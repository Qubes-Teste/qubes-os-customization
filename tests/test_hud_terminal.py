"""Terminal-control boundaries and display-free log-mode lifecycle checks."""
import importlib.util
from pathlib import Path
import sys
import types
import unittest
from unittest import mock


FILES = Path(__file__).resolve().parents[1] / 'salt/qubes_gui/hud/files'


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, FILES / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


logs = load('terminal_test_logs', 'hud_logs.py')
with mock.patch.dict(sys.modules, {'hud_logs': logs}):
    terminal = load('terminal_test_module', 'hud_monitor.py')


class TerminalTextChecks(unittest.TestCase):
    def test_escape_sequences_cannot_clear_screen_retitle_or_write_clipboard(self):
        text = ('first\x1b[2J\x1b[H\x1b]0;forged\x07'
                '\x1b]52;c;Zm9yZ2Vk\x1b\\\x9b31m\nsecond\rOVERWRITE\x08!')
        output = terminal.log_bytes(text)
        self.assertNotIn(b'\x1b', output)
        self.assertNotIn(b'\x07', output)
        self.assertNotIn(b'\x08', output)
        self.assertIn(br'\x1b[2J', output)
        self.assertIn(br'\x9b31m', output)
        self.assertIn(br'second\x0dOVERWRITE\x08!', output)
        self.assertEqual(output.count(b'\r\n'), 1)

    def test_only_source_newlines_become_terminal_controls(self):
        text = ''.join(chr(value) for value in range(32)) + '\x7f\u0085\u202e\u2028\ud800'
        output = terminal.log_bytes(text)
        self.assertEqual(output.count(b'\r\n'), 1)
        self.assertFalse(any(value < 32 or value == 127
                             for value in output.replace(b'\r\n', b'')))
        self.assertIn(br'\u202e', output)
        self.assertIn(br'\ud800', output)

    def test_unicode_and_already_escaped_log_text_remain_readable(self):
        text = 'Ö € 日本語 \\x1b literal\twords\n\n'
        self.assertEqual(terminal.log_bytes(text),
                         'Ö € 日本語 \\x1b literal    words\r\n\r\n'.encode())


class NativeStub:
    def __init__(self):
        self.calls = []

    def __getattr__(self, name):
        def function(*args):
            self.calls.append((name, args))
            return 1
        return function


class LogTerminalChecks(unittest.TestCase):
    def test_log_modes_feed_literal_text_without_spawning_a_pty_and_close_reader(self):
        for view in ('dom0', 'xen'):
            with self.subTest(view=view):
                native = NativeStub()
                feed = mock.Mock(status='Synthetic source')
                feed.poll.return_value = 'line\x1b[2J\n'
                app = types.SimpleNamespace(gtk=native, pack=lambda _body, widget, *_: widget,
                                            label=lambda *_: 1)
                with mock.patch.object(terminal, 'check'), \
                        mock.patch.object(terminal, '_libraries', return_value=(native,) * 5), \
                        mock.patch.object(terminal, 'LogFeed', return_value=feed) as factory:
                    _, interval, tick, cleanup = terminal.build(app, 1, view, [])
                    tick(None)
                    cleanup()
                factory.assert_called_once_with(view)
                feed.close.assert_called_once_with()
                self.assertEqual(interval, 250)
                names = [name for name, _ in native.calls]
                self.assertNotIn('vte_terminal_spawn_sync', names)
                self.assertNotIn('gtk_viewport_new', names)
                self.assertIn(('vte_terminal_set_input_enabled', (1, 0)), native.calls)
                self.assertIn(('vte_terminal_set_scrollback_lines', (1, 600)), native.calls)
                chunks = [args[1] for name, args in native.calls if name == 'vte_terminal_feed']
                self.assertEqual(chunks, [b'line\\x1b[2J\r\n'])

    def test_unknown_view_is_rejected_before_native_initialization(self):
        with mock.patch.object(terminal, 'check', side_effect=AssertionError('native check')):
            with self.assertRaises(ValueError):
                terminal.build(None, None, 'arbitrary-command', [])


if __name__ == '__main__':
    unittest.main()
