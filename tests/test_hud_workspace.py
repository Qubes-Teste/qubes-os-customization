"""Headless startup and refusal boundaries for the native HUD layout."""
import contextlib
import importlib.machinery
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock


SOURCE = Path(__file__).resolve().parents[1] / 'salt/qubes_gui/hud/files/hud-workspace'
loader = importlib.machinery.SourceFileLoader('test_hud_workspace_module', str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
app = importlib.util.module_from_spec(spec)
loader.exec_module(app)


def client(view, identity=10, **extra):
    properties = {'class': app.CLASSES[view], 'window_role': 'qubes-hud-' + view}
    if view == 'manager':
        properties = {'class': 'Lokalisierter Manager', 'instance': 'qubes-hud-manager'}
    return {'id': identity, 'type': 'con', 'window': 1000 + identity,
            'window_type': 'normal', 'window_properties': properties,
            'focused': False, 'nodes': [], 'floating_nodes': [], **extra}


def workspace(name, clients):
    return {'id': int(name), 'type': 'workspace', 'name': str(name),
            'nodes': clients, 'floating_nodes': [], 'focused': False}


class LayoutChecks(unittest.TestCase):
    def test_headless_check_does_not_use_display_locks_ipc_or_processes(self):
        with mock.patch.dict(os.environ, {}, clear=True), \
                mock.patch('sys.argv', ['hud-workspace', '--check']), \
                mock.patch.object(Path, 'is_file', return_value=True), \
                mock.patch.object(os, 'access', return_value=True), \
                mock.patch.object(os, 'open', side_effect=AssertionError('opened lock')), \
                mock.patch.object(app, 'ipc', side_effect=AssertionError('contacted i3')), \
                mock.patch.object(app.subprocess, 'Popen', side_effect=AssertionError('spawned')), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            app.main()
        self.assertIn('verified', output.getvalue())

    def test_placeholder_xid_is_not_a_real_client(self):
        # i3 gives append_layout placeholders real nonzero XIDs before swallowing.
        placeholder = {'window': 4194304, 'window_properties': {'title': 'bindings'},
                       'swallows': [{'class': '^QubesHudBindings$'}]}
        self.assertIsNone(app.identify(placeholder))
        self.assertIsNone(app.identify({'window': 4194304, 'window_properties': None}))

    def test_roles_are_exact_and_manager_matching_is_locale_independent(self):
        for view in app.CLASSES:
            node = client(view)
            self.assertEqual(app.identify(node), view)
            key = 'instance' if view == 'manager' else 'window_role'
            node['window_properties'][key] += '-unrelated'
            self.assertIsNone(app.identify(node))
        manager_slot = next(n for n in app.walk(app.layout()) if n.get('name') == 'manager')
        self.assertNotIn('class', manager_slot['swallows'][0])
        self.assertEqual(manager_slot['swallows'][0]['window_type'], 'normal')

    def test_native_terminals_match_exact_class_and_instance_without_role(self):
        for view in ('dom0', 'xen', 'top', 'xentop', 'cgtop'):
            node = client(view)
            properties = node['window_properties']
            properties['instance'] = properties.pop('window_role')
            self.assertEqual(app.identify(node), view)
            properties['class'] = 'OtherApp'
            self.assertIsNone(app.identify(node))


class RefusalChecks(unittest.TestCase):
    def refuse(self, workspaces, expected):
        tree = {'id': 0, 'type': 'root', 'nodes': workspaces, 'focused': False}
        queries = []

        def readonly(command, *, query=False):
            self.assertTrue(query, 'Refusal must not change the i3 tree')
            self.assertEqual(command, 'get_tree')
            queries.append(command)
            return tree

        with mock.patch.object(app, 'ipc', side_effect=readonly), \
                mock.patch.object(app.subprocess, 'Popen', side_effect=AssertionError('spawned')), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            app.launch('2', Path('/unused'))
        self.assertEqual(queries, ['get_tree'])
        self.assertIn(expected, output.getvalue())

    def test_foreign_client_or_unfilled_placeholder_leaves_workspace_untouched(self):
        for node in ({'id': 9, 'window': 99, 'window_properties': {'class': 'OtherApp'}},
                     {'id': 9, 'window': 99, 'swallows': [{'class': '^OtherApp$'}]}):
            with self.subTest(node=node):
                self.refuse([workspace(2, [node])], 'occupied')

    def test_fullscreen_or_duplicate_owned_panes_are_not_rearranged(self):
        for nodes in ([client('bindings', fullscreen_mode=1)],
                      [client('bindings', 10), client('bindings', 11)]):
            with self.subTest(nodes=nodes):
                self.refuse([workspace(2, nodes)], 'occupied')

    def test_owned_window_elsewhere_prevents_duplicate_layout(self):
        self.refuse([workspace(1, [client('bindings')]), workspace(2, [])],
                    'already open elsewhere')

    def test_completed_layout_marker_preserves_user_rearrangement(self):
        done = workspace(2, [client('bindings')])
        done['marks'] = [app.MARK]
        self.refuse([done], '')


class LockChecks(unittest.TestCase):
    def test_linked_lock_file_is_refused_before_ipc(self):
        for kind in ('symlink', 'hardlink'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                runtime = Path(directory)
                target = runtime / 'original'
                target.write_text('')
                target.chmod(0o600)
                lock = runtime / 'qubes-hud-workspace-91.lock'
                if kind == 'symlink':
                    lock.symlink_to(target)
                else:
                    os.link(target, lock)
                with mock.patch.dict(os.environ, {'DISPLAY': ':91', 'XDG_RUNTIME_DIR': directory}), \
                        mock.patch('sys.argv', ['hud-workspace']), \
                        mock.patch.object(Path, 'is_file', return_value=True), \
                        mock.patch.object(os, 'access', return_value=True), \
                        mock.patch.object(app, 'ipc', side_effect=AssertionError('contacted i3')):
                    with self.assertRaises((OSError, RuntimeError)):
                        app.main()


if __name__ == '__main__':
    unittest.main()
