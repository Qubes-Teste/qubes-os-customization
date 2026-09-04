{# Remove only files owned by the guest HUD formula. Never touches /home. #}
{% from 'qubes_gui/guest_hud/map.jinja' import guest_hud_platform with context %}
{% set owner_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/guest_hud.' %}
{% set shared_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' %}
{% set theme_root = '/usr/share/themes/Qubes-HUD' %}
{% set config_root = '/etc/qubes-hud' %}
{% set theme_owner = theme_root ~ '/.salt-owner' %}
{% set config_owner = config_root ~ '/.salt-owner' %}
{% set xfce_xsettings = config_root ~ '/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml' %}
{% set xfce_terminal = config_root ~ '/xdg/xfce4/terminal/terminalrc' %}
{% set dconf_defaults = '/etc/dconf/db/local.d/90-qubes-hud' %}
{% set dconf_locks = '/etc/dconf/db/local.d/locks/90-qubes-hud' %}
{% set dconf_database = '/etc/dconf/db/local' %}
{% set dconf_source_root = '/etc/dconf/db/local.d' %}
{% set dconf_locks_root = dconf_source_root ~ '/locks' %}
{% set qubesdb_read = '/usr/bin/qubesdb-read' %}
{% set vm_type = salt['cmd.run'](
    qubesdb_read ~ ' /qubes-vm-type', python_shell=false,
    ignore_retcode=true)|trim if salt['file.file_exists'](qubesdb_read) else '' %}
{% set platform_ok = grains.get('kernel') == 'Linux'
    and grains.get('virtual')|lower == 'xen'
    and vm_type == 'TemplateVM'
    and guest_hud_platform.get('supported', false) %}

{% set theme_owner_regular = salt['file.file_exists'](theme_owner)
    and not salt['file.is_link'](theme_owner) %}
{% set config_owner_regular = salt['file.file_exists'](config_owner)
    and not salt['file.is_link'](config_owner) %}
{% set theme_root_owned = theme_owner_regular
    and owner_marker in salt['file.read'](theme_owner) %}
{% set config_root_owned = config_owner_regular
    and owner_marker in salt['file.read'](config_owner) %}

{% set text_targets = [
    (theme_owner, [owner_marker]),
    (theme_root ~ '/index.theme', [owner_marker]),
    (theme_root ~ '/gtk-2.0/gtkrc', [owner_marker]),
    (theme_root ~ '/gtk-3.0/gtk.css', [owner_marker]),
    (theme_root ~ '/gtk-3.0/gtk-dark.css', [owner_marker]),
    (theme_root ~ '/gtk-3.0/qubes-hud.css', [shared_marker]),
    (theme_root ~ '/gtk-4.0/gtk.css', [owner_marker]),
    (theme_root ~ '/gtk-4.0/gtk-dark.css', [owner_marker]),
    (theme_root ~ '/gtk-4.0/qubes-hud.css', [shared_marker]),
    (config_owner, [owner_marker]),
    (config_root ~ '/VERSION', [owner_marker]),
    (xfce_xsettings, [owner_marker]),
    (xfce_terminal, [owner_marker]),
    (dconf_defaults, [owner_marker]),
    (dconf_locks, [owner_marker]),
    (guest_hud_platform.get('early_session', ''), [owner_marker]),
    (guest_hud_platform.get('late_session', ''), [owner_marker])
] %}
{% set collision = namespace(found=false) %}
{% for path, markers in text_targets if path %}
  {% set target_lstat = salt['file.lstat'](path) %}
  {% if target_lstat|length > 0 %}
    {% set target_regular = salt['file.file_exists'](path)
        and not salt['file.is_link'](path) %}
    {% set target_contents = salt['file.read'](path) if target_regular else '' %}
    {% set target_owned = namespace(found=false) %}
    {% for marker in markers %}
      {% if marker in target_contents %}
        {% set target_owned.found = true %}
      {% endif %}
    {% endfor %}
    {% if not target_regular or not target_owned.found %}
      {% set collision.found = true %}
    {% endif %}
  {% endif %}
{% endfor %}

{% set managed_directories = [
    '/usr',
    '/usr/share',
    '/usr/share/themes',
    theme_root,
    theme_root ~ '/gtk-2.0',
    theme_root ~ '/gtk-3.0',
    theme_root ~ '/gtk-4.0',
    '/etc',
    config_root,
    config_root ~ '/xdg',
    config_root ~ '/xdg/xfce4',
    config_root ~ '/xdg/xfce4/xfconf',
    config_root ~ '/xdg/xfce4/xfconf/xfce-perchannel-xml',
    config_root ~ '/xdg/xfce4/terminal',
    '/etc/dconf',
    '/etc/dconf/db',
    dconf_source_root,
    dconf_locks_root
] + guest_hud_platform.get('session_directories', []) %}
{% for directory in managed_directories %}
  {% set directory_lstat = salt['file.lstat'](directory) %}
  {% if directory_lstat|length > 0 and (
      not salt['file.directory_exists'](directory)
      or salt['file.is_link'](directory)) %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{% if not platform_ok %}
qubes_gui_guest_hud_rollback_unsupported_target:
  test.fail_without_changes:
    - name: >-
        qubes_gui.guest_hud.rollback supports only Qubes Linux TemplateVMs
        from the Debian OS family or Fedora.

{% elif collision.found %}
qubes_gui_guest_hud_rollback_unmanaged_target_refused:
  test.fail_without_changes:
    - name: >-
        Refusing rollback because a Qubes-HUD target is no longer an owned
        regular file or real directory. No files were changed.

{% else %}

{% for suffix, path in [
    ('early_session', guest_hud_platform['early_session']),
    ('late_session', guest_hud_platform['late_session']),
    ('dconf_defaults', dconf_defaults),
    ('dconf_locks', dconf_locks),
    ('xfce_xsettings', xfce_xsettings),
    ('xfce_terminal', xfce_terminal),
    ('version', config_root ~ '/VERSION'),
    ('config_owner', config_owner),
    ('gtk2', theme_root ~ '/gtk-2.0/gtkrc'),
    ('gtk3_wrapper', theme_root ~ '/gtk-3.0/gtk.css'),
    ('gtk3_dark_wrapper', theme_root ~ '/gtk-3.0/gtk-dark.css'),
    ('gtk3_overlay', theme_root ~ '/gtk-3.0/qubes-hud.css'),
    ('gtk4_wrapper', theme_root ~ '/gtk-4.0/gtk.css'),
    ('gtk4_dark_wrapper', theme_root ~ '/gtk-4.0/gtk-dark.css'),
    ('gtk4_overlay', theme_root ~ '/gtk-4.0/qubes-hud.css'),
    ('index', theme_root ~ '/index.theme'),
    ('theme_owner', theme_owner)
] %}
qubes_gui_guest_hud_rollback_remove_{{ suffix }}:
  file.absent:
    - name: {{ path }}
{% endfor %}

qubes_gui_guest_hud_rollback_dconf_database:
  cmd.run:
    - name: /usr/bin/dconf update
    - unless: >-
        /bin/sh -c 'database={{ dconf_database }};
        test -f "$database" &&
        test ! {{ dconf_source_root }} -nt "$database" &&
        test ! {{ dconf_locks_root }} -nt "$database" &&
        test -z "$(/usr/bin/find {{ dconf_source_root }} -type f
        -newer "$database" -print -quit)"'
    - require:
      - file: qubes_gui_guest_hud_rollback_remove_dconf_defaults
      - file: qubes_gui_guest_hud_rollback_remove_dconf_locks

qubes_gui_guest_hud_rollback_empty_theme_directories:
  cmd.run:
    - name: >-
        /bin/sh -c 'changed=no;
{% if theme_root_owned %}
        for directory in
        /usr/share/themes/Qubes-HUD/gtk-2.0
        /usr/share/themes/Qubes-HUD/gtk-3.0
        /usr/share/themes/Qubes-HUD/gtk-4.0
        /usr/share/themes/Qubes-HUD; do
        if test -d "$directory" &&
        /usr/bin/rmdir "$directory" 2>/dev/null; then changed=yes; fi; done;
{% endif %}
        /usr/bin/printf "changed=%s\n" "$changed"'
    - stateful: true
    - require:
      - file: qubes_gui_guest_hud_rollback_remove_gtk2
      - file: qubes_gui_guest_hud_rollback_remove_gtk3_wrapper
      - file: qubes_gui_guest_hud_rollback_remove_gtk3_dark_wrapper
      - file: qubes_gui_guest_hud_rollback_remove_gtk3_overlay
      - file: qubes_gui_guest_hud_rollback_remove_gtk4_wrapper
      - file: qubes_gui_guest_hud_rollback_remove_gtk4_dark_wrapper
      - file: qubes_gui_guest_hud_rollback_remove_gtk4_overlay
      - file: qubes_gui_guest_hud_rollback_remove_index
      - file: qubes_gui_guest_hud_rollback_remove_theme_owner

qubes_gui_guest_hud_rollback_empty_config_directories:
  cmd.run:
    - name: >-
        /bin/sh -c 'changed=no;
{% if config_root_owned %}
        for directory in
        /etc/qubes-hud/xdg/xfce4/xfconf/xfce-perchannel-xml
        /etc/qubes-hud/xdg/xfce4/xfconf
        /etc/qubes-hud/xdg/xfce4/terminal
        /etc/qubes-hud/xdg/xfce4
        /etc/qubes-hud/xdg
        /etc/qubes-hud; do
        if test -d "$directory" &&
        /usr/bin/rmdir "$directory" 2>/dev/null; then changed=yes; fi; done;
{% endif %}
        /usr/bin/printf "changed=%s\n" "$changed"'
    - stateful: true
    - require:
      - file: qubes_gui_guest_hud_rollback_remove_xfce_xsettings
      - file: qubes_gui_guest_hud_rollback_remove_xfce_terminal
      - file: qubes_gui_guest_hud_rollback_remove_version
      - file: qubes_gui_guest_hud_rollback_remove_config_owner

qubes_gui_guest_hud_rollback_complete:
  test.nop:
    - name: >-
        Qubes HUD guest selection and assets were removed. Existing user
        preferences and shared runtime packages were left untouched.
    - require:
      - file: qubes_gui_guest_hud_rollback_remove_early_session
      - file: qubes_gui_guest_hud_rollback_remove_late_session
      - file: qubes_gui_guest_hud_rollback_remove_theme_owner
      - cmd: qubes_gui_guest_hud_rollback_dconf_database
      - cmd: qubes_gui_guest_hud_rollback_empty_theme_directories
      - cmd: qubes_gui_guest_hud_rollback_empty_config_directories

{% endif %}
