#!/usr/bin/env python3
"""Prepare in a download qube; execute the existing Salt stack in dom0.

No RPC policy is installed. A user must enter the printed pull command in
dom0, explicitly trusting this project and the qube that supplies its code.
"""
import hashlib
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import stat
import subprocess
import sys
import tempfile
import zipfile

MAX_BYTES = 64 * 1024 * 1024
MAX_FILES = 4096
ROOT_FILES = {'__main__.py', 'README.md', 'AGENTS.md', 'PROJECT_HANDOFF.md',
              'scripts/sync-salt-formula.sh', 'scripts/install-stack.py',
              'salt/pillar.example.sls'}
REQUIRED_FILES = ROOT_FILES | {'salt/qubes_gui/' + name for name in (
    'i3/init.sls', 'i3/platform.jinja', 'hud/init.sls', 'hud/qube.sls', 'hud/font.sls',
    'guest_hud/init.sls', 'guest_hud/firefox.sls', 'templates/family/init.sls')}


def allowed_name(name):
    parts = PurePosixPath(name).parts
    return (bool(re.fullmatch(r'[A-Za-z0-9_./-]+', name))
            and not name.startswith('/') and '..' not in parts
            and str(PurePosixPath(name)) == name
            and (name in ROOT_FILES or (
                len(parts) > 3 and parts[:2] == ('salt', 'qubes_gui')
                and parts[2] in {'i3', 'hud', 'guest_hud', 'templates'})))


def source_files(root):
    """Never package .git, user files, links, caches or outside-tree content."""
    files = [(root / 'install.py', '__main__.py')]
    files += [(root / name, name) for name in sorted(ROOT_FILES - {'__main__.py'})]
    salt_root = root / 'salt' / 'qubes_gui'
    for directory, dirs, names in os.walk(salt_root, followlinks=False):
        for name in dirs + names:
            path = Path(directory) / name
            if path.is_symlink():
                raise ValueError(f'Source symlink refused: {path}')
        files += [(Path(directory) / name, (Path(directory) / name).relative_to(root).as_posix())
                  for name in sorted(names)]
    total = 0
    for path, name in files:
        for parent in path.relative_to(root).parents:
            if (root / parent).is_symlink():
                raise ValueError(f'Source parent symlink refused: {path}')
        metadata = path.lstat()
        if (not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1
                or not allowed_name(name) or name.endswith('.pyc')):
            raise ValueError(f'Unexpected source file: {path}')
        total += metadata.st_size
    if not REQUIRED_FILES.issubset(name for _, name in files):
        raise ValueError('Incomplete project: required Salt states are missing')
    if len(files) > MAX_FILES or total > MAX_BYTES:
        raise ValueError('Project exceeds installer bundle limits')
    return files


def build_bundle(root, destination):
    files = source_files(root)
    with zipfile.ZipFile(destination, 'x', compression=zipfile.ZIP_DEFLATED) as bundle:
        for path, name in sorted(files, key=lambda item: item[1]):
            entry = zipfile.ZipInfo(name)
            entry.create_system = 3
            entry.external_attr = (stat.S_IFREG | 0o644) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            bundle.writestr(entry, path.read_bytes())
    return hashlib.sha256(destination.read_bytes()).hexdigest()


def extract_bundle(bundle_path, destination):
    """Validate the complete archive before writing to a new private directory."""
    if bundle_path.stat().st_size > MAX_BYTES:
        raise ValueError('Installer archive is too large')
    with zipfile.ZipFile(bundle_path) as bundle:
        entries = bundle.infolist()
        names = [entry.filename for entry in entries]
        if (len(entries) > MAX_FILES or len(set(names)) != len(names)
                or sum(entry.file_size for entry in entries) > MAX_BYTES
                or not REQUIRED_FILES.issubset(names)):
            raise ValueError('Incomplete, duplicate or oversized installer archive')
        for entry in entries:
            if (not allowed_name(entry.filename) or entry.is_dir()
                    or stat.S_IFMT(entry.external_attr >> 16) != stat.S_IFREG
                    or entry.flag_bits & 1):
                raise ValueError(f'Unsafe installer archive member: {entry.filename}')
            # File/ancestor collisions must also fail before the first write.
            if any(str(parent) in names for parent in PurePosixPath(entry.filename).parents):
                raise ValueError(f'Conflicting installer archive member: {entry.filename}')
        if any(destination.iterdir()):
            raise ValueError('Extraction requires an empty private directory')
        for entry in entries:
            target = destination / entry.filename
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as output:
                output.write(bundle.read(entry))


def bridge_command(qube, archive, digest, arguments):
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_.-]{0,30}', qube) or qube in {'dom0', 'Domain-0'}:
        raise ValueError('Cannot determine a normal source qube name')
    if not re.fullmatch(r'[0-9a-f]{64}', digest):
        raise ValueError('Invalid archive checksum')
    transfer = shlex.join(['timeout', '--kill-after=5', '120',
                          'qvm-run', '--no-autostart', '--no-gui', '--pass-io',
                          '--no-colour-output', '--no-colour-stderr',
                          '--no-filter-escape-chars', qube, '/usr/bin/cat', str(archive)])
    args = (' ' + shlex.join(arguments)) if arguments else ''
    return ('(umask 077; set -o pipefail; hud_install_dir=$(mktemp -d /tmp/qubes-hud.XXXXXXXXXX) && '
            + transfer + f' | head -c {MAX_BYTES + 1} > "$hud_install_dir/install.pyz" && '
            + "printf '%s  %s\\n' " + digest + ' "$hud_install_dir/install.pyz"'
            + ' | sha256sum --check --status && '
            + 'python3 "$hud_install_dir/install.pyz"' + args + ')')


def in_dom0():
    values = dict(line.split('=', 1) for line in Path('/etc/os-release').read_text().splitlines()
                  if '=' in line and not line.startswith('#'))
    return values.get('ID', '').strip('"') == 'qubes'


def instruction_command(qube, instruction):
    """Pull trusted instructions into a private file before executing them."""
    transfer = shlex.join(['timeout', '-k5', '30', 'qvm-run', '-pn',
                          qube, 'cat', str(instruction)])
    # Bound only the small instruction transfer, not the subsequent Salt run.
    return ('(hud=$(mktemp) && (ulimit -f 16 && ' + transfer
            + ' > "$hud") && bash "$hud")')


def main(arguments=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    executable = Path(__file__).resolve()
    if in_dom0():
        archive = Path(sys.argv[0]).resolve()
        if archive.is_file() and zipfile.is_zipfile(archive):
            with tempfile.TemporaryDirectory(prefix='qubes-hud-source-') as directory:
                root = Path(directory)
                extract_bundle(archive, root)
                return subprocess.call(['/usr/bin/python3', '-B', str(root / 'scripts/install-stack.py'),
                                        *arguments], cwd=root)
        return subprocess.call(['/usr/bin/python3', '-B', str(executable.parent / 'scripts/install-stack.py'),
                                *arguments], cwd=executable.parent)
    if '--help' in arguments or '-h' in arguments:
        print('Run python3 install.py in the downloaded project. It prepares a bundle and prints\n'
              'a short command for dom0 to pull the instructions. No RPC permissions change.\n'
              'Options forwarded to dom0: --plan, --yes, --desktop-user NAME,\n'
              '--source-template NAME, --guest-template NAME (repeatable), --skip-workspace.')
        return 0
    qube = subprocess.check_output(['/usr/bin/qubesdb-read', '/name'], text=True).strip()
    directory = Path(tempfile.mkdtemp(prefix='hud-setup-', dir=Path.home()))
    archive = directory / 'qubes-hud.pyz'
    digest = build_bundle(executable.parent, archive)
    instruction = directory / 'start.sh'
    command = bridge_command(qube, archive, digest, arguments)
    if len(command.encode()) + 1 > 16384:
        raise ValueError('Installer instructions exceed the transfer limit')
    with instruction.open('x') as output:
        output.write(command + '\n')
    print('Project prepared. Keep this qube running until dom0 has copied the bundle.\n'
          'Review/trust the downloaded project before allowing it to configure dom0.\n'
          'The SHA-256 check detects transfer changes; it is not a publisher signature.\n\n'
          'Type this shorter command in a dom0 terminal (not this qube).\n'
          'It pulls and runs the saved instructions; no clipboard transfer is needed:\n\n'
          + instruction_command(qube, instruction)
          + '\n\nDom0 will show the installation plan before applying it.\n'
          f'Instructions to review in this qube: {instruction}\n'
          f'After installation you can remove this prepared bundle: {directory}')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        print(f'Installer stopped: {error}', file=sys.stderr)
        sys.exit(1)
