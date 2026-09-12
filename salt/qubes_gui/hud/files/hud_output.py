# Qubes HUD managed file. Owner: salt/qubes_gui/hud.
"""Bounded RandR output CTM access through stock X11 libraries.

Use one instance at a time, on one thread: Xlib's error handler is process-wide.
Readback verifies the X property, not the monitor's physical color output.
"""
import ctypes as C
import hashlib
import os
import re

P, L, I, S = C.c_void_p, C.c_ulong, C.c_int, C.c_ushort


class Resources(C.Structure):
    _fields_ = [('timestamp', L), ('config_timestamp', L), ('ncrtc', I),
                ('crtcs', C.POINTER(L)), ('noutput', I), ('outputs', C.POINTER(L)),
                ('nmode', I), ('modes', P)]


class OutputInfo(C.Structure):
    _fields_ = [('timestamp', L), ('crtc', L), ('name', P), ('name_len', I),
                ('mm_width', L), ('mm_height', L), ('connection', S),
                ('subpixel_order', S), ('ncrtc', I), ('crtcs', C.POINTER(L)),
                ('nclone', I), ('clones', C.POINTER(L)), ('nmode', I),
                ('npreferred', I), ('modes', C.POINTER(L))]


class XError(C.Structure):
    _fields_ = [('type', I), ('display', P), ('resource', L), ('serial', L),
                ('code', C.c_ubyte), ('request', C.c_ubyte), ('minor', C.c_ubyte)]


class Outputs:
    def __init__(self, display=None, check_only=False):
        self.d, self.previous_handler, self.errors = None, None, []
        self.x, self.rr = C.CDLL('libX11.so.6'), C.CDLL('libXrandr.so.2')
        for library, name, result, args in (
            (self.x, 'XOpenDisplay', P, [C.c_char_p]),
            (self.x, 'XCloseDisplay', I, [P]),
            (self.x, 'XDefaultRootWindow', L, [P]),
            (self.x, 'XInternAtom', L, [P, C.c_char_p, I]),
            (self.x, 'XFree', I, [P]), (self.x, 'XSync', I, [P, I]),
            (self.x, 'XSetErrorHandler', P, [P]),
            (self.rr, 'XRRQueryVersion', I, [P, C.POINTER(I), C.POINTER(I)]),
            (self.rr, 'XRRGetScreenResourcesCurrent', C.POINTER(Resources), [P, L]),
            (self.rr, 'XRRFreeScreenResources', None, [C.POINTER(Resources)]),
            (self.rr, 'XRRGetOutputInfo', C.POINTER(OutputInfo), [P, C.POINTER(Resources), L]),
            (self.rr, 'XRRFreeOutputInfo', None, [C.POINTER(OutputInfo)]),
            (self.rr, 'XRRGetOutputProperty', I, [P, L, L, C.c_long, C.c_long, I, I, L,
                C.POINTER(L), C.POINTER(I), C.POINTER(L), C.POINTER(L), C.POINTER(P)]),
            (self.rr, 'XRRChangeOutputProperty', None, [P, L, L, L, I, I, P, I]),
        ):
            function = getattr(library, name)
            function.restype, function.argtypes = result, args
        if check_only:
            return
        display = display if display is not None else os.environ.get('DISPLAY', '')
        if not isinstance(display, str) or not re.fullmatch(r':[0-9]+(?:\.[0-9]+)?', display):
            raise ValueError('A local X11 display is required')
        self.d = self.x.XOpenDisplay(display.encode())
        if not self.d:
            raise RuntimeError('Cannot open local X11 display')
        callback = C.CFUNCTYPE(I, P, C.POINTER(XError))
        self.handler = callback(self._error)
        self.previous_handler = self.x.XSetErrorHandler(C.cast(self.handler, P))
        try:
            major, minor = I(), I()
            if not self.rr.XRRQueryVersion(self.d, C.byref(major), C.byref(minor)) or (major.value, minor.value) < (1, 3):
                raise RuntimeError('RandR 1.3 or newer is required')
            self.root = self.x.XDefaultRootWindow(self.d)
            self.ctm = self.x.XInternAtom(self.d, b'CTM', 1)
            self.edid = self.x.XInternAtom(self.d, b'EDID', 1)
            self._sync()
        except BaseException:
            self.close()
            raise

    def _error(self, display, event):
        if len(self.errors) < 8:
            self.errors.append((event.contents.code, event.contents.request, event.contents.minor))
        return 0

    def _sync(self):
        self.x.XSync(self.d, 0)
        if self.errors:
            errors, self.errors = self.errors, []
            raise RuntimeError('RandR X11 request failed: ' + repr(errors))

    def _property(self, output, atom, expected_format, limit):
        if not atom:
            return None
        kind, count, left, fmt, data = L(), L(), L(), I(), P()
        status = self.rr.XRRGetOutputProperty(self.d, output, atom, 0, limit, 0, 0, 0,
            C.byref(kind), C.byref(fmt), C.byref(count), C.byref(left), C.byref(data))
        try:
            self._sync()
            if status or left.value or kind.value != 19 or fmt.value != expected_format or not data:
                return None
            if count.value > limit * (4 if expected_format == 8 else 1):
                raise RuntimeError('Output property exceeds its read bound')
            if expected_format == 32:
                return [value & 0xffffffff for value in C.cast(data, C.POINTER(L))[:count.value]]
            return C.string_at(data, count.value)
        finally:
            if data:
                self.x.XFree(data)

    def snapshot(self):
        if not self.d:
            raise RuntimeError('No open X11 display')
        resources = self.rr.XRRGetScreenResourcesCurrent(self.d, self.root)
        if not resources:
            raise RuntimeError('Cannot query RandR outputs')
        try:
            self._sync()
            if not 0 <= resources.contents.noutput <= 64:
                raise RuntimeError('Unexpected RandR output count')
            result = []
            for output in resources.contents.outputs[:resources.contents.noutput]:
                info = self.rr.XRRGetOutputInfo(self.d, resources, output)
                if not info:
                    raise RuntimeError('RandR output disappeared during query')
                try:
                    value = info.contents
                    if value.connection != 0 or not value.crtc:
                        continue
                    if not value.name or not 1 <= value.name_len <= 256:
                        raise RuntimeError('Invalid output name')
                    name = C.string_at(value.name, value.name_len).decode('utf-8', 'replace')
                    ctm = self._property(output, self.ctm, 32, 18)
                    edid = self._property(output, self.edid, 8, 8192)
                    identity = name + ':' + (hashlib.sha256(edid).hexdigest() if edid else 'no-edid')
                    result.append(dict(id=output, name=name, ctm=ctm if ctm is not None and len(ctm) == 18 else None, identity=identity))
                finally:
                    self.rr.XRRFreeOutputInfo(info)
            self._sync()
            return result
        finally:
            self.rr.XRRFreeScreenResources(resources)

    def set(self, output_id, words):
        if type(output_id) is not int or not 0 < output_id <= 0xffffffff:
            raise ValueError('Invalid output ID')
        if not isinstance(words, (list, tuple)) or len(words) != 18 or any(type(v) is not int or not 0 <= v <= 0xffffffff for v in words):
            raise ValueError('CTM requires exactly 18 unsigned 32-bit words')
        if not any(row['id'] == output_id and row['ctm'] is not None for row in self.snapshot()):
            raise RuntimeError('Active output has no supported CTM property')
        data = (L * 18)(*words)  # Xlib represents each format-32 item as a native long.
        self.rr.XRRChangeOutputProperty(self.d, output_id, self.ctm, 19, 32, 0, data, 18)
        self._sync()
        if self._property(output_id, self.ctm, 32, 18) != list(words):
            raise RuntimeError('CTM property readback differs from requested matrix')

    def close(self):
        if self.d:
            self.x.XCloseDisplay(self.d)
            self.d = None
            self.x.XSetErrorHandler(self.previous_handler)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()
