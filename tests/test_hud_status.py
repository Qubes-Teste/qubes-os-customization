"""Protocol preservation and bounded Xen sampling for the HUD status filter."""
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import signal
import subprocess
import unittest
from unittest import mock


SOURCE = Path(__file__).resolve().parents[1] / 'salt/qubes_gui/hud/files/hud-status'
loader = importlib.machinery.SourceFileLoader('test_hud_status_module', str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
app = importlib.util.module_from_spec(spec)
loader.exec_module(app)


class MemoryChecks(unittest.TestCase):
    def test_absolute_native_command_and_mib_to_gib(self):
        for value, expected in [('0\n', 'RAM free:    0.0 GiB'),
                                (' 1536\n', 'RAM free:    1.5 GiB'),
                                ('65536\n', 'RAM free:   64.0 GiB')]:
            with self.subTest(value=value), \
                    mock.patch.object(app.subprocess, 'check_output', return_value=value) as probe:
                self.assertEqual(app.ram_text(), expected)
                probe.assert_called_once_with(
                    ['/usr/bin/xl', 'info', 'free_memory'], text=True,
                    stderr=subprocess.DEVNULL, timeout=1)

    def test_negative_or_malformed_memory_is_unavailable(self):
        for value in ('-1\n', '', 'garbage', 'free_memory: 1024', 'NaN', '1024.5'):
            with self.subTest(value=value), \
                    mock.patch.object(app.subprocess, 'check_output', return_value=value):
                self.assertEqual(app.ram_text(), 'RAM free: unavailable')

    def test_missing_permission_failed_command_and_timeout_are_unavailable(self):
        errors = [FileNotFoundError(), PermissionError(),
                  subprocess.CalledProcessError(1, ['/usr/bin/xl']),
                  subprocess.TimeoutExpired(['/usr/bin/xl'], 1)]
        for error in errors:
            with self.subTest(error=type(error).__name__), \
                    mock.patch.object(app.subprocess, 'check_output', side_effect=error):
                self.assertEqual(app.ram_text(), 'RAM free: unavailable')


class ProtocolChecks(unittest.TestCase):
    def test_header_brackets_empty_arrays_errors_and_non_json_pass_through(self):
        lines = ['{"version":1,"click_events":true}\n', '[\n', ']\n', ',\n',
                 '[]\n', ',[]\n', '  [ ]  \n', 'stock program failed\n',
                 '{"error":"stock error"}\n', 'null\n', ',"scalar"\n']
        for line in lines:
            with self.subTest(line=line):
                self.assertEqual(app.add_ram(line, 'unused'), line)

    def test_no_disk_line_is_preserved_byte_for_byte(self):
        line = ',[null,7,{}, {"name":"clock","full_text":"12:34","color":"#abc"}]\n'
        self.assertEqual(app.add_ram(line, 'unused'), line)

    def test_ram_follows_disk_without_changing_other_blocks_or_colors(self):
        original = [
            {'name': 'load', 'full_text': '0.20', 'color': '#19d3ff'},
            {'name': 'disk', 'full_text': '50 GiB', 'instance': '/', 'urgent': True},
            {'name': 'time', 'full_text': '12:34', 'separator_block_width': 9},
        ]
        for prefix in ('', ','):
            with self.subTest(prefix=prefix):
                output = app.add_ram(prefix + json.dumps(original) + '\n', 'RAM sample')
                self.assertEqual(output.startswith(','), bool(prefix))
                blocks = json.loads(output[len(prefix):])
                self.assertEqual(blocks[:2] + blocks[3:], original)
                self.assertEqual(blocks[2], {'name': 'ram', 'full_text': 'RAM sample',
                                             'min_width': 'RAM free: unavailable'})
                self.assertTrue(output.endswith('\n'))

    def test_only_one_block_is_added_at_the_first_disk(self):
        blocks = [{'name': 'disk', 'instance': '/'}, {'name': 'disk', 'instance': '/home'}]
        output = json.loads(app.add_ram(json.dumps(blocks), 'RAM sample'))
        self.assertEqual([b['name'] for b in output], ['disk', 'ram', 'disk'])


class StreamChecks(unittest.TestCase):
    def test_two_second_cache_and_immediate_line_flush(self):
        class Output(io.StringIO):
            def __init__(self):
                super().__init__()
                self.flushes = 0

            def flush(self):
                self.flushes += 1

        output = Output()
        clock = [0]
        block = '[{"name":"disk","full_text":"disk"}]\n'
        times = [10, 10.5, 11.999, 12, 13, 14]

        def input_lines():
            for index, now in enumerate(times):
                self.assertEqual(output.flushes, index, 'Previous line was not flushed')
                clock[0] = now
                yield '{"version":1}\n' if index == 0 else ',' + block

        with mock.patch.object(app.sys, 'stdin', input_lines()), \
                mock.patch.object(app.sys, 'stdout', output), \
                mock.patch.object(app.time, 'monotonic', side_effect=lambda: clock[0]), \
                mock.patch.object(app, 'ram_text', side_effect=['first', 'second', 'third']) as ram, \
                mock.patch.object(app.signal, 'signal') as signals:
            app.main()
        self.assertEqual(ram.call_count, 3)
        self.assertEqual(output.flushes, len(times))
        lines = output.getvalue().splitlines()
        self.assertEqual(lines[0], '{"version":1}')
        self.assertEqual([json.loads(line[1:])[1]['full_text'] for line in lines[1:]],
                         ['first', 'first', 'second', 'second', 'third'])
        signals.assert_called_once_with(signal.SIGPIPE, signal.SIG_DFL)

    def test_empty_eof_does_not_query_xen_or_the_clock(self):
        with mock.patch.object(app.sys, 'stdin', io.StringIO()), \
                mock.patch.object(app.sys, 'stdout', io.StringIO()) as output, \
                mock.patch.object(app, 'ram_text') as ram, \
                mock.patch.object(app.time, 'monotonic') as clock, \
                mock.patch.object(app.signal, 'signal'):
            app.main()
        ram.assert_not_called()
        clock.assert_not_called()
        self.assertEqual(output.getvalue(), '')


if __name__ == '__main__':
    unittest.main()
