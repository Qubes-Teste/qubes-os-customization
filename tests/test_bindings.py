"""Bounded data, runtime, and singleton checks without an X11 connection."""
import contextlib
import ctypes
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock


FILES = Path(__file__).resolve().parents[1] / 'salt/qubes_gui/hud/files'


class UncalledFunction:
    def __call__(self, *args):
        raise AssertionError('Runtime validation called a GUI/X11 function')


class SymbolLibrary:
    def __init__(self, missing=None):
        self.missing = missing
        self.symbols = {}

    def __getattr__(self, name):
        if name == self.missing:
            raise AttributeError(name)
        return self.symbols.setdefault(name, UncalledFunction())


def load_module(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def load_application():
    keyboard = load_module('test_bindings_keyboard', FILES / 'bindings_keyboard.py')
    with mock.patch.dict('sys.modules', {'bindings_keyboard': keyboard}), \
            mock.patch.object(ctypes, 'CDLL', side_effect=lambda *_: SymbolLibrary()):
        return load_module('test_hud_bindings', FILES / 'hud-bindings')


class RuntimeChecks(unittest.TestCase):
    def test_check_resolves_runtime_without_display_or_function_calls(self):
        app = load_application()
        loaded = []
        def library(name):
            loaded.append(name)
            return SymbolLibrary()
        with mock.patch.dict(os.environ, {}, clear=True), \
                mock.patch.object(ctypes, 'CDLL', side_effect=library), \
                mock.patch('sys.argv', ['hud-bindings', '--check']), \
                mock.patch.object(app, 'acquire_instance', side_effect=AssertionError('lock opened')), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            app.main()
        self.assertIn('libX11.so.6', loaded)
        self.assertIn('verified', output.getvalue())

    def test_missing_keyboard_symbol_is_rejected_without_opening_display(self):
        app = load_application()
        with mock.patch.object(ctypes, 'CDLL', return_value=SymbolLibrary('XkbGetMap')):
            with self.assertRaises(AttributeError):
                app.KeyboardLayout(check_only=True)

    def test_missing_gtk_symbol_is_rejected_during_runtime_binding(self):
        keyboard = load_module('test_bindings_keyboard_missing', FILES / 'bindings_keyboard.py')
        with mock.patch.dict('sys.modules', {'bindings_keyboard': keyboard}), \
                mock.patch.object(ctypes, 'CDLL', return_value=SymbolLibrary('gtk_main')):
            with self.assertRaises(AttributeError):
                load_module('test_missing_gtk_app', FILES / 'hud-bindings')


class DataChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = load_application()

    def parse(self, data):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'bindings.json'
            path.write_text(json.dumps(data))
            return self.app.load_data(path)

    @staticmethod
    def data(template=None):
        entry = {'keys': 'Example', 'description': 'Example action'}
        if template is not None:
            entry['keys_template'] = template
        return {'sections': [{'title': 'Example section', 'entries': [entry]}]}

    def test_shipped_data_and_keycode_boundaries_are_valid(self):
        data = self.app.load_data(FILES / 'bindings.json')
        self.assertEqual(sum(len(s['entries']) for s in data['sections']), 45)
        self.parse(self.data('{k8} / {k255} / {s_minus}'))

    def test_malformed_sections_and_entries_are_cleanly_rejected(self):
        invalid = [None, [], {}, {'sections': None}, {'sections': [None]},
                   {'sections': ['bad']}, {'sections': [{'title': 'x', 'entries': [None]}]},
                   {'sections': [{'title': 'x', 'entries': ['bad']}]},
                   {'sections': [{'title': 1, 'entries': []}]},
                   {'sections': [{'title': 'x', 'entries': [{'keys': 1, 'description': 'x'}]}]}]
        for data in invalid:
            with self.subTest(data=data), self.assertRaises(ValueError):
                self.parse(data)

    def test_invalid_templates_and_out_of_range_keycodes_are_rejected(self):
        for template in (1, '{k7}', '{k256}', '{k1000}', '{unknown}',
                         '{s_other}', '{k}', '{k47', 'k47}', '{{k47}}'):
            with self.subTest(template=template), self.assertRaises(ValueError):
                self.parse(self.data(template))

    def test_size_entry_and_section_limits(self):
        oversized = self.data()
        oversized['sections'][0]['entries'][0]['description'] = 'x' * 262144
        too_many_rows = self.data()
        too_many_rows['sections'][0]['entries'] *= 513
        too_many_sections = {'sections': [{'title': 'x', 'entries': []}] * 33}
        for data in (oversized, too_many_rows, too_many_sections):
            with self.subTest(size=len(json.dumps(data))), self.assertRaises(ValueError):
                self.parse(data)


class SingletonChecks(unittest.TestCase):
    def setUp(self):
        self.app = load_application()
        self.temp = tempfile.TemporaryDirectory()
        self.runtime = Path(self.temp.name)
        self.env = mock.patch.dict(os.environ, {'XDG_RUNTIME_DIR': str(self.runtime), 'DISPLAY': ':91'})
        self.env.start()
        self.descriptors = []

    def tearDown(self):
        for descriptor in self.descriptors:
            os.close(descriptor)
        self.env.stop()
        self.temp.cleanup()

    def acquire(self):
        descriptor = self.app.acquire_instance(True)
        if descriptor is not None:
            self.descriptors.append(descriptor)
        return descriptor

    def release(self, descriptor):
        os.close(descriptor)
        self.descriptors.remove(descriptor)

    def test_background_duplicate_does_not_focus_and_close_releases_lock(self):
        first = self.acquire()
        self.assertIsNotNone(first)
        with mock.patch.object(self.app.subprocess, 'check_output', side_effect=AssertionError('IPC called')):
            self.assertIsNone(self.app.acquire_instance(True))
        self.release(first)
        self.assertIsNotNone(self.acquire())

    def test_failed_window_initialization_releases_instance_lock(self):
        with mock.patch('sys.argv', ['hud-bindings', '--background']), \
                mock.patch.object(self.app.gtk, 'gtk_init_check', return_value=1), \
                mock.patch.object(self.app, 'run_window', side_effect=RuntimeError('initialization failed')):
            with self.assertRaisesRegex(RuntimeError, 'initialization failed'):
                self.app.main()
        self.assertIsNotNone(self.acquire())

    def test_manual_duplicate_focuses_existing_reference_only(self):
        self.acquire()
        tree = {'nodes': [{'id': 14, 'window_properties': {'class': 'OtherApp'}},
                          {'nodes': [{'id': 42, 'window_properties': {'class': 'QubesHudBindings'}}]}]}
        with mock.patch.object(self.app.subprocess, 'check_output', return_value=json.dumps(tree).encode()), \
                mock.patch.object(self.app.subprocess, 'run') as command:
            self.assertIsNone(self.app.acquire_instance(False))
        self.assertEqual(command.call_args.args[0], ['/usr/bin/i3-msg', '[con_id=42] focus'])

    def test_screen_suffix_shares_lock_but_distinct_display_does_not(self):
        self.acquire()
        with mock.patch.dict(os.environ, {'DISPLAY': ':91.1'}):
            self.assertIsNone(self.app.acquire_instance(True))
        with mock.patch.dict(os.environ, {'DISPLAY': ':92'}):
            self.assertIsNotNone(self.acquire())


    def test_unsafe_runtime_and_remote_display_are_rejected(self):
        self.runtime.chmod(0o755)
        with self.assertRaises(RuntimeError):
            self.app.acquire_instance(True)
        self.runtime.chmod(0o700)
        with mock.patch.dict(os.environ, {'DISPLAY': 'hostname:91'}), self.assertRaises(RuntimeError):
            self.app.acquire_instance(True)
        link = self.runtime / 'runtime-link'
        link.symlink_to(self.runtime, target_is_directory=True)
        with mock.patch.dict(os.environ, {'XDG_RUNTIME_DIR': str(link)}), self.assertRaises(RuntimeError):
            self.app.acquire_instance(True)

    def test_modified_or_linked_lock_files_are_refused(self):
        descriptor = self.acquire()
        self.release(descriptor)
        path = next(self.runtime.glob('*.lock'))
        path.chmod(0o644)
        with self.assertRaises(RuntimeError):
            self.app.acquire_instance(True)
        path.chmod(0o600)
        extra = self.runtime / 'hardlink'
        os.link(path, extra)
        with self.assertRaises(RuntimeError):
            self.app.acquire_instance(True)
        extra.unlink()
        path.unlink()
        target = self.runtime / 'unrelated'
        target.write_text('preserve me')
        path.symlink_to(target)
        with self.assertRaises(OSError):
            self.app.acquire_instance(True)
        self.assertEqual(target.read_text(), 'preserve me')


if __name__ == '__main__':
    unittest.main()
