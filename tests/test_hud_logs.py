"""Log-source boundaries, bounded following, and child cleanup without live logs."""
import contextlib
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock


SOURCE = Path(__file__).resolve().parents[1] / 'salt/qubes_gui/hud/files/hud_logs.py'
SPEC = importlib.util.spec_from_file_location('hud_logs', SOURCE)
logs = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(logs)


class LogFeedTests(unittest.TestCase):
    def setUp(self):
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.base = Path(self.stack.enter_context(tempfile.TemporaryDirectory()))
        self.qubes = self.base / 'qubes'
        self.qubes.mkdir()
        self.console = self.base / 'console'
        self.console.mkdir()
        self.xen = self.console / 'hypervisor.log'
        self.hotplug = self.base / 'xen-hotplug.log'
        self.builder = self.base / 'domain-builder-ng.log'
        for name, value in {'QUBES_LOG_DIR': self.qubes, 'XEN_FILE': self.xen,
                'DOM0_FILES': (self.hotplug, self.builder), 'LIBVIRT_DIR': self.base / 'unavailable',
                'SCAN_INTERVAL': 0,
                'JOURNAL_ARGS': (sys.executable, '-c', 'import time; time.sleep(60)')}.items():
            self.stack.enter_context(mock.patch.object(logs, name, value))

    def feed(self, view='xen'):
        feed = logs.LogFeed(view)
        self.addCleanup(feed.close)
        return feed

    def collect(self, feed, wanted):
        output = ''
        deadline = time.monotonic() + 2
        while wanted not in output and time.monotonic() < deadline:
            output += feed.poll()
            time.sleep(.01)
        self.assertIn(wanted, output)
        return output

    def test_dom0_allowlist_excludes_guest_update_and_archived_sources(self):
        for name in ('guid.work.log', 'qrexec.work.log', 'qubesdb.work.log'):
            (self.qubes / name).write_text('daemon-' + name + '\n')
        for name in ('guest-work.log', 'mgmt-work.log', 'update-work.log',
                     'guid.work.log.old', 'qubes-vm-update.log'):
            (self.qubes / name).write_text('EXCLUDED CONTENT\n')
        (self.console / 'guest-work.log').write_text('EXCLUDED CONTENT\n')
        self.hotplug.write_text('hotplug-event\n')
        self.builder.write_text('builder-event\n')
        feed = self.feed('dom0')
        output = feed.poll()
        self.assertEqual(len(feed.files), 5)
        self.assertNotIn('EXCLUDED', output)
        self.assertIn('[guid.work.log] daemon-', output)
        self.assertIn('hotplug-event', output)
        self.assertIn('builder-event', output)
        self.assertIn('libvirt files unavailable', feed.status)

    def test_xen_only_and_append_truncate_replace(self):
        self.xen.write_text('old-line-that-is-longer\n')
        (self.console / 'guest-work.log').write_text('EXCLUDED CONTENT\n')
        feed = self.feed()
        self.assertIn('old-line', feed.poll())
        with self.xen.open('a') as stream:
            stream.write('appended\n')
        self.assertIn('appended', feed.poll())
        self.xen.write_text('new\n')
        output = feed.poll()
        self.assertIn('log truncated', output)
        self.assertIn('[hypervisor.log] new', output)
        self.xen.rename(self.console / 'hypervisor.log.old')
        self.xen.write_text('replacement\n')
        self.assertIn('replacement', feed.poll())
        self.assertEqual(set(feed.files), {self.xen})
        self.assertIsNone(feed.process)

    def test_new_sources_and_stable_explicit_cap(self):
        self.stack.enter_context(mock.patch.object(logs, 'MAX_FILES', 2))
        first = self.qubes / 'guid.one.log'
        first.write_text('first\n')
        feed = self.feed('dom0')
        self.assertIn('first', feed.poll())
        second = self.qubes / 'guid.two.log'
        second.write_text('second\n')
        self.assertIn('second', feed.poll())
        (self.qubes / 'guid.three.log').write_text('third\n')
        self.assertNotIn('third', feed.poll())
        self.assertIn('1 files omitted', feed.status)
        with first.open('a') as stream:
            stream.write('still-following\n')
        output = feed.poll()
        self.assertIn('still-following', output)
        self.assertNotIn('[guid.one.log] first', output)

    def test_symlinks_fifo_and_parent_symlink_are_not_read(self):
        secret = self.base / 'other.log'
        secret.write_text('EXCLUDED CONTENT\n')
        self.xen.symlink_to(secret)
        feed = self.feed()
        self.assertEqual(feed.poll(), '')
        self.assertIn('unavailable', feed.status)
        self.xen.unlink()
        os.mkfifo(self.xen)
        self.assertEqual(feed.poll(), '')
        self.xen.unlink()
        self.console.rmdir()
        other = self.base / 'other'
        other.mkdir()
        (other / 'hypervisor.log').write_text('EXCLUDED CONTENT\n')
        self.console.symlink_to(other, target_is_directory=True)
        self.assertEqual(feed.poll(), '')
        self.assertIn('unavailable', feed.status)

    def test_long_unterminated_lines_controls_and_output_overflow(self):
        self.xen.touch()
        feed = self.feed()
        feed.poll()
        self.xen.write_bytes(b'x' * 20000 + b'\nnext \x1b[31m\x00\r ' + '\u202e\t'.encode() + b'\n')
        output = self.collect(feed, 'next')
        self.assertEqual(output.count('[line truncated]'), 1)
        self.assertIn('\\x1b', output)
        self.assertIn('\\x00', output)
        self.assertIn('\\u202e', output)
        self.assertNotIn('\x1b', output)
        self.assertNotIn('\u202e', output)
        self.assertLessEqual(len(feed.files[self.xen].pending), logs.MAX_LINE)
        self.stack.enter_context(mock.patch.object(logs, 'MAX_OUTPUT', 512))
        with self.xen.open('a') as stream:
            stream.write('many\n' * 500)
        output = feed.poll()
        self.assertLessEqual(len(output), 512)
        self.assertIn('[output limited;', output)

    def test_journal_exit_and_close_reap_owned_child(self):
        self.stack.enter_context(mock.patch.object(logs, 'JOURNAL_ARGS',
            (sys.executable, '-c', 'import sys; print("fixture journal"); sys.exit(7)')))
        feed = self.feed('dom0')
        output = self.collect(feed, 'stream exited (7)')
        self.assertIn('[journal] fixture journal', output)
        self.assertIn('journal exited (7)', feed.status)
        feed.close()
        self.assertTrue(feed.process.stdout.closed)
        self.assertEqual(feed.poll(), '')
        with mock.patch.object(logs, 'JOURNAL_ARGS',
                (sys.executable, '-c', 'import time; time.sleep(60)')):
            live = self.feed('dom0')
        live.close()
        self.assertIsNotNone(live.process.returncode)
        self.assertTrue(live.process.stdout.closed)
        self.assertEqual(live.status, 'Stopped')
        live.close()

    def test_journal_start_error_leaves_readable_file_sources(self):
        self.hotplug.write_text('still-readable\n')
        with mock.patch.object(logs.subprocess, 'Popen', side_effect=OSError('fixture failure')):
            feed = self.feed('dom0')
        self.assertIn('still-readable', feed.poll())
        self.assertIn('unavailable: journal', feed.status)

    def test_check_never_opens_logs_or_starts_a_process(self):
        with (mock.patch.object(logs.os, 'open', side_effect=AssertionError('opened log')),
                mock.patch.object(logs.subprocess, 'Popen', side_effect=AssertionError('started process'))):
            logs.LogFeed.check()
        with mock.patch.object(logs, 'JOURNAL', str(self.base / 'missing')):
            with self.assertRaises(RuntimeError):
                logs.LogFeed.check()

    def test_status_remains_bounded_with_thousands_of_source_errors(self):
        feed = self.feed()
        feed.errors = {f'guid.{number:04d}-' + 'long-name' * 7 + '.log': 'fixture error'
                       for number in range(logs.MAX_SCAN)}
        self.assertLessEqual(len(feed.status), 256)
        self.assertIn('(+4093)', feed.status)
        self.assertNotIn('guid.0003', feed.status)

    def test_busy_sources_share_the_read_budget(self):
        self.stack.enter_context(mock.patch.object(logs, 'READ_BYTES', 4096))
        for name, letter in (('guid.one.log', 'A'), ('guid.two.log', 'B')):
            (self.qubes / name).write_text((letter + '\n') * 8000)
        feed = self.feed('dom0')
        combined = feed.poll() + feed.poll()
        self.assertIn('[guid.one.log]', combined)
        self.assertIn('[guid.two.log]', combined)


if __name__ == '__main__':
    unittest.main()
