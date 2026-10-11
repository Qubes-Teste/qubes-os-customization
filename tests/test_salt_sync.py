"""Exercise fresh Salt synchronization in private directories, without Qubes changes."""
import json
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SaltSyncChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='hud-sync-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def fixture(self, name='fixture'):
        root = self.root / name
        root.mkdir()
        script = (ROOT / 'scripts/sync-salt-formula.sh').read_text()
        entries = re.search(r'required_entries=\(\n(.*?)\n\)', script, re.S)
        self.assertIsNotNone(entries)
        source = root / 'salt/qubes_gui'
        for relative in entries.group(1).split():
            target = source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('source fixture: ' + relative + '\n')
        # Test an asset below additional, initially absent formula directories.
        asset = source / 'hud/files/nested/asset'
        asset.parent.mkdir(parents=True, exist_ok=True)
        asset.write_text('nested asset\n')
        srv = root / 'srv'
        srv.mkdir()
        parent = srv / 'user_salt'
        self.assertEqual(script.count('target_parent=/srv/user_salt\n'), 1)
        script = script.replace('target_parent=/srv/user_salt\n',
                                'target_parent=' + shlex.quote(str(parent)) + '\n')
        self.assertEqual(script.count('for directory in /srv '), 1)
        script = script.replace('for directory in /srv ',
                                'for directory in ' + shlex.quote(str(srv)) + ' ')
        scripts = root / 'scripts'
        scripts.mkdir()
        (scripts / 'sync-salt-formula.sh').write_text(script)
        commands = root / 'commands'
        commands.mkdir()
        mocks = {
            'sudo': '#!/bin/bash\nexec "$@"\n',
            'qubesctl': '''#!/usr/bin/python3
import json, os, pathlib, sys
assert sys.argv[1:] == ['state.sls', 'qubes.user-dirs'], sys.argv
with open(os.environ['HUD_SYNC_TEST_CALLS'], 'a') as output:
    output.write(json.dumps(sys.argv[1:]) + '\\n')
if os.environ.get('HUD_SYNC_TEST_FAIL') == '1':
    sys.exit(42)
# The stock state creates the shared parent, never qubes_gui.
parent = pathlib.Path(os.environ['HUD_SYNC_TEST_PARENT'])
parent.mkdir(mode=0o750, parents=True, exist_ok=True)
top = parent / 'top.sls'
if not top.exists():
    top.write_text('existing native top\\n')
''',
            'install': '''#!/usr/bin/python3
import os, subprocess, sys
args = sys.argv[1:]
# Ordinary-user tests preserve real install/copy/mode behavior while ignoring
# only ownership, which requires root on the deployment target.
for flag in ('-o', '-g'):
    if flag in args:
        index = args.index(flag)
        assert args[index + 1] == 'root', args
        del args[index:index + 2]
sys.exit(subprocess.call(['/usr/bin/install', *args]))
''',
        }
        for name, contents in mocks.items():
            command = commands / name
            command.write_text(contents)
            command.chmod(0o755)
        return root

    def synchronize(self, root, fail=False):
        environment = dict(os.environ, PATH=str(root / 'commands') + ':/usr/bin:/bin',
                           HUD_SYNC_TEST_CALLS=str(root / 'calls'),
                           HUD_SYNC_TEST_PARENT=str(root / 'srv/user_salt'),
                           HUD_SYNC_TEST_FAIL=str(int(fail)))
        return subprocess.run(['/usr/bin/bash', str(root / 'scripts/sync-salt-formula.sh')],
                              env=environment, text=True, capture_output=True, timeout=30)

    def test_fresh_parent_and_namespace_then_repeat(self):
        root = self.fixture()
        source = root / 'salt/qubes_gui'
        target = root / 'srv/user_salt/qubes_gui'
        self.assertFalse(target.parent.exists())
        first = self.synchronize(root)
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o750)
        for path in source.rglob('*'):
            copied = target / path.relative_to(source)
            if path.is_file():
                self.assertEqual(copied.read_bytes(), path.read_bytes())
                self.assertEqual(stat.S_IMODE(copied.stat().st_mode), 0o640)
            else:
                self.assertTrue(copied.is_dir())
        manifest = target / '.qubes-gui-sync-manifest-v1'
        original_manifest = manifest.read_bytes()
        self.assertEqual(stat.S_IMODE(manifest.stat().st_mode), 0o640)
        self.assertTrue(original_manifest.startswith(b'# qubes-gui-sync-manifest-v1\n'))
        second = self.synchronize(root)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(manifest.read_bytes(), original_manifest)
        self.assertEqual((target.parent / 'top.sls').read_text(), 'existing native top\n')
        self.assertEqual(len((root / 'calls').read_text().splitlines()), 2)

    def test_existing_shared_parent_and_namespace_preserve_unrelated_files(self):
        for namespace_exists in (False, True):
            with self.subTest(namespace_exists=namespace_exists):
                root = self.fixture(str(namespace_exists))
                parent = root / 'srv/user_salt'
                parent.mkdir()
                (parent / 'top.sls').write_text('user top\n')
                target = parent / 'qubes_gui'
                if namespace_exists:
                    target.mkdir()
                    (target / 'unrelated').write_text('user file\n')
                result = self.synchronize(root)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((parent / 'top.sls').read_text(), 'user top\n')
                if namespace_exists:
                    self.assertEqual((target / 'unrelated').read_text(), 'user file\n')

    def test_unsafe_root_or_parent_is_refused_before_native_setup(self):
        for relative in ('srv', 'srv/user_salt', 'srv/user_salt/qubes_gui'):
            for kind in ('file', 'fifo', 'symlink', 'dangling'):
                with self.subTest(relative=relative, kind=kind):
                    root = self.fixture(relative.replace('/', '-') + '-' + kind)
                    target = root / relative
                    if target.exists():
                        target.rmdir()
                    target.parent.mkdir(parents=True, exist_ok=True)
                    outside = root / 'outside'
                    outside.mkdir()
                    if kind == 'file':
                        target.write_text('preserve\n')
                    elif kind == 'fifo':
                        os.mkfifo(target)
                    else:
                        destination = outside if kind == 'symlink' else outside / 'absent'
                        target.symlink_to(destination, target_is_directory=True)
                    before = target.lstat()
                    result = self.synchronize(root)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('not a real directory', result.stderr)
                    self.assertFalse((root / 'calls').exists())
                    self.assertEqual(target.lstat(), before)
                    self.assertEqual(list(outside.iterdir()), [])

    def test_failed_native_setup_stops_before_namespace_creation(self):
        root = self.fixture()
        result = self.synchronize(root, fail=True)
        self.assertEqual(result.returncode, 42, result.stderr)
        self.assertFalse((root / 'srv/user_salt').exists())
        calls = [json.loads(line) for line in (root / 'calls').read_text().splitlines()]
        self.assertEqual(calls, [['state.sls', 'qubes.user-dirs']])


if __name__ == '__main__':
    unittest.main()
