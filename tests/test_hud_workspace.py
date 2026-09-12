"""Headless startup and refusal boundaries for the native HUD layout."""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
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
    return {'id': int(name), 'type': 'workspace', 'name': str(name), 'num': int(name),
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


class QubeChecks(unittest.TestCase):
    def test_absent_profile_does_not_contact_i3_or_start_a_qube(self):
        with mock.patch.object(app, 'QUBE_PROFILE', Path('/nonexistent-qube-profile')), \
                mock.patch('sys.argv', ['hud-workspace', '--qube', '--prepare']), \
                mock.patch.object(app, 'ipc', side_effect=AssertionError('contacted i3')), \
                mock.patch.object(app.subprocess, 'run', side_effect=AssertionError('started VM')):
            app.main()

    def test_profile_refuses_special_files_and_unsafe_names(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'profile'
            with mock.patch.object(app, 'QUBE_PROFILE', path):
                os.mkfifo(path)
                with self.assertRaises(RuntimeError):
                    app.qube_profile()  # O_NONBLOCK prevents hanging on a FIFO.
                path.unlink()
                for name in ('dom0', 'Domain-0', 'none', 'default', 'test-dm',
                             'bad;exec', '../escape', 'bad"name', '-flag'):
                    path.write_text(json.dumps({'name': name, 'workspace': 2}))
                    info = SimpleNamespace(st_mode=0o100644, st_uid=0, st_gid=0, st_nlink=1)
                    parent = SimpleNamespace(st_mode=0o40755, st_uid=0, st_gid=0)
                    with mock.patch.object(os, 'fstat', return_value=info), \
                            mock.patch.object(Path, 'lstat', return_value=parent), \
                            self.assertRaises(RuntimeError):
                        app.qube_profile()

    def test_class_patterns_cannot_match_a_different_qube(self):
        import re
        for node in app.walk(app.qube_layout('hud.test')):
            for match in node.get('swallows', []):
                self.assertFalse(re.search(match['class'], 'hudXtest:HudQubeBrowser'))
                self.assertFalse(re.search(match['class'], 'other:HudQubeBrowser'))
                self.assertFalse(re.search(match['class'], 'hud.test:HudQubeBrowserSpoof'))

    def test_foreign_workspace_is_never_rearranged_or_started(self):
        foreign = {'id': 7, 'type': 'con', 'window': 99, 'window_properties': {'class': 'OtherApp'}}
        tree = {'type': 'root', 'nodes': [workspace(2, [foreign])]}
        with mock.patch.object(app, 'ipc', return_value=tree) as ipc, \
                mock.patch.object(app.subprocess, 'run', side_effect=AssertionError('started VM')):
            with self.assertRaisesRegex(RuntimeError, 'occupied'):
                app.launch_qube({'name': 'hud-test', 'workspace': 2}, Path('/unused'), False)
            ipc.assert_called_once_with('get_tree', query=True)

    def test_repeated_launch_follows_moved_group_without_toggling_or_app_launches(self):
        pane = {'id': 7, 'type': 'con', 'marks': [app.MARK + '-qube-hud-test-top']}
        tree = {'type': 'root', 'nodes': [workspace(3, [pane])]}
        with mock.patch.object(app, 'ipc', return_value=tree) as ipc, \
                mock.patch.object(app.subprocess, 'run') as run:
            app.launch_qube({'name': 'hud-test', 'workspace': 2}, Path('/unused'), False)
            self.assertEqual(ipc.call_args_list[-1].args,
                             ('workspace --no-auto-back-and-forth "3"',))
            run.assert_called_once_with(['/usr/bin/qvm-start', '--skip-if-running', 'hud-test'],
                                        check=True, timeout=120)
            ipc.reset_mock()
            run.reset_mock()
            app.launch_qube({'name': 'hud-test', 'workspace': 2}, Path('/unused'), True)
            ipc.assert_called_once_with('get_tree', query=True)
            run.assert_not_called()

    def test_qube_name_cannot_reuse_dom0_layout_marks(self):
        hud_marks = {mark for node in app.walk(app.layout()) for mark in node.get('marks', [])}
        for name in ('bindings', 'terminal', 'top', 'xen'):
            qube_marks = {mark for node in app.walk(app.qube_layout(name))
                          for mark in node.get('marks', [])}
            self.assertFalse(hud_marks & qube_marks)

    def test_renamed_workspace_two_is_still_checked_for_foreign_windows(self):
        ws = workspace(2, [{'id': 7, 'type': 'con', 'window': 99,
                            'window_properties': {'class': 'OtherApp'}}])
        ws['name'] = '2: mail'
        with mock.patch.object(app, 'ipc', return_value={'type': 'root', 'nodes': [ws]}) as ipc:
            with self.assertRaisesRegex(RuntimeError, 'occupied'):
                app.launch_qube({'name': 'hud-test', 'workspace': 2}, Path('/unused'), False)
            ipc.assert_called_once_with('get_tree', query=True)

    def test_qube_group_is_selected_inside_target_with_three_workspaces(self):
        # i3's output content container is also type=con. With workspaces 1,
        # 2 and 5 it has three children and contains every new leaf mark, so a
        # whole-tree three-child search incorrectly finds it as a second group.
        protected = client('bindings', 110, focused=True)
        target = workspace(2, [])
        content = {'id': 200, 'type': 'con', 'nodes': [
            workspace(1, [protected]), target, workspace(5, [client('bindings', 150)])]}
        tree = {'id': 0, 'type': 'root', 'nodes': [
            {'id': 100, 'type': 'output', 'nodes': [content]}]}
        group = app.qube_layout('hud-test')
        for identity, node in enumerate(app.walk(group), 300):
            node['id'] = identity
        commands = []

        def native_ipc(command, *, query=False):
            if query:
                self.assertEqual(command, 'get_tree')
                return tree
            commands.append(command)
            if command.startswith('append_layout '):
                path = Path(json.loads(command.removeprefix('append_layout ')))
                self.assertEqual(json.loads(path.read_text()), app.qube_layout('hud-test'))
                target['nodes'].append(group)
            return [{'success': True}]

        with tempfile.TemporaryDirectory() as directory, \
                mock.patch.object(app, 'ipc', side_effect=native_ipc), \
                mock.patch.object(app.subprocess, 'run', side_effect=AssertionError('started VM')):
            app.launch_qube({'name': 'hud-test', 'workspace': 2}, Path(directory), True)
        mark_commands = [command for command in commands if ' mark --add ' in command]
        self.assertEqual(mark_commands, ['[con_id=300] mark --add ' + app.MARK + '-qube-hud-test'])
        self.assertEqual(commands[-1], '[con_id=110] focus')
        self.assertEqual([node['num'] for node in content['nodes']], [1, 2, 5])
        self.assertIs(target['nodes'][0], group)


class ButtonChecks(unittest.TestCase):
    def test_button_mode_never_launches_layout_or_opens_runtime_lock(self):
        with mock.patch('sys.argv', ['hud-workspace', '--buttons']), \
                mock.patch.object(app, 'buttons') as stream, \
                mock.patch.object(app, 'launch', side_effect=AssertionError('launched layout')), \
                mock.patch.object(os, 'open', side_effect=AssertionError('opened lock')), \
                mock.patch.object(Path, 'is_file', return_value=True), \
                mock.patch.object(os, 'access', return_value=True):
            app.main()
        stream.assert_called_once_with()

    def test_defaults_do_not_invent_windows_focus_urgency_or_output(self):
        actual = [{'id': 91, 'name': '1: dom0', 'num': 1, 'output': 'DP-2',
                   'focused': True, 'visible': True, 'urgent': False},
                  {'id': 97, 'name': '7', 'num': 7, 'output': 'DP-1',
                   'focused': False, 'visible': False, 'urgent': True},
                  {'id': 98, 'name': '研究 "desk"', 'num': -1, 'output': 'DP-2'}]
        result = app.workspace_buttons(actual)
        self.assertEqual([item['name'] for item in result],
                         ['1: dom0', '2', '3', '4', '5', '7', '研究 "desk"'])
        self.assertEqual([item for item in result if 'id' in item], actual)
        self.assertEqual(result[1:5], [{'name': str(n), 'num': n} for n in range(2, 6)])
        self.assertEqual(len(actual), 3)

    def test_empty_state_and_returned_default_workspace(self):
        self.assertEqual(len(app.workspace_buttons([])), 5)
        actual = {'id': 95, 'name': '5', 'num': 5, 'focused': True,
                  'visible': True, 'urgent': False, 'output': 'DP-1'}
        self.assertEqual(app.workspace_buttons([actual])[-1], actual)

    def test_subscribe_precedes_query_and_later_ticks_are_ignored(self):
        child = mock.Mock()
        child.stdout = io.StringIO('{"first":true}\n{"first":false}\n{"change":"focus"}\n')
        child.poll.return_value = None
        order = []

        def spawn(*args, **kwargs):
            self.assertEqual(args[0][-1], '["workspace","output","tick"]')
            order.append('subscribe')
            return child

        def query(command, *, query=False):
            self.assertTrue(query)
            self.assertEqual(command, 'get_workspaces')
            order.append('snapshot')
            return []

        with mock.patch.object(app.subprocess, 'Popen', side_effect=spawn), \
                mock.patch.object(app, 'ipc', side_effect=query), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            with self.assertRaisesRegex(RuntimeError, 'subscription ended'):
                app.buttons()
        self.assertEqual(order, ['subscribe', 'snapshot', 'snapshot'])
        self.assertEqual(len(output.getvalue().splitlines()), 2)
        child.terminate.assert_called_once()
        child.wait.assert_called_once_with(timeout=1)
        self.assertTrue(child.stdout.closed)

    def test_signal_exception_reaps_subscriber_and_restores_handler(self):
        child = mock.Mock()
        child.stdout = io.StringIO('{"first":true}\n')
        child.poll.return_value = None
        handler = app.signal.getsignal(app.signal.SIGTERM)

        def interrupted(*args, **kwargs):
            app.signal.getsignal(app.signal.SIGTERM)(app.signal.SIGTERM, None)

        with mock.patch.object(app.subprocess, 'Popen', return_value=child), \
                mock.patch.object(app, 'ipc', side_effect=interrupted):
            with self.assertRaises(SystemExit):
                app.buttons()
        child.terminate.assert_called_once()
        child.wait.assert_called_once_with(timeout=1)
        self.assertIs(app.signal.getsignal(app.signal.SIGTERM), handler)

    def test_closed_bar_reaps_subscriber_and_discards_pending_flush(self):
        child = mock.Mock()
        child.stdout = io.StringIO('{"first":true}\n')
        child.poll.return_value = None
        with mock.patch.object(app.subprocess, 'Popen', return_value=child), \
                mock.patch.object(app, 'ipc', return_value=[]), \
                mock.patch('builtins.print', side_effect=BrokenPipeError), \
                mock.patch.object(app.os, 'dup2') as discard:
            app.buttons()
        discard.assert_called_once()
        child.terminate.assert_called_once()
        child.wait.assert_called_once_with(timeout=1)


if __name__ == '__main__':
    unittest.main()
