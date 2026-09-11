# Qubes HUD managed file. Owner: salt/qubes_gui/hud.
"""Bounded, unprivileged followers for local dom0 and Xen logs only."""
import os
from pathlib import Path
import re
import stat
import subprocess
import time
import unicodedata


JOURNAL = '/usr/bin/journalctl'
JOURNAL_ARGS = (JOURNAL, '--boot', '--lines=80', '--follow', '--no-pager',
                '--output=short-iso', '--quiet')
QUBES_LOG_DIR = Path('/var/log/qubes')
DOM0_FILES = (Path('/var/log/xen/xen-hotplug.log'),
              Path('/var/log/xen/domain-builder-ng.log'))
XEN_FILE = Path('/var/log/xen/console/hypervisor.log')
LIBVIRT_DIR = Path('/var/log/libvirt/libxl')
DOM0_NAME = re.compile(r'(?:guid|qrexec|qubesdb)\.[A-Za-z0-9][A-Za-z0-9_.-]{0,63}\.log\Z')
MAX_FILES = 256
MAX_SCAN = 4096
INITIAL_BYTES = 8192
READ_BYTES = 32768
READ_CHUNK = 4096
MAX_LINE = 2048
MAX_OUTPUT = 65536
SCAN_INTERVAL = 2.0


def _plain(text):
    """Visibly escape controls, including terminal escapes and bidi markers."""
    result = []
    for char in text:
        if char == '\t':
            result.append('    ')
        elif unicodedata.category(char).startswith('C') or char in '\u2028\u2029':
            value = ord(char)
            result.append(f'\\x{value:02x}' if value < 256 else f'\\u{value:04x}')
        else:
            result.append(char)
    return ''.join(result)


class _Lines:
    def __init__(self, name):
        self.name = name
        self.pending = b''
        self.discard = False

    def feed(self, data):
        """A partial or indefinitely long line never grows without a bound."""
        self.pending += data
        while self.pending:
            end = self.pending.find(b'\n')
            if self.discard:
                self.pending = b'' if end < 0 else self.pending[end + 1:]
                self.discard = end < 0
                continue
            if end < 0 and len(self.pending) <= MAX_LINE:
                break
            truncated = end > MAX_LINE or (end < 0 and len(self.pending) > MAX_LINE)
            size = MAX_LINE if truncated else end
            text = _plain(self.pending[:size].decode('utf-8', 'replace'))
            yield f'[{self.name}] {text}' + (' … [line truncated]' if truncated else '') + '\n'
            self.pending = b'' if end < 0 else self.pending[end + 1:]
            self.discard = truncated and end < 0


class _File(_Lines):
    def __init__(self, path, initial=True):
        super().__init__(path.name)
        self.path = path
        parent = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
        try:
            self.fd = os.open(path.name, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
                              dir_fd=parent)
        finally:
            os.close(parent)
        try:
            info = os.fstat(self.fd)
            if not stat.S_ISREG(info.st_mode):
                raise OSError('Source is not a regular file')
            self.identity = (info.st_dev, info.st_ino)
            self.offset = max(0, info.st_size - INITIAL_BYTES) if initial else 0
            os.lseek(self.fd, self.offset, os.SEEK_SET)
            self.discard = self.offset > 0  # Do not show a partial initial line.
        except Exception:
            os.close(self.fd)
            raise

    def read(self, limit):
        notices = []
        if os.fstat(self.fd).st_size < self.offset:
            os.lseek(self.fd, 0, os.SEEK_SET)
            self.offset = 0
            self.pending = b''
            self.discard = False
            notices.append(f'[{self.name}] [log truncated; following from start]\n')
        data = os.read(self.fd, limit)
        self.offset += len(data)
        return data, notices

    def close(self):
        os.close(self.fd)


class LogFeed:
    """No paths, commands, elevated privileges, or guest sources are accepted."""
    @staticmethod
    def check():
        if not Path(JOURNAL).is_file() or not os.access(JOURNAL, os.X_OK):
            raise RuntimeError('The stock journalctl executable is unavailable')

    def __init__(self, view='dom0'):
        if view not in ('dom0', 'xen'):
            raise ValueError('Log view must be dom0 or xen')
        self.view = view
        self.files = {}
        self.errors = {}
        self.omitted = 0
        self.scan_limited = False
        self.libvirt_unavailable = False
        self.closed = False
        self.next_scan = 0
        self.turn = 0
        self.process = None
        self.journal_lines = _Lines('journal')
        self.journal_ended = False
        if view == 'dom0':
            try:
                self.process = subprocess.Popen(JOURNAL_ARGS, stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0,
                    start_new_session=True, env=dict(os.environ, SYSTEMD_COLORS='0'))
                os.set_blocking(self.process.stdout.fileno(), False)
            except OSError as error:
                self.errors['journal'] = str(error)

    @property
    def status(self):
        if self.closed:
            return 'Stopped'
        parts = [f'{len(self.files)} file source(s)']
        if self.view == 'dom0':
            if self.process is not None:
                code = self.process.poll()
                parts.append('journal live' if code is None else f'journal exited ({code})')
            if self.libvirt_unavailable:
                parts.append('libvirt files unavailable')
        if self.omitted:
            parts.append(f'{self.omitted} files omitted (source limit)')
        if self.scan_limited:
            parts.append('directory scan limited')
        if self.errors:
            names = sorted(self.errors)
            parts.append('unavailable: ' + ', '.join(name[:40] for name in names[:3])
                         + (f' (+{len(names) - 3})' if len(names) > 3 else ''))
        text = ' · '.join(parts)
        return text if len(text) <= 256 else text[:255] + '…'

    def _scan(self):
        candidates = {}
        self.errors = {key: value for key, value in self.errors.items() if key == 'journal'}
        self.scan_limited = False
        paths = [XEN_FILE] if self.view == 'xen' else list(DOM0_FILES)
        if self.view == 'dom0':
            self.libvirt_unavailable = not os.access(LIBVIRT_DIR, os.R_OK | os.X_OK)
            try:
                parent = os.open(QUBES_LOG_DIR, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
                try:
                    with os.scandir(parent) as entries:
                        for number, entry in enumerate(entries):
                            if number >= MAX_SCAN:
                                self.scan_limited = True
                                break
                            if DOM0_NAME.fullmatch(entry.name):
                                paths.append(QUBES_LOG_DIR / entry.name)
                finally:
                    os.close(parent)
            except OSError as error:
                self.errors['Qubes daemon logs'] = str(error)
        for path in paths:
            try:
                info = path.stat(follow_symlinks=False)
                if not stat.S_ISREG(info.st_mode):
                    raise OSError('Source is not a regular file')
                candidates[path] = info
            except FileNotFoundError:
                if self.view == 'xen':
                    self.errors['hypervisor.log'] = 'Log is not present'
            except OSError as error:
                self.errors[path.name] = str(error)
        for path in list(self.files):
            source = self.files[path]
            info = candidates.get(path)
            if info is None or source.identity != (info.st_dev, info.st_ino):
                source.close()
                del self.files[path]
                if info is not None:
                    self._add(path, initial=False)
        # Existing tails keep their positions. New sources fill free slots;
        # historical files cannot repeatedly evict/reset an active follower.
        for path in sorted(candidates, key=lambda p: candidates[p].st_mtime_ns, reverse=True):
            if path not in self.files and len(self.files) < MAX_FILES:
                self._add(path)
        self.omitted = sum(path not in self.files and path.name not in self.errors for path in candidates)

    def _add(self, path, initial=True):
        try:
            self.files[path] = _File(path, initial)
        except OSError as error:
            self.errors[path.name] = str(error)

    def poll(self):
        if self.closed:
            return ''
        now = time.monotonic()
        if now >= self.next_scan:
            self._scan()
            self.next_scan = now + SCAN_INTERVAL
        output = []
        used = 0
        limited = False
        def emit(lines):
            nonlocal used, limited
            for line in lines:
                if used + len(line) <= MAX_OUTPUT - 80:
                    output.append(line)
                    used += len(line)
                else:
                    limited = True
        sources = list(self.files.values())
        if self.process is not None and not self.journal_ended:
            sources.append(self.journal_lines)
        if sources:
            start = self.turn % len(sources)
            sources = sources[start:] + sources[:start]
        visited = 0
        remaining = READ_BYTES
        for source in sources:
            if remaining <= 0:
                break
            visited += 1
            try:
                if source is self.journal_lines:
                    data = os.read(self.process.stdout.fileno(), min(READ_CHUNK, remaining))
                    if not data and self.process.poll() is not None:
                        self.journal_ended = True
                        if source.pending:
                            emit(source.feed(b'\n'))
                        emit([f'[journal] [stream exited ({self.process.returncode})]\n'])
                else:
                    data, notices = source.read(min(READ_CHUNK, remaining))
                    emit(notices)
                remaining -= len(data)
                emit(source.feed(data))
            except BlockingIOError:
                continue
            except OSError as error:
                self.errors[source.name] = str(error)
        self.turn += visited
        text = ''.join(output)
        if limited:
            text += '[viewer] [output limited; some lines omitted]\n'
        return text

    def close(self):
        if self.closed:
            return
        self.closed = True
        for source in self.files.values():
            source.close()
        self.files.clear()
        if self.process is not None:
            if self.process.poll() is None:
                self.process.terminate()
                try:
                    self.process.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait(timeout=1)
            self.process.stdout.close()
