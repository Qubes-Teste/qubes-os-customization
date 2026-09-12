"""Headless boundaries for the shared stock-program terminal viewer."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest import mock

PATH = Path(__file__).resolve().parents[1] / 'salt/qubes_gui/hud/files/hud_terminal.py'
spec = importlib.util.spec_from_file_location('hud_terminal_test_module', PATH)
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)


class Function:
    def __init__(self, backend, name):
        self.backend, self.name = backend, name

    def __call__(self, *args):
        self.backend.calls.append((self.name, args))
        return self.backend.results.get(self.name, 0)


class Backend:
    def __init__(self):
        self.calls = []
        self.results = {'vte_terminal_new': 11, 'gtk_scrolled_window_new': 12,
                        'gtk_viewport_new': 13, 'gtk_box_new': 14,
                        'gtk_scrollable_get_vadjustment': 15, 'gtk_scrollbar_new': 16}
        self.functions = {}

    def __getattr__(self, name):
        return self.functions.setdefault(name, Function(self, name))

    def arguments(self, name):
        return [args for called, args in self.calls if called == name]

    def pack(self, parent, child, expand=False):
        self.calls.append(('pack', (parent, child, expand)))
        return child


class TerminalTests(unittest.TestCase):
    def test_runtime_check_never_initializes_native_libraries_or_spawns(self):
        backend = Backend()
        terminal._libraries.cache_clear()
        try:
            with mock.patch.object(terminal.C, 'CDLL', return_value=backend), \
                    mock.patch.object(terminal.os.path, 'isfile', return_value=True), \
                    mock.patch.object(terminal.os, 'access', return_value=True):
                terminal.check()
            self.assertEqual(backend.calls, [])
        finally:
            terminal._libraries.cache_clear()

    def test_missing_native_library_and_command_are_rejected(self):
        terminal._libraries.cache_clear()
        with mock.patch.object(terminal.C, 'CDLL', side_effect=OSError('missing library')):
            with self.assertRaises(OSError):
                terminal.check()
        with mock.patch.object(terminal, '_libraries'), \
                mock.patch.object(terminal.os.path, 'isfile', return_value=False):
            with self.assertRaisesRegex(RuntimeError, 'Missing stock terminal command'):
                terminal.check()

    def test_unknown_view_fails_before_native_initialization(self):
        with mock.patch.object(terminal, 'check', side_effect=AssertionError('native check')):
            with self.assertRaises(ValueError):
                terminal.build(None, None, 'arbitrary-command', [])

    def build(self, view):
        backend = Backend()
        app = SimpleNamespace(gtk=backend, pack=backend.pack,
                              box=lambda vertical: backend.gtk_box_new(int(vertical), 0))
        with mock.patch.object(terminal, 'check'), \
                mock.patch.object(terminal, '_libraries', return_value=(backend,) * 5):
            built = terminal.build(app, 10, view, [])
        return backend, built

    def test_monitor_pans_live_canvas_and_blocks_input_before_single_spawn(self):
        backend, (_, _, tick, cleanup) = self.build('top')
        self.assertEqual(backend.arguments('gtk_widget_set_size_request'), [(11, 1280, 960)])
        self.assertEqual(backend.arguments('gtk_scrolled_window_set_policy'), [(12, 0, 0)])
        self.assertEqual(backend.arguments('vte_terminal_set_scrollback_lines'), [(11, 0)])
        self.assertEqual(backend.arguments('vte_terminal_set_input_enabled'), [(11, 0)])
        self.assertEqual(backend.arguments('gtk_drag_dest_unset'), [(11,)])
        self.assertFalse(backend.arguments('vte_terminal_spawn_sync'))
        tick(None)
        tick(None)
        calls = backend.arguments('vte_terminal_spawn_sync')
        self.assertEqual(len(calls), 1)
        self.assertIsNone(calls[0][6])  # No Python callback after fork.
        self.assertIsNone(calls[0][7])
        cleanup()
        cleanup()

    def test_log_history_bar_stays_outside_horizontal_viewport(self):
        for view in ('dom0', 'xen'):
            with self.subTest(view=view):
                backend, _ = self.build(view)
                self.assertEqual(backend.arguments('gtk_widget_set_size_request'), [(11, 1280, -1)])
                self.assertEqual(backend.arguments('gtk_scrolled_window_set_policy'), [(12, 0, 2)])
                self.assertEqual(backend.arguments('vte_terminal_set_scrollback_lines'), [(11, 600)])
                self.assertEqual(backend.arguments('gtk_scrollbar_new'), [(1, 15)])
                self.assertIn((14, 12, True), backend.arguments('pack'))
                self.assertIn((14, 16, False), backend.arguments('pack'))
                self.assertEqual(backend.arguments('vte_terminal_set_input_enabled'), [(11, 0)])


if __name__ == '__main__':
    unittest.main()
