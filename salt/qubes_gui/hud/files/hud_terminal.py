# Qubes HUD managed file. Owner: salt/qubes_gui/hud.
"""Shared read-only viewers for fixed stock programs using GTK3/VTE."""
import ctypes as C
import functools
import os
import signal
import time

P, I, U, S = C.c_void_p, C.c_int, C.c_uint, C.c_char_p
COMMANDS = {
    "top": ("/usr/bin/top", "--secure-mode"),
    "xentop": ("/usr/sbin/xentop", "--delay=2", "--full-name"),
    "cgtop": ("/usr/bin/systemd-cgtop", "--delay=2", "--depth=2"),
    "dom0": ("/usr/bin/setpriv", "--pdeathsig", "TERM", "/usr/sbin/rsyslogd",
             "-n", "-iNONE", "-f", "/usr/local/libexec/qubes-hud/hud-dom0-logs.conf"),
    "xen": ("/usr/bin/bash", "--noprofile", "--norc", "-p", "-o", "pipefail", "-c",
            "/usr/bin/setpriv --pdeathsig TERM /usr/bin/tail -c 65536 -F -- "
            "/var/log/xen/console/hypervisor.log 2>&1 | "
            "/usr/bin/setpriv --pdeathsig TERM /usr/bin/env LC_ALL=C /usr/bin/cat -vT"),
}


class RGBA(C.Structure):
    _fields_ = [(name, C.c_double) for name in ("red", "green", "blue", "alpha")]


class Error(C.Structure):
    _fields_ = [("domain", U), ("code", I), ("message", S)]


def _bind(library, name, result, *args):
    function = getattr(library, name)
    function.restype, function.argtypes = result, args
    return function


@functools.lru_cache(maxsize=1)
def _libraries():
    """Resolve ABIs without initializing GTK, opening a display or spawning."""
    vte = C.CDLL("libvte-2.91.so.0")
    gtk = C.CDLL("libgtk-3.so.0")
    pango = C.CDLL("libpango-1.0.so.0")
    glib = C.CDLL("libglib-2.0.so.0")
    gobject = C.CDLL("libgobject-2.0.so.0")
    _bind(vte, "vte_terminal_new", P)
    for name in ("input_enabled", "allow_hyperlink", "audible_bell",
                 "scroll_on_output", "scroll_on_keystroke", "enable_sixel"):
        _bind(vte, "vte_terminal_set_" + name, None, P, I)
    _bind(vte, "vte_terminal_set_scrollback_lines", None, P, C.c_int64)
    _bind(vte, "vte_terminal_set_font", None, P, P)
    _bind(vte, "vte_terminal_set_colors", None, P, P, P, P, C.c_size_t)
    _bind(vte, "vte_terminal_set_color_bold", None, P, P)
    _bind(vte, "vte_terminal_copy_clipboard_format", None, P, I)
    _bind(vte, "vte_terminal_feed", None, P, S, C.c_ssize_t)
    _bind(vte, "vte_terminal_spawn_sync", I, P, I, S, P, P, I, P, P,
          C.POINTER(I), P, C.POINTER(P))
    _bind(gtk, "gtk_drag_dest_unset", None, P)
    _bind(gtk, "gtk_viewport_new", P, P, P)
    _bind(gtk, "gtk_scrollable_get_vadjustment", P, P)
    _bind(gtk, "gtk_scrollbar_new", P, I, P)
    _bind(gtk, "gtk_scrolled_window_set_overlay_scrolling", None, P, I)
    _bind(gtk, "gtk_widget_set_size_request", None, P, I, I)
    _bind(gtk, "gtk_widget_set_can_focus", None, P, I)
    _bind(gtk, "gdk_event_get_keyval", I, P, C.POINTER(U))
    _bind(gtk, "gdk_event_get_state", I, P, C.POINTER(U))
    _bind(pango, "pango_font_description_from_string", P, S)
    _bind(pango, "pango_font_description_free", None, P)
    _bind(glib, "g_error_free", None, P)
    _bind(glib, "g_main_context_iteration", I, P, I)
    # Separate CDLL/function objects leave the shared GUI's callback ABI intact.
    _bind(gobject, "g_signal_connect_data", C.c_ulong, P, S, P, P, P, I)
    return vte, gtk, pango, glib, gobject


def check():
    """Validate installed libraries and fixed commands, without running them."""
    _libraries()
    programs = {command[0] for command in COMMANDS.values()} | {
        "/usr/sbin/rsyslogd", "/usr/bin/setpriv", "/usr/bin/tail",
        "/usr/bin/cat", "/usr/bin/env"}
    for program in programs:
        if not os.path.isfile(program) or not os.access(program, os.X_OK):
            raise RuntimeError("Missing stock terminal command: " + program)


def _cyan(scale=1.0):
    return RGBA(25 / 255 * scale, 211 / 255 * scale, scale, 1.0)


def build(app, body, view, callbacks):
    """Return (focus widget, tick interval, tick, cleanup) for the shared window."""
    command = COMMANDS.get(view)  # Fixed argv/paths, including Xen's stock pipeline.
    if command is None:
        raise ValueError('Unknown terminal view')
    check()
    vte, gtk, pango, glib, gobject = _libraries()
    terminal = vte.vte_terminal_new()
    logs = view in ('dom0', 'xen')
    scroll = app.gtk.gtk_scrolled_window_new(None, None)
    gtk.gtk_scrolled_window_set_overlay_scrolling(scroll, 0)
    # A large live monitor canvas is panned, not replayed from terminal history.
    app.gtk.gtk_scrolled_window_set_policy(scroll, 0, 2 if logs else 0)
    viewport = gtk.gtk_viewport_new(None, None)
    gtk.gtk_widget_set_size_request(terminal, 1280, -1 if logs else 960)
    app.gtk.gtk_container_add(viewport, terminal)
    app.gtk.gtk_container_add(scroll, viewport)
    if logs:
        row = app.pack(body, app.box(False), True)
        app.pack(row, scroll, True)
        # Keep the actual history slider visible at the right while panning.
        adjustment = gtk.gtk_scrollable_get_vadjustment(terminal)
        app.pack(row, gtk.gtk_scrollbar_new(1, adjustment))
    else:
        app.pack(body, scroll, True)
    vte.vte_terminal_set_input_enabled(terminal, 0)
    gtk.gtk_drag_dest_unset(terminal)
    gtk.gtk_widget_set_can_focus(terminal, 1)
    vte.vte_terminal_set_allow_hyperlink(terminal, 0)
    vte.vte_terminal_set_enable_sixel(terminal, 0)
    vte.vte_terminal_set_audible_bell(terminal, 0)
    vte.vte_terminal_set_scroll_on_output(terminal, 0)
    vte.vte_terminal_set_scroll_on_keystroke(terminal, 0)
    vte.vte_terminal_set_scrollback_lines(terminal, 600 if logs else 0)
    font = pango.pango_font_description_from_string(b"Noto Sans Mono 8")
    vte.vte_terminal_set_font(terminal, font)
    pango.pango_font_description_free(font)
    foreground, background = _cyan(), RGBA(0, 0, 0, 1)
    palette = (RGBA * 256)(background, *[
        _cyan(0.42 + 0.58 * ((index - 1) % 15) / 14) for index in range(1, 256)])
    vte.vte_terminal_set_colors(terminal, C.byref(foreground), C.byref(background),
                                palette, len(palette))
    vte.vte_terminal_set_color_bold(terminal, C.byref(foreground))
    state = {"pid": 0, "pidfd": None, "closed": False, "started": False}

    def attach(name, prototype, function):
        callback = prototype(function)
        callbacks.append(callback)
        gobject.g_signal_connect_data(terminal, name, C.cast(callback, P), None, None, 0)

    def key_press(_widget, event, _data):
        key, modifiers = U(), U()
        gtk.gdk_event_get_keyval(event, C.byref(key))
        gtk.gdk_event_get_state(event, C.byref(modifiers))
        copy = (key.value in (ord("c"), ord("C")) and modifiers.value & 13 == 5
                or key.value == 0xff63 and modifiers.value & 13 == 4)
        if copy:
            vte.vte_terminal_copy_clipboard_format(terminal, 1)  # VTE_FORMAT_TEXT.
            return 1
        return 0  # VTE's disabled input gates typing, paste and mouse reporting.

    def child_exited(_widget, status, _data):
        # Widget destruction can emit this before the process is reaped. Keep
        # its identity so cleanup still drives the native child watch to finish.
        if not state["closed"]:
            message = f"\r\n[Program stopped: status {status}. Close this window to finish.]\r\n"
            encoded = message.encode("ascii")
            vte.vte_terminal_feed(terminal, encoded, len(encoded))

    attach(b"key-press-event", C.CFUNCTYPE(I, P, P, P), key_press)

    attach(b"child-exited", C.CFUNCTYPE(None, P, I, P), child_exited)

    def tick(_data):
        if state["started"] or state["closed"]:
            return 1
        state["started"] = True
        argv = (S * (len(command) + 1))(*(item.encode() for item in command), None)
        runtime = os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid()))
        environment = [b"TERM=xterm-256color", b"COLORTERM=",
                       os.fsencode('HUD_LOG_STATE=' + runtime + '/qubes-hud-terminals/' + view)]
        envv = (S * (len(environment) + 1))(*environment, None)
        if view == 'xen':
            banner = b"Recent Xen hypervisor log; following new events\r\n"
            vte.vte_terminal_feed(terminal, banner, len(banner))
        pid, error = I(), P()
        # No Python post-fork callback. VTE creates the PTY and watches/reaps GPid.
        success = vte.vte_terminal_spawn_sync(terminal, 0, b"/", argv, envv,
                                              0, None, None, C.byref(pid), None,
                                              C.byref(error))
        if not success:
            detail = "could not start fixed command"
            if error:
                raw = C.cast(error, C.POINTER(Error)).contents.message or b""
                detail = "".join(c if c.isprintable() else " " for c in
                                 raw[:512].decode("utf-8", "replace"))[:300]
                glib.g_error_free(error)
            encoded = ("Program unavailable: " + detail + "\r\n").encode("utf-8")
            vte.vte_terminal_feed(terminal, encoded, len(encoded))
        else:
            state["pid"] = pid.value
            try:
                state["pidfd"] = os.pidfd_open(pid.value)
            except OSError:
                pass  # The child may already have exited; its VTE watch remains.
        return 1

    def cleanup():
        if state["closed"]:
            return
        state["closed"] = True
        pid, pidfd = state["pid"], state["pidfd"]
        try:
            for signum in (signal.SIGTERM, signal.SIGKILL):
                if not pid:
                    break
                try:
                    # WNOWAIT leaves reaping to VTE/GLib; never steal its child.
                    os.waitid(os.P_PID, pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
                    if pidfd is not None:
                        signal.pidfd_send_signal(pidfd, signum)
                    else:
                        os.kill(pid, signum)
                except (ChildProcessError, ProcessLookupError):
                    break
                # Rsyslog may need close to one second to save its file cursors.
                deadline = time.monotonic() + (2.0 if signum == signal.SIGTERM else 0.5)
                while time.monotonic() < deadline:
                    glib.g_main_context_iteration(None, 0)
                    try:
                        os.waitid(os.P_PID, pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
                    except ChildProcessError:
                        pid = 0
                        break
                    time.sleep(0.01)
            if pid:
                # GLib's native watch should have reaped even a destroyed widget.
                try:
                    os.waitid(os.P_PID, pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
                except ChildProcessError:
                    pid = 0
                if pid:
                    raise RuntimeError("Terminal child did not finish after termination")
        finally:
            if pidfd is not None:
                os.close(pidfd)
            state["pidfd"] = None

    return terminal, 1000, tick, cleanup
