"""Schedule, color preservation and transactional output ownership checks."""
import copy
import contextlib
import io
import json
import os
import tempfile
from datetime import datetime, timedelta, timezone
import importlib.machinery
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest import mock

SOURCE = Path(__file__).resolve().parents[1] / 'salt/qubes_gui/hud/files/hud-night-light'
loader = importlib.machinery.SourceFileLoader('test_hud_night_light_module', str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
app = importlib.util.module_from_spec(spec)
with mock.patch.object(sys, 'path', [str(SOURCE.parent)] + sys.path):
    loader.exec_module(app)

SCALE = 1 << 32
WEIGHTS = (913110047, 3071760610, 310096639)

def encode(coefficients):
    words = []
    for coefficient in coefficients:
        value = round(abs(coefficient) * SCALE)
        if coefficient < 0:
            value |= 1 << 63
        words.extend((value & 0xffffffff, value >> 32))
    return words


def decode(words):
    result = []
    for low, high in zip(words[::2], words[1::2]):
        value = low | (high << 32)
        result.append((-(value & ((1 << 63) - 1)) if value >> 63 else value) / SCALE)
    return result

IDENTITY = encode((1, 0, 0, 0, 1, 0, 0, 0, 1))


class ScheduleChecks(unittest.TestCase):
    def test_strict_clock_minutes(self):
        self.assertEqual(app.minute('00:00'), 0)
        self.assertEqual(app.minute('23:59'), 1439)
        for invalid in ('24:00', '12:60', '-1:00', '9:00', '21:00:00', '21:00\n', ''):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                app.minute(invalid)

    def test_overnight_interval_has_inclusive_start_exclusive_end(self):
        settings = {'mode': 'auto', 'start': '21:00', 'end': '08:00'}
        for hour, minute, expected in ((0, 0, 'night'), (7, 59, 'night'),
                                       (8, 0, 'day'), (20, 59, 'day'),
                                       (21, 0, 'night'), (23, 59, 'night')):
            with self.subTest(hour=hour, minute=minute):
                self.assertEqual(app.phase(settings, datetime(2026, 9, 12, hour, minute)), expected)

    def test_nonwrapping_interval_and_local_clock(self):
        settings = {'mode': 'auto', 'start': '09:15', 'end': '17:45'}
        for hour, minute, expected in ((9, 14, 'day'), (9, 15, 'night'),
                                       (17, 44, 'night'), (17, 45, 'day')):
            now = datetime(2026, 9, 12, hour, minute, tzinfo=timezone(timedelta(hours=2)))
            self.assertEqual(app.phase(settings, now), expected)

    def test_equal_endpoints_are_refused(self):
        with self.assertRaises(ValueError):
            app.phase({'mode': 'auto', 'start': '08:00', 'end': '08:00'}, datetime(2026, 9, 12, 12))

    def test_manual_override_ignores_current_schedule_phase(self):
        for mode in ('day', 'night'):
            for hour in (0, 12, 21):
                with self.subTest(mode=mode, hour=hour):
                    self.assertEqual(app.phase({'mode': mode, 'start': '21:00', 'end': '08:00'},
                                               datetime(2026, 9, 12, hour)), mode)


class MatrixChecks(unittest.TestCase):
    def test_identity_becomes_exact_green_rec709_matrix(self):
        result = app.green_matrix(IDENTITY)
        expected = [0] * 18
        expected[6:12] = [value for weight in WEIGHTS for value in (weight, 0)]
        self.assertEqual(result, expected)
        self.assertEqual(sum(WEIGHTS), SCALE)

    def test_all_rgb_channels_contribute_and_neutral_intensity_is_preserved(self):
        matrix = decode(app.green_matrix(IDENTITY))
        for rgb in ((1, 0, 0), (0, 1, 0), (0, 0, 1), (1, 1, 1),
                    (1, 1, 0), (0, 1, 1), (1, 0, 1), (.25, .25, .25), (0, 0, 0)):
            output = [sum(matrix[row * 3 + col] * rgb[col] for col in range(3)) for row in range(3)]
            self.assertEqual(output[0], 0)
            self.assertEqual(output[2], 0)
            if any(rgb):
                self.assertGreater(output[1], 0)
            else:
                self.assertEqual(output[1], 0)
            if rgb[0] == rgb[1] == rgb[2]:
                self.assertAlmostEqual(output[1], rgb[0], places=12)

    def test_existing_signed_calibration_is_composed_not_discarded(self):
        baseline = (1, -.125, .25, .125, .75, 0, -.25, .125, .5)
        original = encode(baseline)
        transformed = decode(app.green_matrix(original))
        self.assertEqual(original, encode(baseline), 'Caller baseline must remain reusable for restoration')
        self.assertEqual(transformed[:3] + transformed[6:], [0] * 6)
        for col in range(3):
            expected = sum((WEIGHTS[row] / SCALE) * baseline[row * 3 + col] for row in range(3))
            self.assertAlmostEqual(transformed[3 + col], expected, delta=1 / SCALE)


def output_row(name='DP-1', matrix=None, identity=None, output_id=41):
    return {'id': output_id, 'name': name,
            'ctm': list(IDENTITY if matrix is None else matrix),
            'identity': identity or name + ':no-edid'}


class FakeOutput:
    def __init__(self, rows, events):
        self.rows = copy.deepcopy(rows)
        self.hardware = {row['id']: copy.deepcopy(row['ctm']) for row in rows}
        self.events = events
        self.writes = []
        self.fail = False
        self.drop_hardware_write = False

    def snapshot(self):
        return copy.deepcopy(self.rows)

    def set(self, identity, matrix):
        self.events.append(('set', identity, list(matrix)))
        if self.fail:
            raise RuntimeError('Simulated native output failure')
        self.writes.append((identity, list(matrix)))
        next(row for row in self.rows if row['id'] == identity)['ctm'] = list(matrix)
        if not self.drop_hardware_write:
            self.hardware[identity] = list(matrix)


class TransitionChecks(unittest.TestCase):
    def setUp(self):
        self.events = []
        self.state = {'schema': 1, 'outputs': {}}

    def save(self, state):
        self.events.append(('save', copy.deepcopy(state)))

    def test_save_precedes_mutation_and_repeated_night_reasserts_without_compounding(self):
        base = encode((.75, .125, 0, 0, 1, 0, .125, 0, .875))
        backend = FakeOutput([output_row(matrix=base)], self.events)
        app.transition(backend, self.state, True, self.save)
        self.assertEqual(self.events[0][0], 'save')
        saved = self.events[0][1]['outputs']['DP-1']
        self.assertEqual(saved['base'], base)
        self.assertEqual(saved['night'], app.green_matrix(base))
        self.assertEqual(len(backend.writes), 1)
        self.events.clear()
        app.transition(backend, self.state, True, self.save)
        self.assertEqual(len(backend.writes), 2)
        self.assertEqual(backend.writes[0], backend.writes[1])
        self.assertEqual(self.state['outputs']['DP-1']['base'], base)
        app.transition(backend, self.state, False, self.save)
        self.assertEqual(backend.rows[0]['ctm'], base)
        self.assertEqual(len(backend.writes), 3)

    def test_hardware_reset_recovers_even_when_cached_property_still_reports_night(self):
        backend = FakeOutput([output_row()], self.events)
        app.transition(backend, self.state, True, self.save)
        night = app.green_matrix(IDENTITY)
        # DRM may reset while Xorg continues to report the previous CTM property.
        backend.hardware[41] = list(IDENTITY)
        self.assertEqual(backend.snapshot()[0]['ctm'], night)
        app.transition(backend, self.state, True, self.save)
        self.assertEqual(backend.hardware[41], night)
        self.assertEqual(backend.writes, [(41, night), (41, night)])
        self.assertEqual(self.state['outputs']['DP-1']['base'], IDENTITY)

    def test_silent_day_restore_failure_retries_despite_successful_property_readback(self):
        backend = FakeOutput([output_row()], self.events)
        app.transition(backend, self.state, True, self.save)
        night = app.green_matrix(IDENTITY)
        backend.drop_hardware_write = True
        app.transition(backend, self.state, False, self.save)
        self.assertEqual(backend.snapshot()[0]['ctm'], IDENTITY)
        self.assertEqual(backend.hardware[41], night)
        self.assertEqual(self.state['outputs']['DP-1']['base'], IDENTITY)
        backend.drop_hardware_write = False
        app.transition(backend, self.state, False, self.save)
        self.assertEqual(backend.hardware[41], IDENTITY)
        self.assertEqual(backend.writes[-2:], [(41, IDENTITY), (41, IDENTITY)])
        self.assertEqual(self.state['outputs']['DP-1']['night'], night)

    def test_save_failure_never_changes_a_display(self):
        backend = FakeOutput([output_row()], self.events)
        with self.assertRaises(OSError):
            app.transition(backend, self.state, True, mock.Mock(side_effect=OSError('disk full')))
        self.assertEqual(backend.writes, [])
        self.assertEqual(backend.rows[0]['ctm'], IDENTITY)

    def test_write_failure_retains_original_for_retry_and_restoration(self):
        backend = FakeOutput([output_row()], self.events)
        backend.fail = True
        with self.assertRaises(RuntimeError):
            app.transition(backend, self.state, True, self.save)
        self.assertEqual(self.events[0][0], 'save')
        self.assertEqual(self.state['outputs']['DP-1']['base'], IDENTITY)
        backend.fail = False
        app.transition(backend, self.state, True, self.save)
        app.transition(backend, self.state, False, self.save)
        self.assertEqual(backend.rows[0]['ctm'], IDENTITY)

    def test_day_never_overwrites_a_foreign_current_matrix(self):
        backend = FakeOutput([output_row()], self.events)
        app.transition(backend, self.state, True, self.save)
        foreign = encode((.875, 0, 0, 0, .75, 0, 0, 0, .5))
        backend.rows[0]['ctm'] = foreign
        count = len(backend.writes)
        app.transition(backend, self.state, False, self.save)
        self.assertEqual(len(backend.writes), count)
        self.assertEqual(backend.rows[0]['ctm'], foreign)
        self.assertNotIn('DP-1', self.state['outputs'])

    def test_external_night_calibration_becomes_the_new_restorable_baseline(self):
        backend = FakeOutput([output_row()], self.events)
        app.transition(backend, self.state, True, self.save)
        foreign = encode((.875, 0, 0, 0, .75, 0, 0, 0, .5))
        backend.rows[0]['ctm'] = foreign
        app.transition(backend, self.state, True, self.save)
        self.assertEqual(self.state['outputs']['DP-1']['base'], foreign)
        self.assertEqual(backend.rows[0]['ctm'], app.green_matrix(foreign))
        app.transition(backend, self.state, False, self.save)
        self.assertEqual(backend.rows[0]['ctm'], foreign)

    def test_same_connector_new_monitor_never_receives_previous_baseline(self):
        base = encode((.75, 0, 0, 0, .875, 0, 0, 0, 1))
        backend = FakeOutput([output_row(matrix=base, identity='DP-1:' + 'a' * 64)], self.events)
        app.transition(backend, self.state, True, self.save)
        backend.rows[0]['identity'] = 'DP-1:' + 'b' * 64
        count = len(backend.writes)
        app.transition(backend, self.state, False, self.save)
        self.assertEqual(len(backend.writes), count)
        self.assertNotEqual(backend.rows[0]['ctm'], base)
        self.assertNotIn('DP-1', self.state['outputs'])

    def test_disconnected_original_is_retained_for_later_restore(self):
        backend = FakeOutput([output_row()], self.events)
        app.transition(backend, self.state, True, self.save)
        connected = backend.rows.pop()
        app.transition(backend, self.state, False, self.save)
        self.assertIn('DP-1', self.state['outputs'])
        backend.rows.append(connected)
        app.transition(backend, self.state, False, self.save)
        self.assertEqual(backend.rows[0]['ctm'], IDENTITY)

    def test_temporarily_unreadable_matrix_keeps_baseline_and_restores_next_tick(self):
        backend = FakeOutput([output_row(), output_row('HDMI-1', output_id=42)], self.events)
        app.transition(backend, self.state, True, self.save)
        owned_night = list(backend.rows[0]['ctm'])
        backend.rows[0]['ctm'] = None
        with self.assertRaisesRegex(RuntimeError, 'DP-1'):
            app.transition(backend, self.state, False, self.save)
        self.assertEqual(backend.rows[1]['ctm'], IDENTITY)
        self.assertEqual(self.state['outputs']['HDMI-1']['base'], IDENTITY)
        self.assertEqual(self.state['outputs']['DP-1']['base'], IDENTITY)
        self.assertEqual(self.events[-1][0], 'save')
        self.assertIn('DP-1', self.events[-1][1]['outputs'])
        backend.rows[0]['ctm'] = owned_night
        app.transition(backend, self.state, False, self.save)
        self.assertEqual(backend.rows[0]['ctm'], IDENTITY)
        self.assertEqual(set(self.state['outputs']), {'DP-1', 'HDMI-1'})
        self.assertTrue(all(record['base'] == IDENTITY for record in self.state['outputs'].values()))

    def test_unsupported_output_refuses_night_before_any_partial_change(self):
        unsupported = output_row('HDMI-1', output_id=42)
        unsupported['ctm'] = None
        backend = FakeOutput([output_row(), unsupported], self.events)
        with self.assertRaisesRegex(RuntimeError, 'HDMI-1'):
            app.transition(backend, self.state, True, self.save)
        self.assertEqual(backend.writes, [])
        self.assertEqual(self.events, [])
        self.assertEqual(self.state['outputs'], {})


class FileAndRuntimeChecks(unittest.TestCase):
    def test_fifo_is_refused_without_waiting_for_a_writer(self):
        # Bound this native read test so a regression cannot hang the test runner.
        code = """
import runpy, sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]).parent))
namespace = runpy.run_path(sys.argv[1], run_name='fifo_probe')
try:
    namespace['read_owned'](Path(sys.argv[2]), 0o600)
except ValueError:
    pass
else:
    raise AssertionError('FIFO was accepted as a state file')
"""
        with tempfile.TemporaryDirectory() as directory:
            fifo = Path(directory) / 'state-fifo'
            os.mkfifo(fifo, 0o600)
            app.subprocess.run([sys.executable, '-B', '-c', code, str(SOURCE), str(fifo)],
                               env=dict(os.environ, DISPLAY=''), check=True,
                               capture_output=True, timeout=3)

    def test_night_reassertion_does_not_rewrite_unchanged_runtime_json(self):
        night = app.green_matrix(IDENTITY)
        state = {'schema': 1, 'phase': 'night', 'outputs': {'DP-1': {
            'identity': 'DP-1:no-edid', 'base': IDENTITY, 'night': night}}}
        backend = FakeOutput([output_row(matrix=night)], [])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'qubes-hud-night-light-91-0.json'
            path.write_text(json.dumps(state, sort_keys=True) + '\n')
            path.chmod(0o600)
            before = path.stat()
            with mock.patch.dict(os.environ, {'DISPLAY': ':91', 'XDG_RUNTIME_DIR': directory}), \
                    mock.patch.object(app, 'settings', return_value=dict(app.DEFAULTS, mode='night')), \
                    mock.patch.object(app, 'Outputs') as output, \
                    mock.patch.object(app, 'write_owned', side_effect=AssertionError('rewrote identical JSON')):
                output.return_value.__enter__.return_value = backend
                app.control()
                app.control()
            self.assertEqual(backend.writes, [(41, night), (41, night)])
            self.assertEqual((path.stat().st_ino, path.stat().st_mtime_ns),
                             (before.st_ino, before.st_mtime_ns))

    def test_invalid_matrix_words_are_rejected_before_arithmetic(self):
        for value in (None, [], IDENTITY[:-1], IDENTITY + [0],
                      [True] + IDENTITY[1:], [-1] + IDENTITY[1:],
                      [1 << 32] + IDENTITY[1:]):
            with self.subTest(value=value), self.assertRaises(ValueError):
                app.green_matrix(value)

    def test_owned_files_refuse_links_modes_and_oversize_data(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            path = parent / 'state'
            path.write_text('original')
            path.chmod(0o600)
            self.assertEqual(app.read_owned(path, 0o600), 'original')
            with self.assertRaises(ValueError):
                app.read_owned(path, 0o600, limit=3)
            path.chmod(0o644)
            with self.assertRaises(ValueError):
                app.read_owned(path, 0o600)
            path.chmod(0o600)
            linked = parent / 'hardlink'
            os.link(path, linked)
            with self.assertRaises(ValueError):
                app.write_owned(path, 'changed', 0o600)
            linked.unlink()
            symlink = parent / 'symlink'
            symlink.symlink_to(path)
            with self.assertRaises((OSError, ValueError)):
                app.write_owned(symlink, 'changed', 0o600)
            self.assertEqual(path.read_text(), 'original')

    def test_symlinked_private_directory_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            real = parent / 'real'
            real.mkdir(mode=0o700)
            alias = parent / 'alias'
            alias.symlink_to(real, target_is_directory=True)
            with self.assertRaises(ValueError):
                app.write_owned(alias / 'state', 'changed', 0o600)
            self.assertEqual(list(real.iterdir()), [])

    def test_malformed_runtime_is_refused_before_opening_x11(self):
        malformed = (None, [], {'schema': 1, 'outputs': None},
                     {'schema': 1, 'outputs': {'DP-1': None}},
                     {'schema': 1, 'outputs': {'DP-1': []}})
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'qubes-hud-night-light-91-0.json'
            for state in malformed:
                path.write_text(json.dumps(state))
                path.chmod(0o600)
                with self.subTest(state=state), \
                        mock.patch.dict(os.environ, {'DISPLAY': ':91', 'XDG_RUNTIME_DIR': directory}), \
                        mock.patch.object(app, 'Outputs', side_effect=AssertionError('opened X11')), \
                        mock.patch.object(app, 'settings', side_effect=AssertionError('runtime validation missed fixture')), \
                        self.assertRaises(ValueError):
                    app.control(status=True)

    def test_display_and_explicit_default_screen_share_state_and_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            for display in (':91', ':91.0'):
                with mock.patch.dict(os.environ, {'DISPLAY': display, 'XDG_RUNTIME_DIR': directory}), \
                        mock.patch.object(app, 'Outputs', side_effect=AssertionError('opened X11')):
                    app.control(restore=True)
            self.assertEqual([path.name for path in Path(directory).iterdir()],
                             ['qubes-hud-night-light-91-0.lock'])

    def test_check_is_display_free_and_performs_no_settings_or_service_mutation(self):
        with mock.patch.dict(os.environ, {}, clear=True), \
                mock.patch.object(sys, 'argv', ['hud-night-light', '--check']), \
                mock.patch.object(app, 'Outputs') as output, \
                mock.patch.object(app, 'settings', side_effect=AssertionError('read settings')), \
                mock.patch.object(app, 'run', side_effect=AssertionError('service mutation')), \
                mock.patch.object(os, 'open', side_effect=AssertionError('opened file')), \
                contextlib.redirect_stdout(io.StringIO()) as stdout:
            app.main()
        output.assert_called_once_with(check_only=True)
        self.assertIn('available', stdout.getvalue())


class ServiceControlChecks(unittest.TestCase):
    def test_start_imports_only_x11_environment_and_applies_even_if_timer_active(self):
        with mock.patch.dict(os.environ, {'DISPLAY': ':91', 'XAUTHORITY': '/private/auth'}, clear=True), \
                mock.patch.object(sys, 'argv', ['hud-night-light', '--start']), \
                mock.patch.object(os, 'geteuid', return_value=1000), \
                mock.patch.object(app, 'run', return_value='') as run, \
                mock.patch.object(app, 'control', side_effect=AssertionError('direct display call')):
            app.main()
        self.assertEqual(run.call_args_list, [
            mock.call('/usr/bin/systemctl', '--user', 'import-environment', 'DISPLAY', 'XAUTHORITY'),
            mock.call('/usr/bin/systemctl', '--user', 'daemon-reload'),
            mock.call('/usr/bin/systemctl', '--user', 'start', app.TIMER, app.SERVICE)])

    def test_stop_quiesces_timer_and_applier_before_starting_restore(self):
        calls = []

        def run(*args):
            calls.append(args)
            return 'DISPLAY=:91\nXAUTHORITY=/private/auth\n' if 'show-environment' in args else 'loaded\n'

        with mock.patch.object(app, 'run', side_effect=run), \
                mock.patch.object(app, 'control', side_effect=AssertionError('unexpected fallback')):
            app.stop()
        stop_timer = calls.index(('/usr/bin/systemctl', '--user', 'stop', app.TIMER))
        stop_service = calls.index(('/usr/bin/systemctl', '--user', 'stop', app.SERVICE))
        restore = calls.index(('/usr/bin/systemctl', '--user', 'start', app.RESTORE))
        self.assertLess(stop_timer, stop_service)
        self.assertLess(stop_service, restore)

    def test_stop_handles_missing_units_using_manager_x11_environment(self):
        calls = []
        restored = []

        def run(*args):
            calls.append(args)
            return 'DISPLAY=:91\nXAUTHORITY=/manager/auth\n' if 'show-environment' in args else 'not-found\n'

        def control(**kwargs):
            restored.append((kwargs, os.environ.get('DISPLAY'), os.environ.get('XAUTHORITY')))

        with mock.patch.dict(os.environ, {'DISPLAY': ':98', 'XAUTHORITY': '/caller/auth'}, clear=True), \
                mock.patch.object(app, 'run', side_effect=run), \
                mock.patch.object(app, 'control', side_effect=control):
            app.stop()
        self.assertFalse(any('stop' in args or 'start' in args for args in calls))
        self.assertEqual(restored, [({'restore': True}, ':91', '/manager/auth')])

    def test_stop_without_graphical_manager_does_not_open_a_display(self):
        for environment in ('', 'DISPLAY=remote:0\n', 'DISPLAY=invalid\n'):
            def run(*args):
                return environment if 'show-environment' in args else 'not-found\n'

            with self.subTest(environment=environment), \
                    mock.patch.object(app, 'run', side_effect=run), \
                    mock.patch.object(app, 'control', side_effect=AssertionError('opened display')):
                app.stop()

    def test_stop_failure_cannot_race_restore_against_running_applier(self):
        calls = []

        def run(*args):
            calls.append(args)
            if args[-2:] == ('stop', app.SERVICE):
                raise app.subprocess.CalledProcessError(1, args)
            return 'loaded\n'

        with mock.patch.object(app, 'run', side_effect=run), \
                mock.patch.object(app, 'control', side_effect=AssertionError('unsafe fallback')), \
                self.assertRaises(app.subprocess.CalledProcessError):
            app.stop()
        self.assertNotIn(('/usr/bin/systemctl', '--user', 'start', app.RESTORE), calls)


class MenuChecks(unittest.TestCase):
    @staticmethod
    def answer(text='', code=0):
        return app.subprocess.CompletedProcess([], code, stdout=text)

    def test_cancel_or_unknown_selection_never_persists_or_changes_display(self):
        replies = ([self.answer(code=1)], [self.answer('99')],
                   [self.answer('3'), self.answer(code=1)])
        for answers in replies:
            with self.subTest(answers=answers), \
                    mock.patch.object(app, 'settings', return_value=dict(app.DEFAULTS)), \
                    mock.patch.object(app.subprocess, 'run', side_effect=answers), \
                    mock.patch.object(app, 'save_settings') as save, \
                    mock.patch.object(app, 'control') as control:
                app.menu()
            save.assert_not_called()
            control.assert_not_called()

    def test_valid_hours_choose_auto_and_apply_once(self):
        with mock.patch.object(app, 'settings', return_value=dict(app.DEFAULTS, mode='day')), \
                mock.patch.object(app.subprocess, 'run', side_effect=[self.answer('3'), self.answer('22:30 07:15')]), \
                mock.patch.object(app, 'save_settings') as save, \
                mock.patch.object(app, 'control') as control:
            app.menu()
        save.assert_called_once_with({'mode': 'auto', 'start': '22:30', 'end': '07:15'})
        control.assert_called_once_with()

    def test_invalid_hours_are_refused_before_file_or_display_changes(self):
        for text in ('22:30', '99:00 08:00', '08:00 08:00'):
            with self.subTest(text=text), \
                    mock.patch.object(app, 'settings', return_value=dict(app.DEFAULTS)), \
                    mock.patch.object(app.subprocess, 'run', side_effect=[self.answer('3'), self.answer(text)]), \
                    mock.patch.object(app, 'write_owned', side_effect=AssertionError('wrote invalid settings')), \
                    mock.patch.object(app, 'control', side_effect=AssertionError('changed display')), \
                    self.assertRaises(ValueError):
                app.menu()

    def test_explicit_night_selection_applies_immediately(self):
        with mock.patch.object(app, 'settings', return_value=dict(app.DEFAULTS)), \
                mock.patch.object(app.subprocess, 'run', return_value=self.answer('2')), \
                mock.patch.object(app, 'save_settings') as save, \
                mock.patch.object(app, 'control') as control:
            app.menu()
        save.assert_called_once_with(dict(app.DEFAULTS, mode='night'))
        control.assert_called_once_with()


if __name__ == '__main__':
    unittest.main()
