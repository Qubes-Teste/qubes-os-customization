# Qubes HUD managed file. Owner: salt/qubes_gui/hud.
"""Read the active XKB layout and physical-key legends without observing input.

snapshot() fetches a fresh server map, so both group switches and later map or
variant replacements are visible. Call it from the GUI thread; no event hook,
keyboard grab, map change, subprocess, or keyboard-state mutation is used.
"""
import ctypes as C
import os


class _State(C.Structure):
    _fields_ = [
        ('group', C.c_ubyte), ('locked_group', C.c_ubyte),
        ('base_group', C.c_ushort), ('latched_group', C.c_ushort),
        ('mods', C.c_ubyte), ('base_mods', C.c_ubyte),
        ('latched_mods', C.c_ubyte), ('locked_mods', C.c_ubyte),
        ('compat_state', C.c_ubyte), ('grab_mods', C.c_ubyte),
        ('compat_grab_mods', C.c_ubyte), ('lookup_mods', C.c_ubyte),
        ('compat_lookup_mods', C.c_ubyte), ('ptr_buttons', C.c_ushort),
    ]


class KeyboardLayout:
    """A private, read-only connection to the current X11 keyboard map."""
    CORE_KEYBOARD = 0x100
    CLIENT_MAP = 0x07
    NAMES = {'us': 'English (US)', 'gb': 'English (UK)', 'de': 'German'}
    LABELS = {
        'Return': 'Enter', 'Escape': 'Escape', 'space': 'Space',
        'Left': '←', 'Down': '↓', 'Up': '↑', 'Right': '→',
        'BackSpace': 'Backspace', 'Prior': 'Page Up', 'Next': 'Page Down',
        'dead_acute': '´', 'dead_grave': '`', 'dead_circumflex': '^',
        'dead_diaeresis': '¨', 'dead_tilde': '~', 'ISO_Left_Tab': 'Tab',
    }

    def __init__(self, display=None, *, check_only=False):
        pointer, integer, ulong = C.c_void_p, C.c_int, C.c_ulong
        self.x = C.CDLL('libX11.so.6')
        def bind(name, result, *args):
            function = getattr(self.x, name)
            function.restype, function.argtypes = result, args
        bind('XOpenDisplay', pointer, C.c_char_p)
        bind('XCloseDisplay', integer, pointer)
        bind('XDefaultRootWindow', ulong, pointer)
        bind('XInternAtom', ulong, pointer, C.c_char_p, integer)
        bind('XGetWindowProperty', integer, pointer, ulong, ulong,
             C.c_long, C.c_long, integer, ulong, C.POINTER(ulong),
             C.POINTER(integer), C.POINTER(ulong), C.POINTER(ulong),
             C.POINTER(pointer))
        bind('XFree', integer, pointer)
        bind('XkbQueryExtension', integer, pointer, *([C.POINTER(integer)] * 5))
        bind('XkbGetState', integer, pointer, C.c_uint, C.POINTER(_State))
        bind('XkbGetMap', pointer, pointer, C.c_uint, C.c_uint)
        bind('XkbTranslateKeyCode', integer, pointer, C.c_ubyte, C.c_uint,
             C.POINTER(C.c_uint), C.POINTER(ulong))
        bind('XkbFreeKeyboard', None, pointer, C.c_uint, integer)
        bind('XKeysymToString', C.c_char_p, ulong)
        self.display = None
        if check_only:
            return
        display = display if display is not None else os.environ.get('DISPLAY')
        self.display = self.x.XOpenDisplay(display.encode() if display else None)
        if not self.display:
            raise RuntimeError('Cannot open X11 keyboard display')
        try:
            opcode, event, error, major, minor = [integer(v) for v in (0, 0, 0, 1, 0)]
            if not self.x.XkbQueryExtension(self.display, C.byref(opcode),
                    C.byref(event), C.byref(error), C.byref(major), C.byref(minor)):
                raise RuntimeError('XKB keyboard extension unavailable')
            self.root = self.x.XDefaultRootWindow(self.display)
            self.rules_atom = self.x.XInternAtom(self.display, b'_XKB_RULES_NAMES', 0)
        except Exception:
            self.close()
            raise

    def close(self):
        if self.display:
            self.x.XCloseDisplay(self.display)
            self.display = None

    def _group(self):
        state = _State()
        if self.x.XkbGetState(self.display, self.CORE_KEYBOARD, C.byref(state)):
            raise RuntimeError('Cannot read active XKB group')
        return int(state.group)

    def _rules(self):
        actual, count, remaining = C.c_ulong(), C.c_ulong(), C.c_ulong()
        fmt, data = C.c_int(), C.c_void_p()
        status = self.x.XGetWindowProperty(self.display, self.root,
            self.rules_atom, 0, 1024, 0, 31, C.byref(actual), C.byref(fmt),
            C.byref(count), C.byref(remaining), C.byref(data))
        try:
            if status or fmt.value != 8 or remaining.value or not data:
                return ()
            return tuple(C.string_at(data, count.value).decode('utf-8', 'replace').split('\0'))
        finally:
            if data:
                self.x.XFree(data)

    def _legend(self, keysym, keycode):
        if 0x21 <= keysym <= 0x7e or 0xa0 <= keysym <= 0xff:
            character = chr(keysym)
        elif 0x01000100 <= keysym <= 0x0110ffff:
            character = chr(keysym & 0xffffff)
        else:
            name = self.x.XKeysymToString(keysym)
            name = name.decode('ascii', 'replace') if name else ''
            return self.LABELS.get(name, name.replace('_', ' ') or f'Keycode {keycode}')
        upper = character.upper()
        return upper if len(upper) == 1 else character

    def snapshot(self, keycodes):
        if not self.display:
            raise RuntimeError('Keyboard connection is closed')
        codes = sorted(set(keycodes))
        if any(type(code) is not int or not 8 <= code <= 255 for code in codes):
            raise ValueError('X11 keycodes must be integers from 8 through 255')
        for attempt in range(3):
            rules, group = self._rules(), self._group()
            keyboard = self.x.XkbGetMap(self.display, self.CLIENT_MAP, self.CORE_KEYBOARD)
            if not keyboard:
                raise RuntimeError('Cannot read current XKB map')
            try:
                def translate(code, selected_group):
                    modifiers, symbol = C.c_uint(), C.c_ulong()
                    # XkbBuildCoreState(0, group): only the group, no Shift/Caps.
                    self.x.XkbTranslateKeyCode(keyboard, code, (selected_group & 3) << 13,
                                              C.byref(modifiers), C.byref(symbol))
                    return symbol.value
                keys = {code: self._legend(translate(code, group), code) for code in codes}
                # An unqualified i3 bindsym is resolved in Group1 (index 0),
                # then active in every group. Show the active-group legend of
                # that physical key, not the symbol's spelling in Group1.
                minus_code = next((code for code in range(8, 256)
                                   if translate(code, 0) == ord('-')), None)
                symbols = {'minus': self._legend(translate(minus_code, group), minus_code)
                           if minus_code is not None else None}
            finally:
                self.x.XkbFreeKeyboard(keyboard, 0, 1)
            if self._group() == group and self._rules() == rules:
                break
        else:
            raise RuntimeError('Keyboard layout changed during lookup; retry later')
        layouts = rules[2].split(',') if len(rules) > 2 else []
        variants = rules[3].split(',') if len(rules) > 3 else []
        layout = layouts[group] if group < len(layouts) else ''
        variant = variants[group] if group < len(variants) else ''
        name = self.NAMES.get(layout, layout or 'Unknown keyboard layout')
        if variant:
            name += ' · ' + variant
        return {'group': group, 'layout': layout, 'variant': variant,
                'name': name, 'supported': layout in self.NAMES, 'keys': keys,
                'symbols': symbols}
