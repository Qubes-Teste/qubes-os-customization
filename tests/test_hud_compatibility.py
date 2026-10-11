"""Render compatibility boundaries with Salt's existing Jinja/YAML libraries.

No host files, package database, desktop or qubes are modified. Native i3's
configuration parser is additionally checked when the stock binary exists.
"""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

try:
    import jinja2
    import yaml
except ImportError:
    jinja2 = yaml = None


ROOT = Path(__file__).resolve().parents[1]
DIGEST = 'a' * 64


class Host:
    """A clean graphical dom0 with a verified stock i3 and no project files."""
    def __init__(self, settings_evr='1.17-1.fc41', helper_help=None):
        self.settings_evr = settings_evr
        self.helper_help = helper_help or {'retcode': 0, 'stdout': '--console'}
        self.settings_installed = True
        self.missing = set()
        self.i3_digest = DIGEST
        self.probes = []

    def command(self, command, **kwargs):
        self.probes.append(command)
        if isinstance(command, list):
            if command[:2] == ['/usr/bin/test', '-x']:
                return int(command[2] in self.missing)
            if command == ['/usr/bin/qubes-i3-sensible-terminal', '--help']:
                return self.helper_help
        if command == '/usr/bin/rpm --quiet -q i3-settings-qubes':
            return int(not self.settings_installed)
        if command == '/usr/bin/rpm --quiet -q picom':
            return 0
        if command.startswith('/usr/bin/rpm ') and 'i3-settings-qubes' in command:
            return self.settings_evr
        if command == "/usr/bin/rpm -qf --qf '%{NAME}' /usr/bin/i3":
            return 'i3'
        if command == "/usr/bin/rpm -q --qf '%{FILEDIGESTALGO}' i3":
            return '8'
        if command.startswith('/usr/bin/rpm -q --qf ') and 'FILEDIGESTS' in command:
            return '/usr/bin/i3\t' + DIGEST + '\n'
        raise AssertionError('Unexpected render-time command: ' + repr(command))

    def functions(self):
        return {
            'pillar.get': lambda key, default=None: default,
            'user.info': lambda name: {'uid': 1000, 'gid': 1000, 'home': '/home/user'},
            'file.group_to_gid': lambda name: 1000,
            'file.lstat': lambda path: {'st_uid': 0, 'st_gid': 0}
                if path == '/usr/bin/i3' else {},
            'file.file_exists': lambda path: path == '/usr/bin/i3',
            'file.directory_exists': lambda path: False,
            'file.is_link': lambda path: False,
            'file.get_mode': lambda path: '0755' if path == '/usr/bin/i3' else '',
            'file.get_hash': lambda *args: self.i3_digest,
            'file.read': lambda path: '',
            'cmd.run': self.command,
            'cmd.run_all': self.command,
            'cmd.retcode': self.command,
        }


@unittest.skipUnless(jinja2 and yaml, 'Uses Jinja/YAML already provided by Salt')
class Compatibility(unittest.TestCase):
    def setUp(self):
        self.environment = jinja2.Environment(
            loader=jinja2.FileSystemLoader(ROOT / 'salt'),
            undefined=jinja2.StrictUndefined)
        self.environment.filters['yaml_dquote'] = json.dumps

    def render(self, host=None, release='4.3', **grains):
        host = host or Host()
        platform = {'virtual': 'Qubes', 'virtual_subtype': 'Xen Dom0',
                    'cpuarch': 'x86_64', 'osrelease': release}
        platform.update(grains)
        output = self.environment.get_template('qubes_gui/hud/init.sls').render(
            salt=host.functions(), grains=platform, opts={'test': True})
        return yaml.safe_load(output)

    @staticmethod
    def parameters(high, state, function):
        return {key: value for item in high[state][function]
                if isinstance(item, dict) for key, value in item.items()}

    def test_package_updates_preserve_the_installation_graph(self):
        expected = self.render()
        for version in ('1.14-1.fc41', '1.17-1.fc41', '2.0-5.fc99'):
            with self.subTest(version=version):
                self.assertEqual(expected, self.render(Host(settings_evr=version)))
        self.assertIn('qubes_gui_hud_runtime_packages_qubes_updatevm', expected)
        self.assertIn('qubes_gui_hud_xsession', expected)

    def test_newer_numeric_qubes_releases_preserve_the_graph(self):
        expected = self.render()
        for release in ('4.3.1', '4.4', '4.10', '5.0', '10.0.1'):
            with self.subTest(release=release):
                self.assertEqual(expected, self.render(release=release))

    def test_old_unknown_and_non_dom0_platforms_are_refused(self):
        for release in ('', '4.2', '3.9', '4', '4.3.', '4.3rc1', '4.x', '4.-3'):
            with self.subTest(release=release):
                self.assertEqual(set(self.render(release=release)),
                                 {'qubes_gui_hud_unsupported_platform'})
        for grains in ({'virtual': 'xen'}, {'virtual_subtype': 'Xen DomU'},
                       {'cpuarch': 'aarch64'}):
            with self.subTest(grains=grains):
                self.assertEqual(set(self.render(**grains)),
                                 {'qubes_gui_hud_unsupported_platform'})

    def test_missing_package_or_helpers_refuses_activation(self):
        for missing in ('package', '/usr/bin/qubes-i3-sensible-terminal',
                        '/usr/bin/qubes-i3status'):
            with self.subTest(missing=missing):
                host = Host()
                host.settings_installed = missing != 'package'
                host.missing.add(missing)
                self.assertEqual(set(self.render(host)),
                                 {'qubes_gui_hud_missing_i3_integration'})
                self.assertNotIn(['/usr/bin/qubes-i3-sensible-terminal', '--help'],
                                 host.probes)

    def test_official_i3_integrity_is_still_required(self):
        host = Host()
        host.i3_digest = 'b' * 64
        self.assertEqual(set(self.render(host)), {'qubes_gui_hud_official_i3_required'})

    def test_console_interface_is_detected_and_both_configs_parse(self):
        for help_result, argument in (({'retcode': 1, 'stdout': ''}, 'console'),
                ({'retcode': 0, 'stdout': 'usage: terminal --console'}, '--console'),
                ({'retcode': 0, 'stdout': '', 'stderr': 'usage: terminal --console'}, '--console'),
                ({'retcode': 1, 'stdout': '', 'stderr': 'unknown option --console'}, 'console')):
            with self.subTest(argument=argument):
                high = self.render(Host(helper_help=help_result))
                file = self.parameters(high, 'qubes_gui_hud_i3_config', 'file.managed')
                self.assertEqual(file['template'], 'jinja')
                self.assertEqual(file['context'], {'console_argument': argument})
                config = self.environment.get_template('qubes_gui/hud/files/i3-config').render(
                    **file['context'])
                self.assertIn('set $console qubes-i3-sensible-terminal ' + argument, config)
                self.assertNotIn('{{', config)
                if Path('/usr/bin/i3').exists():
                    with tempfile.TemporaryDirectory(prefix='hud-i3-config-check-') as directory:
                        path = Path(directory) / 'config'
                        path.write_text(config)
                        result = subprocess.run(['/usr/bin/i3', '-C', '-c', str(path)],
                                                capture_output=True, text=True, timeout=15)
                        self.assertEqual(result.returncode, 0, result.stderr)

    def test_session_requires_rechecking_an_unchanged_config(self):
        high = self.render()
        check = self.parameters(high, 'qubes_gui_hud_i3_config_compatible', 'cmd.run')
        self.assertEqual(check['name'], "/usr/bin/i3 -C -c '/home/user/.config/i3/config'")
        self.assertEqual(check['unless'], check['name'])
        self.assertEqual(check['require'], [{'file': 'qubes_gui_hud_i3_config'}])
        session = self.parameters(high, 'qubes_gui_hud_xsession', 'file.managed')
        self.assertIn({'cmd': 'qubes_gui_hud_i3_config_compatible'}, session['require'])


if __name__ == '__main__':
    unittest.main()
