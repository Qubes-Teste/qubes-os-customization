"""Offline bootstrap boundaries and native deployment ordering; no live applies."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock
import warnings
import zipfile


ROOT = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


bootstrap = load('hud_bootstrap_test_module', 'install.py')
stack = load('hud_install_stack_test_module', 'scripts/install-stack.py')


def fixture(root):
    for name in bootstrap.REQUIRED_FILES:
        name = 'install.py' if name == '__main__.py' else name
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('# fixture: ' + name + '\n')


def archive(path, extra=(), missing=()):
    with warnings.catch_warnings(), zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as output:
        warnings.simplefilter('ignore', UserWarning)  # Deliberate duplicate attack cases.
        for name, mode, data in [
                (name, stat.S_IFREG | 0o644, b'fixture\n')
                for name in sorted(bootstrap.REQUIRED_FILES - set(missing))] + list(extra):
            entry = zipfile.ZipInfo(name)
            entry.create_system = 3
            entry.external_attr = mode << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            output.writestr(entry, data)


class BundleChecks(unittest.TestCase):
    def test_roundtrip_is_reproducible_and_excludes_unrelated_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'source'
            root.mkdir()
            fixture(root)
            (root / 'private-token').write_text('never package this')
            (root / '.git').mkdir()
            (root / '.git/config').write_text('private remote')
            first, second = Path(directory) / 'first.pyz', Path(directory) / 'second.pyz'
            digest = bootstrap.build_bundle(root, first)
            self.assertEqual(digest, bootstrap.build_bundle(root, second))
            self.assertEqual(digest, hashlib.sha256(first.read_bytes()).hexdigest())
            destination = Path(directory) / 'extracted'
            destination.mkdir(mode=0o700)
            bootstrap.extract_bundle(first, destination)
            self.assertEqual({p.relative_to(destination).as_posix()
                              for p in destination.rglob('*') if p.is_file()},
                             bootstrap.REQUIRED_FILES)
            self.assertEqual((destination / '__main__.py').read_bytes(),
                             (root / 'install.py').read_bytes())
            self.assertEqual((destination / 'salt/qubes_gui/hud/init.sls').read_bytes(),
                             (root / 'salt/qubes_gui/hud/init.sls').read_bytes())

    def test_source_links_specials_and_incomplete_projects_are_refused(self):
        for kind in ('symlink-file', 'hardlink-file', 'symlink-parent', 'fifo', 'missing'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / 'source'
                root.mkdir()
                fixture(root)
                path = root / 'README.md'
                original = Path(directory) / 'outside'
                original.write_text('outside data')
                if kind == 'symlink-parent':
                    displaced = Path(directory) / 'actual-salt'
                    (root / 'salt').rename(displaced)
                    (root / 'salt').symlink_to(displaced, target_is_directory=True)
                else:
                    path.unlink()
                    if kind == 'symlink-file':
                        path.symlink_to(original)
                    elif kind == 'hardlink-file':
                        os.link(original, path)
                    elif kind == 'fifo':
                        os.mkfifo(path)
                destination = Path(directory) / 'bundle.pyz'
                with self.assertRaises((ValueError, OSError)):
                    bootstrap.build_bundle(root, destination)
                self.assertFalse(destination.exists())

    def test_existing_bundle_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'source'
            root.mkdir()
            fixture(root)
            destination = Path(directory) / 'bundle.pyz'
            destination.write_bytes(b'previous bundle')
            with self.assertRaises(FileExistsError):
                bootstrap.build_bundle(root, destination)
            self.assertEqual(destination.read_bytes(), b'previous bundle')

    def test_malicious_archive_members_fail_before_any_extraction(self):
        regular = stat.S_IFREG | 0o644
        cases = [
            [('salt/qubes_gui/hud/../../escape', regular, b'x')],
            [('/tmp/escape', regular, b'x')],
            [('salt//qubes_gui/hud/escape', regular, b'x')],
            [('salt/qubes_gui/hud/./escape', regular, b'x')],
            [('salt\\qubes_gui\\hud\\escape', regular, b'x')],
            [('salt/qubes_gui/hud/link', stat.S_IFLNK | 0o777, b'/tmp/escape')],
            [('salt/qubes_gui/hud/device', stat.S_IFCHR | 0o600, b'')],
            [('salt/qubes_gui/hud/fifo', stat.S_IFIFO | 0o600, b'')],
            [('salt/qubes_gui/hud/dir/', stat.S_IFDIR | 0o755, b'')],
            [('salt/qubes_gui/hud/untyped', 0o644, b'x')],
            [('README.md', regular, b'replacement')],
            [('salt/qubes_gui/hud/collision', regular, b'x'),
             ('salt/qubes_gui/hud/collision/child', regular, b'x')],
            [('scripts/foreign-program', regular, b'x')],
        ]
        for extra in cases:
            with self.subTest(extra=extra), tempfile.TemporaryDirectory() as directory:
                source, destination = Path(directory) / 'bundle.pyz', Path(directory) / 'out'
                destination.mkdir(mode=0o700)
                archive(source, extra)
                with self.assertRaises(ValueError):
                    bootstrap.extract_bundle(source, destination)
                self.assertEqual(list(destination.iterdir()), [])

    def test_archive_limits_incomplete_payload_and_existing_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            source, destination = Path(directory) / 'bundle.pyz', Path(directory) / 'out'
            destination.mkdir(mode=0o700)
            archive(source, missing={'scripts/install-stack.py'})
            with self.assertRaises(ValueError):
                bootstrap.extract_bundle(source, destination)
            archive(source)
            with mock.patch.object(bootstrap, 'MAX_FILES', len(bootstrap.REQUIRED_FILES) - 1), \
                    self.assertRaises(ValueError):
                bootstrap.extract_bundle(source, destination)
            with mock.patch.object(bootstrap, 'MAX_BYTES', source.stat().st_size - 1), \
                    self.assertRaises(ValueError):
                bootstrap.extract_bundle(source, destination)
            archive(source, [('salt/qubes_gui/hud/large', stat.S_IFREG | 0o644, b'x' * 100000)])
            with mock.patch.object(bootstrap, 'MAX_BYTES', source.stat().st_size + 1), \
                    self.assertRaises(ValueError):
                bootstrap.extract_bundle(source, destination)
            self.assertEqual(list(destination.iterdir()), [])
            archive(source)
            existing = destination / 'user-data'
            existing.write_text('preserve')
            with self.assertRaises(ValueError):
                bootstrap.extract_bundle(source, destination)
            self.assertEqual(existing.read_text(), 'preserve')
            self.assertEqual(list(destination.iterdir()), [existing])


class BridgeChecks(unittest.TestCase):
    def test_qube_names_and_digests_cannot_inject_commands(self):
        for qube in ('dom0', 'Domain-0', '-flag', 'work;id', 'work\nother', '../work'):
            with self.subTest(qube=qube), self.assertRaises(ValueError):
                bootstrap.bridge_command(qube, Path('/tmp/input'), 'a' * 64, [])
        for digest in ('a' * 63, 'a' * 64 + ';id', 'x' * 64, 'A' * 64):
            with self.subTest(digest=digest), self.assertRaises(ValueError):
                bootstrap.bridge_command('work', Path('/tmp/input'), digest, [])

    def bridge(self, *, wrong_digest=False, transfer_failure=False, oversized=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands = root / 'bin'
            commands.mkdir()
            source = root / "bundle ' $(touch INJECTED).pyz"
            source.write_bytes(b'payload' if not oversized else b'x' * 2048)
            marker, transfer = root / 'executed.json', root / 'transfer.json'
            scripts = {
                'mktemp': "import os\nfrom pathlib import Path\np = Path(os.environ['HUD_DEST'])\np.mkdir()\nprint(p)\n",
                'qvm-run': "import json, os, sys\nfrom pathlib import Path\n"
                           "Path(os.environ['HUD_TRANSFER']).write_text(json.dumps(sys.argv[1:]))\n"
                           "sys.stdout.buffer.write(Path(sys.argv[-1]).read_bytes())\n"
                           "sys.exit(int(os.environ.get('HUD_FAIL', '0')))\n",
                'python3': "import json, os, sys\nfrom pathlib import Path\n"
                           "Path(os.environ['HUD_MARKER']).write_text(json.dumps(sys.argv[1:]))\n",
            }
            for name, body in scripts.items():
                path = commands / name
                path.write_text('#!/usr/bin/python3\n' + body)
                path.chmod(0o755)
            args = ['--desktop-user', 'user; touch INJECTED', '--guest-template', "name'$(touch INJECTED)"]
            digest = '0' * 64 if wrong_digest else hashlib.sha256(source.read_bytes()).hexdigest()
            with mock.patch.object(bootstrap, 'MAX_BYTES', 1024):
                command = bootstrap.bridge_command('work', source, digest, args)
            environment = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ['PATH'],
                               HUD_DEST=str(root / 'incoming'), HUD_MARKER=str(marker),
                               HUD_TRANSFER=str(transfer), HUD_FAIL='4' if transfer_failure else '0')
            completed = subprocess.run(['/usr/bin/bash', '-c', command], cwd=root,
                                       env=environment, capture_output=True, timeout=10)
            self.assertFalse((root / 'INJECTED').exists())
            self.assertEqual(json.loads(transfer.read_text())[-3:], ['work', '/usr/bin/cat', str(source)])
            if wrong_digest or transfer_failure or oversized:
                self.assertNotEqual(completed.returncode, 0)
                self.assertFalse(marker.exists(), 'Unverified/failed transfer was executed')
            else:
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertEqual(json.loads(marker.read_text()),
                                 [str(root / 'incoming/install.pyz'), *args])
                self.assertEqual((root / 'incoming/install.pyz').read_bytes(), source.read_bytes())

    def test_real_shell_preserves_quoted_paths_and_forwarded_arguments(self):
        self.bridge()

    def test_bad_digest_transfer_failure_and_size_cap_prevent_execution(self):
        for option in ('wrong_digest', 'transfer_failure', 'oversized'):
            with self.subTest(option=option):
                self.bridge(**{option: True})


class InstructionChecks(unittest.TestCase):
    def instruction(self, *, transfer_failure=False, oversized=False, mktemp_failure=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands, incoming = root / 'bin', root / 'incoming'
            commands.mkdir()
            incoming.mkdir()
            source = root / "start ' $(touch INJECTED); script.sh"
            source.write_text('printf done >> "$HUD_EXECUTED"\n'
                              '/usr/bin/head -c 32768 /dev/zero > "$HUD_LARGE"\n'
                              + ('#' + 'x' * 20000 + '\n' if oversized else ''))
            marker, transfer, large = root / 'executed', root / 'transfer.json', root / 'large'
            runner = commands / 'qvm-run'
            runner.write_text('#!/usr/bin/python3\nimport json, os, sys\nfrom pathlib import Path\n'
                              "Path(os.environ['HUD_TRANSFER']).write_text(json.dumps(sys.argv[1:]))\n"
                              'sys.stdout.buffer.write(Path(sys.argv[-1]).read_bytes())\n'
                              "sys.exit(int(os.environ['HUD_FAIL']))\n")
            runner.chmod(0o755)
            if mktemp_failure:
                temporary = commands / 'mktemp'
                temporary.write_text('#!/bin/sh\nexit 1\n')
                temporary.chmod(0o755)
            environment = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ['PATH'],
                               TMPDIR=str(incoming), HUD_EXECUTED=str(marker), HUD_LARGE=str(large),
                               HUD_TRANSFER=str(transfer), HUD_FAIL='4' if transfer_failure else '0')
            command = bootstrap.instruction_command('work', source)
            failed = transfer_failure or oversized or mktemp_failure
            for _ in range(1 if failed else 2):
                completed = subprocess.run(['/usr/bin/bash', '-c', command], cwd=root,
                                           env=environment, capture_output=True, timeout=10)
                self.assertFalse((root / 'INJECTED').exists())
                if failed:
                    self.assertNotEqual(completed.returncode, 0)
                    self.assertFalse(marker.exists(), 'Incomplete instructions were executed')
                else:
                    self.assertEqual(completed.returncode, 0, completed.stderr)
            if mktemp_failure:
                self.assertFalse(transfer.exists(), 'Transfer ran after private file creation failed')
                self.assertEqual(list(incoming.iterdir()), [])
                return
            self.assertEqual(json.loads(transfer.read_text()), ['-pn', 'work', 'cat', str(source)])
            files = list(incoming.iterdir())
            self.assertEqual(len(files), 1 if failed else 2)
            for path in files:
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                self.assertLessEqual(path.stat().st_size, 16384)
                if not oversized:
                    self.assertEqual(path.read_bytes(), source.read_bytes())
            if not failed:
                self.assertEqual(marker.read_text(), 'donedone')
                self.assertEqual(large.stat().st_size, 32768,
                                 'Transfer file-size limit leaked into installer execution')

    def test_real_shell_quotes_paths_and_uses_new_private_file_on_repeats(self):
        self.instruction()

    def test_failed_and_oversized_transfers_never_execute_instructions(self):
        for option in ('transfer_failure', 'oversized'):
            with self.subTest(option=option):
                self.instruction(**{option: True})

    def test_mktemp_failure_prevents_transfer_and_execution(self):
        self.instruction(mktemp_failure=True)


def arguments(**extra):
    return SimpleNamespace(desktop_user='desktop', source_template=stack.SOURCE,
                           guest_template=[], skip_workspace=False, **extra)


def account():
    return SimpleNamespace(pw_name='desktop', pw_uid=1000, pw_gid=os.getgid(), pw_dir='/tmp')


def machine(**changes):
    value = {'desktop': account(), 'updatevm': 'sys-net', 'guests': [stack.SOURCE],
             'missing_source': False, 'errors': [], 'vms': {}}
    value.update(changes)
    return value


class NativePlanChecks(unittest.TestCase):
    def test_signed_source_and_clone_creation_precede_guest_discovery(self):
        plan = stack.build_plan(arguments(), machine(missing_source=True))
        self.assertEqual(plan[0]['command'][0], '/usr/bin/bash')
        self.assertTrue(plan[0]['command'][1].endswith('/scripts/sync-salt-formula.sh'))
        self.assertEqual(plan[1]['command'], ['/usr/bin/qvm-template', '--yes', '--updatevm',
                                             'sys-net', 'install', stack.SOURCE])
        family = [phase for phase in plan if 'qubes_gui.templates.family' in phase['command']]
        self.assertEqual([bool(phase['targets']) for phase in family], [False, False, True, True])
        self.assertIn('test=True', family[0]['command'])
        self.assertNotIn('test=True', family[1]['command'])
        self.assertEqual(family[2]['targets'], tuple(stack.FAMILY.values()))
        for phase in plan:
            command = phase['command']
            self.assertIn(command[0], {'/usr/bin/qvm-template', '/usr/bin/bash', '/usr/bin/qubesctl'})
            self.assertNotIn('--nogpgcheck', command)
            if command[0] == '/usr/bin/qubesctl':
                pillar = json.loads(next(token[7:] for token in command if token.startswith('pillar=')))
                for component in ('i3', 'hud'):
                    self.assertEqual(pillar['qubes_gui'][component]['package_transport'], 'qubes-updatevm')
                self.assertEqual('--skip-dom0' in command, bool(phase['targets']))

    def test_workspace_boot_enable_follows_guest_configuration(self):
        plan = stack.build_plan(arguments(), machine())
        phases = [phase for phase in plan if 'qubes_gui.hud.qube' in phase['command']]
        self.assertEqual([phase['targets'] for phase in phases],
                         [(), (), (stack.PRESET,), (stack.PRESET,), (), ()])
        self.assertEqual([phase['kind'] for phase in phases[2:4]], ['AppVM', 'AppVM'])
        readiness = []
        for phase in phases:
            pillar = json.loads(next(token[7:] for token in phase['command'] if token.startswith('pillar=')))
            readiness.append(pillar['qubes_gui']['hud']['qube_workspace']['ready'])
        self.assertEqual(readiness, [False, False, False, False, True, True])
        args = arguments()
        args.skip_workspace = True
        self.assertFalse(any('qubes_gui.hud.qube' in phase['command']
                             for phase in stack.build_plan(args, machine())))

    def test_readonly_plan_and_preflight_blockers_never_prompt_or_execute(self):
        for errors in ([], ['Template is running']):
            with self.subTest(errors=errors), \
                    mock.patch.object(stack, 'inspect_machine', return_value=machine(errors=errors)), \
                    mock.patch.object(stack, 'execute', side_effect=AssertionError('mutation')), \
                    mock.patch('builtins.input', side_effect=AssertionError('prompt')), \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(stack.main(['--plan']), 1 if errors else 0)

    def test_running_or_wrong_class_target_is_refused_before_execution(self):
        phase = {'title': 'guest apply', 'command': ['must-not-run'],
                 'targets': ('target',), 'kind': 'TemplateVM'}
        for vm in ({}, {'class': 'TemplateVM', 'state': 'Running'},
                   {'class': 'TemplateVM', 'state': 'Paused'}, {'class': 'AppVM', 'state': 'Halted'}):
            with self.subTest(vm=vm), mock.patch.object(stack, 'domains', return_value={'target': vm}), \
                    mock.patch.object(stack.subprocess, 'run', side_effect=AssertionError('mutation')), \
                    contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
                stack.execute([phase])

    def test_execution_stops_after_failure_or_guest_left_running(self):
        first = {'title': 'first', 'command': ['/usr/bin/qubesctl', 'first'],
                 'targets': ('target',), 'kind': 'TemplateVM'}
        second = dict(first, title='second', command=['must-not-run'])
        for failed in (False, True):
            states = [{'target': {'class': 'TemplateVM', 'state': state}}
                      for state in ('Halted', 'Running')]
            with self.subTest(failed=failed), mock.patch.object(stack, 'domains', side_effect=states), \
                    mock.patch.object(stack.os, 'geteuid', return_value=1000), \
                    mock.patch.object(stack.subprocess, 'run', side_effect=(
                        subprocess.CalledProcessError(1, 'first') if failed else None)) as run, \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()), \
                    self.assertRaises((ValueError, subprocess.CalledProcessError)):
                stack.execute([first, second])
            run.assert_called_once_with(['/usr/bin/sudo', '--', *first['command']],
                                        check=True)


class NativePreflightChecks(unittest.TestCase):
    def inspect(self, vms, *, saved=None, tags=None, args=None):
        def read(*command):
            if command == ('/usr/bin/qubes-prefs', 'updatevm'):
                return 'sys-net'
            if command[0] == '/usr/bin/qvm-tags':
                return '\n'.join((tags or {}).get(command[1], []))
            self.fail('Unexpected preflight command: ' + repr(command))
        with mock.patch.object(stack, 'check_platform'), \
                mock.patch.object(stack, 'domains', return_value=vms), \
                mock.patch.object(stack, 'features', side_effect=lambda name: (saved or {}).get(name, {})), \
                mock.patch.object(stack, 'read', side_effect=read), \
                mock.patch.object(stack.pwd, 'getpwnam', return_value=account()):
            return stack.inspect_machine(args or arguments())

    def baseline(self):
        return {'dom0': {'class': 'AdminVM', 'state': 'Running', 'template': ''},
                'sys-net': {'class': 'AppVM', 'state': 'Running', 'template': 'elsewhere'},
                'sys-firewall': {'class': 'DispVM', 'state': 'Running', 'template': 'elsewhere'}}

    def test_fresh_machine_plans_signed_source_without_starting_existing_qubes(self):
        result = self.inspect(self.baseline())
        self.assertTrue(result['missing_source'])
        self.assertEqual(result['errors'], [])
        self.assertEqual(result['guests'], [stack.SOURCE])

    def test_source_os_and_halted_template_identity_are_required(self):
        for kind, state, version in [('AppVM', 'Halted', '13'), ('TemplateVM', 'Running', '13'),
                                     ('TemplateVM', 'Paused', '13'), ('TemplateVM', 'Halted', '12')]:
            with self.subTest(kind=kind, state=state, version=version):
                vms = self.baseline()
                vms[stack.SOURCE] = {'class': kind, 'state': state, 'template': ''}
                result = self.inspect(vms, saved={stack.SOURCE: {'os-distribution': 'debian',
                                                                'os-version': version}})
                self.assertTrue(result['errors'])

    def test_graphical_discovery_uses_guest_features_and_preserves_explicit_targets(self):
        vms = self.baseline()
        saved = {}
        for name, distribution, version, gui in [
                ('debian-custom', 'debian', '13.1', '1'),
                ('fedora-custom', 'fedora', '42', '1'),
                ('whonix-custom', 'whonix', '18', '1'),
                ('debian-minimal', 'debian', '13', '0'),
                ('debian-old', 'debian', '12', '1'),
                ('unknown', 'unrecognized', '1', '1')]:
            vms[name] = {'class': 'TemplateVM', 'state': 'Halted', 'template': ''}
            saved[name] = {'os-distribution': distribution, 'os-version': version, 'gui': gui}
        args = arguments()
        args.guest_template = ['debian-custom', 'unknown']
        result = self.inspect(vms, saved=saved, args=args)
        self.assertEqual(result['guests'], [stack.SOURCE, 'debian-custom', 'fedora-custom',
                                            'whonix-custom', 'unknown'])
        self.assertEqual(result['errors'], [])

    def test_existing_family_requires_matching_tag_role_and_parent(self):
        for role, name in stack.FAMILY.items():
            parent = stack.SOURCE if role == 'base' else stack.FAMILY['base']
            saved = {name: {'vm-config.qubes-hud-family-' + key: value for key, value in
                            {'name': name, 'role': role, 'source': parent}.items()}}
            vms = self.baseline()
            vms[name] = {'class': 'TemplateVM', 'state': 'Halted', 'template': ''}
            for valid in (False, True):
                with self.subTest(role=role, valid=valid):
                    tags = {name: ['hud-template-family-managed']} if valid else {}
                    result = self.inspect(vms, saved=saved, tags=tags)
                    self.assertEqual(bool(result['errors']), not valid)
            saved[name]['vm-config.qubes-hud-family-source'] = 'unrelated'
            self.assertTrue(self.inspect(vms, saved=saved,
                                        tags={name: ['hud-template-family-managed']})['errors'])

    def test_occupied_workspace_requires_skip_and_preserves_live_state(self):
        vms = self.baseline()
        vms[stack.PRESET] = {'class': 'AppVM', 'state': 'Running', 'template': stack.SOURCE}
        tags = {stack.PRESET: ['hud-workspace-managed']}
        self.assertTrue(self.inspect(vms, tags=tags)['errors'])
        args = arguments()
        args.skip_workspace = True
        self.assertEqual(self.inspect(vms, tags=tags, args=args)['errors'], [])
        self.assertEqual(vms[stack.PRESET]['state'], 'Running')


if __name__ == '__main__':
    unittest.main()
