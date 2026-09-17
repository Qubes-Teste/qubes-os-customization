{# Remove only files owned by the guest HUD formula. Never touches /home. #}
{% from 'qubes_gui/guest_hud/map.jinja' import guest_hud_platform with context %}
{% set owner_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/guest_hud.' %}
{% set shared_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' %}
{% set theme_root = '/usr/share/themes/Qubes-HUD' %}
{% set config_root = '/etc/qubes-hud' %}
{% set theme_owner = theme_root ~ '/.salt-owner' %}
{% set config_owner = config_root ~ '/.salt-owner' %}
{% set cyan_icon_manager = config_root ~ '/manage-cyan-icon-theme' %}
{% set cyan_icon_record = config_root ~ '/cyan-icon-theme.owner' %}
{% set sdwdate_icon_manager = config_root ~ '/manage-sdwdate-tray-icons' %}
{% set sdwdate_icon_record = config_root ~ '/sdwdate-tray-icons.owner' %}
{% set tor_launcher_manager = config_root ~ '/manage-tor-control-panel-launcher' %}
{% set tor_launcher_record = config_root ~ '/tor-control-panel-launcher.owner' %}
{% set cyan_icon_root = '/usr/share/icons/Qubes-HUD-Cyan' %}
{% set cyan_icon_owner = cyan_icon_root ~ '/.qubes-hud-owner' %}
{% set cyan_icon_backup = '/usr/share/icons/.Qubes-HUD-Cyan.previous' %}
{% set cyan_icon_backup_owner = cyan_icon_backup ~ '/.qubes-hud-owner' %}
{% set cyan_icon_removal_tombstone = '/usr/share/icons/.Qubes-HUD-Cyan.removing' %}
{% set cyan_icon_removal_record = '/usr/share/icons/.Qubes-HUD-Cyan.removing.json' %}
{% set cyan_icon_removal_external_temp = '/usr/share/icons/.Qubes-HUD-Cyan.removing.json.tmp' %}
{% set cyan_icon_active_removal_temp = cyan_icon_root ~ '/.Qubes-HUD-Cyan.removing.json.tmp' %}
{% set cyan_icon_backup_removal_temp = cyan_icon_backup ~ '/.Qubes-HUD-Cyan.removing.json.tmp' %}
{% set xfce_xsettings = config_root ~ '/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml' %}
{% set xfce_terminal = config_root ~ '/xdg/xfce4/terminal/terminalrc' %}
{% set qt5ct_root = config_root ~ '/xdg/qt5ct' %}
{% set qt5ct_colors_root = qt5ct_root ~ '/colors' %}
{% set qt5ct_config = qt5ct_root ~ '/qt5ct.conf' %}
{% set qt5ct_palette = qt5ct_colors_root ~ '/qubes-hud.conf' %}
{% set sdwdate_dropin_root = '/etc/systemd/user/sdwdate-gui.service.d' %}
{% set sdwdate_dropin_owner = sdwdate_dropin_root ~ '/.qubes-hud-owner' %}
{% set sdwdate_dropin = sdwdate_dropin_root ~ '/90-qubes-hud.conf' %}
{% set dconf_defaults = '/etc/dconf/db/local.d/90-qubes-hud' %}
{% set dconf_locks = '/etc/dconf/db/local.d/locks/90-qubes-hud' %}
{% set dconf_database = '/etc/dconf/db/local' %}
{% set dconf_source_root = '/etc/dconf/db/local.d' %}
{% set dconf_locks_root = dconf_source_root ~ '/locks' %}
{% set gtksource_versions = ['3.0', '4'] %}
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
{% set config_root_lstat = salt['file.lstat'](config_root) %}
{% set config_root_real = config_root_lstat|length > 0
    and salt['file.directory_exists'](config_root)
    and not salt['file.is_link'](config_root) %}
{% set config_owner_regular = config_root_real
    and salt['file.file_exists'](config_owner)
    and not salt['file.is_link'](config_owner) %}
{% set theme_root_owned = theme_owner_regular
    and owner_marker in salt['file.read'](theme_owner) %}
{% set config_root_owned = config_owner_regular
    and owner_marker in salt['file.read'](config_owner) %}

{#
  The generated-icon record is a strict commit point for version 6 and later.
  Every remaining generated-theme component or resumable removal state must
  prove ownership before rollback emits a mutating state. Without a record,
  this may be an older install or an interrupted upgrade, so unfamiliar new
  paths are preserved and only independently verifiable components are removed.
#}
{% set cyan_icon_record_lstat = salt['file.lstat'](cyan_icon_record) %}
{% set cyan_icon_record_exists = cyan_icon_record_lstat|length > 0 %}
{% set cyan_icon_record_regular = salt['file.file_exists'](cyan_icon_record)
    and not salt['file.is_link'](cyan_icon_record) %}
{% set cyan_icon_record_owned = cyan_icon_record_regular
    and owner_marker in salt['file.read'](cyan_icon_record) %}
{% set cyan_icon_manager_lstat = salt['file.lstat'](cyan_icon_manager) %}
{% set cyan_icon_manager_exists = cyan_icon_manager_lstat|length > 0 %}
{% set cyan_icon_manager_regular = config_root_real
    and salt['file.file_exists'](cyan_icon_manager)
    and not salt['file.is_link'](cyan_icon_manager) %}
{% set cyan_icon_manager_owned = cyan_icon_manager_regular
    and salt['file.get_mode'](cyan_icon_manager) == '0755'
    and salt['file.lstat'](cyan_icon_manager).get('st_uid') == 0
    and salt['file.lstat'](cyan_icon_manager).get('st_gid') == 0
    and shared_marker in salt['file.read'](cyan_icon_manager) %}
{% set sdwdate_icon_manager_lstat = salt['file.lstat'](sdwdate_icon_manager) %}
{% set sdwdate_icon_manager_exists = sdwdate_icon_manager_lstat|length > 0 %}
{% set sdwdate_icon_manager_regular = config_root_real
    and salt['file.file_exists'](sdwdate_icon_manager)
    and not salt['file.is_link'](sdwdate_icon_manager) %}
{% set sdwdate_icon_manager_owned = sdwdate_icon_manager_regular
    and salt['file.get_mode'](sdwdate_icon_manager) == '0755'
    and sdwdate_icon_manager_lstat.get('st_uid') == 0
    and sdwdate_icon_manager_lstat.get('st_gid') == 0
    and owner_marker in salt['file.read'](sdwdate_icon_manager) %}
{% set sdwdate_icon_record_lstat = salt['file.lstat'](sdwdate_icon_record) %}
{% set sdwdate_icon_record_exists = sdwdate_icon_record_lstat|length > 0 %}
{% set sdwdate_icon_record_regular = config_root_real
    and salt['file.file_exists'](sdwdate_icon_record)
    and not salt['file.is_link'](sdwdate_icon_record) %}
{% set sdwdate_icon_record_owned = sdwdate_icon_record_regular
    and salt['file.get_mode'](sdwdate_icon_record) == '0644'
    and sdwdate_icon_record_lstat.get('st_uid') == 0
    and sdwdate_icon_record_lstat.get('st_gid') == 0
    and owner_marker in salt['file.read'](sdwdate_icon_record) %}
{% set sdwdate_icon_state_valid = salt['cmd.retcode'](
    sdwdate_icon_manager ~ ' validate-removal', python_shell=false,
    ignore_retcode=true) == 0
    if platform_ok and sdwdate_icon_record_owned
       and sdwdate_icon_manager_owned else false %}
{% set tor_launcher_manager_lstat = salt['file.lstat'](tor_launcher_manager) %}
{% set tor_launcher_manager_exists = tor_launcher_manager_lstat|length > 0 %}
{% set tor_launcher_manager_regular = config_root_real
    and salt['file.file_exists'](tor_launcher_manager)
    and not salt['file.is_link'](tor_launcher_manager) %}
{% set tor_launcher_manager_owned = tor_launcher_manager_regular
    and salt['file.get_mode'](tor_launcher_manager) == '0755'
    and tor_launcher_manager_lstat.get('st_uid') == 0
    and tor_launcher_manager_lstat.get('st_gid') == 0
    and owner_marker in salt['file.read'](tor_launcher_manager) %}
{% set tor_launcher_record_lstat = salt['file.lstat'](tor_launcher_record) %}
{% set tor_launcher_record_exists = tor_launcher_record_lstat|length > 0 %}
{% set tor_launcher_record_regular = config_root_real
    and salt['file.file_exists'](tor_launcher_record)
    and not salt['file.is_link'](tor_launcher_record) %}
{% set tor_launcher_record_owned = tor_launcher_record_regular
    and salt['file.get_mode'](tor_launcher_record) == '0644'
    and tor_launcher_record_lstat.get('st_uid') == 0
    and tor_launcher_record_lstat.get('st_gid') == 0
    and owner_marker in salt['file.read'](tor_launcher_record) %}
{% set tor_launcher_state_valid = salt['cmd.retcode'](
    tor_launcher_manager ~ ' validate-removal', python_shell=false,
    ignore_retcode=true) == 0
    if platform_ok and tor_launcher_record_owned
       and tor_launcher_manager_owned else false %}
{% set cyan_icon_root_lstat = salt['file.lstat'](cyan_icon_root) %}
{% set cyan_icon_root_exists = cyan_icon_root_lstat|length > 0 %}
{% set cyan_icon_root_real = cyan_icon_root_exists
    and salt['file.directory_exists'](cyan_icon_root)
    and not salt['file.is_link'](cyan_icon_root) %}
{% set cyan_icon_owner_regular = salt['file.file_exists'](cyan_icon_owner)
    and not salt['file.is_link'](cyan_icon_owner) %}
{% set cyan_icon_root_owned = cyan_icon_root_real
    and cyan_icon_owner_regular
    and shared_marker in salt['file.read'](cyan_icon_owner) %}
{% set cyan_icon_tree = namespace(valid=false) %}
{% if platform_ok and cyan_icon_manager_owned and cyan_icon_root_owned %}
  {% set cyan_icon_tree.valid = salt['cmd.retcode'](
      cyan_icon_manager ~ ' validate-removal', python_shell=false,
      ignore_retcode=true) == 0 %}
{% endif %}
{% set cyan_icon_backup_lstat = salt['file.lstat'](cyan_icon_backup) %}
{% set cyan_icon_backup_exists = cyan_icon_backup_lstat|length > 0 %}
{% set cyan_icon_backup_real = cyan_icon_backup_exists
    and salt['file.directory_exists'](cyan_icon_backup)
    and not salt['file.is_link'](cyan_icon_backup) %}
{% set cyan_icon_backup_owner_regular = cyan_icon_backup_real
    and salt['file.file_exists'](cyan_icon_backup_owner)
    and not salt['file.is_link'](cyan_icon_backup_owner) %}
{% set cyan_icon_backup_owned = cyan_icon_backup_owner_regular
    and shared_marker in salt['file.read'](cyan_icon_backup_owner) %}
{% set cyan_icon_backup_tree = namespace(valid=false) %}
{% if platform_ok and cyan_icon_manager_owned and cyan_icon_backup_owned %}
  {% set cyan_icon_backup_tree.valid = salt['cmd.retcode'](
      cyan_icon_manager ~ ' validate-removal --target ' ~ cyan_icon_backup,
      python_shell=false, ignore_retcode=true) == 0 %}
{% endif %}
{% set cyan_icon_removal_tombstone_exists =
    salt['file.lstat'](cyan_icon_removal_tombstone)|length > 0 %}
{% set cyan_icon_removal_record_exists =
    salt['file.lstat'](cyan_icon_removal_record)|length > 0 %}
{% set cyan_icon_removal_state_exists = cyan_icon_removal_tombstone_exists
    or cyan_icon_removal_record_exists
    or salt['file.lstat'](cyan_icon_removal_external_temp)|length > 0
    or salt['file.lstat'](cyan_icon_active_removal_temp)|length > 0
    or salt['file.lstat'](cyan_icon_backup_removal_temp)|length > 0 %}
{% set cyan_icon_active_removal_valid = salt['cmd.retcode'](
    cyan_icon_manager ~ ' validate-removal-state', python_shell=false,
    ignore_retcode=true) == 0
    if platform_ok and cyan_icon_removal_state_exists
       and cyan_icon_manager_owned else false %}
{% set cyan_icon_backup_removal_valid = salt['cmd.retcode'](
    cyan_icon_manager ~ ' validate-removal-state --target ' ~ cyan_icon_backup,
    python_shell=false, ignore_retcode=true) == 0
    if platform_ok and cyan_icon_removal_state_exists
       and cyan_icon_manager_owned else false %}
{% set cyan_icon_removal_state_valid = cyan_icon_active_removal_valid
    or cyan_icon_backup_removal_valid %}

{% set sdwdate_dropin_root_lstat = salt['file.lstat'](sdwdate_dropin_root) %}
{% set sdwdate_dropin_root_exists = sdwdate_dropin_root_lstat|length > 0 %}
{% set sdwdate_dropin_root_real = sdwdate_dropin_root_exists
    and salt['file.directory_exists'](sdwdate_dropin_root)
    and not salt['file.is_link'](sdwdate_dropin_root) %}
{% set sdwdate_dropin_owner_lstat = salt['file.lstat'](sdwdate_dropin_owner) %}
{% set sdwdate_dropin_owner_exists = sdwdate_dropin_owner_lstat|length > 0 %}
{% set sdwdate_dropin_lstat = salt['file.lstat'](sdwdate_dropin) %}
{% set sdwdate_dropin_exists = sdwdate_dropin_lstat|length > 0 %}
{% set sdwdate_dropin_owner_regular = sdwdate_dropin_root_real
    and salt['file.file_exists'](sdwdate_dropin_owner)
    and not salt['file.is_link'](sdwdate_dropin_owner) %}
{% set sdwdate_dropin_root_owned = sdwdate_dropin_owner_regular
    and owner_marker in salt['file.read'](sdwdate_dropin_owner) %}

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
    (sdwdate_icon_manager, [owner_marker]),
    (sdwdate_icon_record, [owner_marker]),
    (tor_launcher_manager, [owner_marker]),
    (tor_launcher_record, [owner_marker]),
    (xfce_xsettings, [owner_marker]),
    (xfce_terminal, [owner_marker]),
    (qt5ct_config, [owner_marker]),
    (qt5ct_palette, [owner_marker]),
    (sdwdate_dropin, [owner_marker]),
    (sdwdate_dropin_owner, [owner_marker]),
    (dconf_defaults, [owner_marker]),
    (dconf_locks, [owner_marker]),
    (guest_hud_platform.get('early_session', ''), [owner_marker]),
    (guest_hud_platform.get('late_session', ''), [owner_marker])
] %}
{% set collision = namespace(found=false) %}
{% for version in gtksource_versions %}
  {% set source_root = '/usr/share/gtksourceview-' ~ version %}
  {% for directory in [source_root, source_root ~ '/styles'] %}
    {% set metadata = salt['file.lstat'](directory) %}
    {# 16877 is S_IFDIR | 0755; 33188 below is S_IFREG | 0644. #}
    {% if metadata and (metadata.get('st_mode') != 16877
        or metadata.get('st_uid') != 0 or metadata.get('st_gid') != 0) %}
      {% set collision.found = true %}
    {% endif %}
  {% endfor %}
  {% set style = source_root ~ '/styles/qubes-hud.xml' %}
  {% set metadata = salt['file.lstat'](style) %}
  {% if metadata %}
    {% if metadata.get('st_mode') != 33188
        or metadata.get('st_uid') != 0 or metadata.get('st_gid') != 0
        or metadata.get('st_nlink') != 1 %}
      {% set collision.found = true %}
    {% elif owner_marker not in salt['file.read'](style) %}
      {% set collision.found = true %}
    {% endif %}
  {% endif %}
{% endfor %}
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

{% if cyan_icon_record_exists and (
    not cyan_icon_record_owned
    or (cyan_icon_manager_exists and not cyan_icon_manager_owned)
    or ((cyan_icon_root_exists or cyan_icon_backup_exists)
        and not cyan_icon_manager_owned)
    or (cyan_icon_root_exists and (
        not cyan_icon_root_owned or not (
            cyan_icon_tree.valid or cyan_icon_active_removal_valid)))
    or (cyan_icon_backup_exists and (
        not cyan_icon_backup_owned or not (
            cyan_icon_backup_tree.valid or cyan_icon_backup_removal_valid)))) %}
  {% set collision.found = true %}
{% endif %}
{% if cyan_icon_removal_state_exists and not (
    cyan_icon_manager_owned and cyan_icon_removal_state_valid) %}
  {% set collision.found = true %}
{% endif %}
{% if sdwdate_icon_manager_exists and not sdwdate_icon_manager_owned %}
  {% set collision.found = true %}
{% endif %}
{% if sdwdate_icon_record_exists and (
    not sdwdate_icon_record_owned
    or not sdwdate_icon_manager_owned
    or not sdwdate_icon_state_valid) %}
  {% set collision.found = true %}
{% endif %}
{% if tor_launcher_manager_exists and not tor_launcher_manager_owned %}
  {% set collision.found = true %}
{% endif %}
{% if tor_launcher_record_exists and (
    not tor_launcher_record_owned
    or not tor_launcher_manager_owned
    or not tor_launcher_state_valid) %}
  {% set collision.found = true %}
{% endif %}
{% if (sdwdate_dropin_owner_exists or sdwdate_dropin_exists)
    and not sdwdate_dropin_root_owned %}
  {% set collision.found = true %}
{% endif %}

{% set managed_directories = [
    '/usr',
    '/usr/share',
    '/usr/share/icons',
    '/usr/share/sdwdate-gui',
    '/usr/share/sdwdate-gui/icons',
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
    qt5ct_root,
    qt5ct_colors_root,
    '/etc/systemd',
    '/etc/systemd/user',
    sdwdate_dropin_root,
    '/etc/dconf',
    '/etc/dconf/db',
    dconf_source_root,
    dconf_locks_root
] + guest_hud_platform.get('session_directories', [])
  + ([
      '/usr/libexec',
      '/usr/libexec/tor-control-panel'
    ] if tor_launcher_record_exists else []) %}
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

include:
  - qubes_gui.hud.font-rollback

{% for suffix, path in [
    ('early_session', guest_hud_platform['early_session']),
    ('late_session', guest_hud_platform['late_session']),
    ('dconf_defaults', dconf_defaults),
    ('dconf_locks', dconf_locks),
    ('xfce_xsettings', xfce_xsettings),
    ('xfce_terminal', xfce_terminal),
    ('qt5ct_config', qt5ct_config),
    ('qt5ct_palette', qt5ct_palette),
    ('sdwdate_qt5ct_dropin', sdwdate_dropin),
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

qubes_gui_guest_hud_rollback_remove_sdwdate_dropin_owner:
  file.absent:
    - name: {{ sdwdate_dropin_owner }}
    - require:
      - file: qubes_gui_guest_hud_rollback_remove_sdwdate_qt5ct_dropin

{% if cyan_icon_removal_state_valid %}
qubes_gui_guest_hud_rollback_recover_cyan_icon_removal:
  cmd.run:
{% if cyan_icon_active_removal_valid %}
    - name: {{ cyan_icon_manager }} recover-removal
{% else %}
    - name: >-
        {{ cyan_icon_manager }} recover-removal --target {{ cyan_icon_backup }}
{% endif %}
{% endif %}

{% if cyan_icon_tree.valid %}
qubes_gui_guest_hud_rollback_remove_cyan_icon_theme:
  cmd.run:
    - name: {{ cyan_icon_manager }} remove
{% if cyan_icon_removal_state_valid %}
    - require:
      - cmd: qubes_gui_guest_hud_rollback_recover_cyan_icon_removal
{% endif %}
{% endif %}

{% if cyan_icon_backup_tree.valid %}
qubes_gui_guest_hud_rollback_remove_cyan_icon_backup:
  cmd.run:
    - name: >-
        {{ cyan_icon_manager }} remove --target {{ cyan_icon_backup }}
{% if cyan_icon_removal_state_valid %}
    - require:
      - cmd: qubes_gui_guest_hud_rollback_recover_cyan_icon_removal
{% endif %}
{% endif %}

{% if cyan_icon_manager_owned %}
qubes_gui_guest_hud_rollback_remove_cyan_icon_manager:
  file.absent:
    - name: {{ cyan_icon_manager }}
{% if cyan_icon_tree.valid or cyan_icon_backup_tree.valid
    or cyan_icon_removal_state_valid %}
    - require:
{% if cyan_icon_tree.valid %}
      - cmd: qubes_gui_guest_hud_rollback_remove_cyan_icon_theme
{% endif %}
{% if cyan_icon_backup_tree.valid %}
      - cmd: qubes_gui_guest_hud_rollback_remove_cyan_icon_backup
{% endif %}
{% if cyan_icon_removal_state_valid %}
      - cmd: qubes_gui_guest_hud_rollback_recover_cyan_icon_removal
{% endif %}
{% endif %}
{% endif %}

{% if cyan_icon_record_owned %}
qubes_gui_guest_hud_rollback_remove_cyan_icon_record:
  file.absent:
    - name: {{ cyan_icon_record }}
{% if cyan_icon_tree.valid or cyan_icon_backup_tree.valid
    or cyan_icon_manager_owned %}
    - require:
{% if cyan_icon_tree.valid %}
      - cmd: qubes_gui_guest_hud_rollback_remove_cyan_icon_theme
{% endif %}
{% if cyan_icon_backup_tree.valid %}
      - cmd: qubes_gui_guest_hud_rollback_remove_cyan_icon_backup
{% endif %}
{% if cyan_icon_manager_owned %}
      - file: qubes_gui_guest_hud_rollback_remove_cyan_icon_manager
{% endif %}
{% endif %}
{% endif %}

{% if sdwdate_icon_record_owned %}
qubes_gui_guest_hud_rollback_restore_sdwdate_tray_icons:
  cmd.run:
    - name: {{ sdwdate_icon_manager }} remove

qubes_gui_guest_hud_rollback_remove_sdwdate_icon_manager:
  file.absent:
    - name: {{ sdwdate_icon_manager }}
    - require:
      - cmd: qubes_gui_guest_hud_rollback_restore_sdwdate_tray_icons
    - require_in:
      - file: qubes_gui_guest_hud_rollback_remove_config_owner
{% elif sdwdate_icon_manager_owned %}
qubes_gui_guest_hud_rollback_remove_sdwdate_icon_manager:
  file.absent:
    - name: {{ sdwdate_icon_manager }}
    - require_in:
      - file: qubes_gui_guest_hud_rollback_remove_config_owner
{% endif %}

{% if tor_launcher_record_owned %}
qubes_gui_guest_hud_rollback_restore_tor_control_panel_launcher:
  cmd.run:
    - name: {{ tor_launcher_manager }} remove

qubes_gui_guest_hud_rollback_remove_tor_launcher_manager:
  file.absent:
    - name: {{ tor_launcher_manager }}
    - require:
      - cmd: qubes_gui_guest_hud_rollback_restore_tor_control_panel_launcher
    - require_in:
      - file: qubes_gui_guest_hud_rollback_remove_qt5ct_config
      - file: qubes_gui_guest_hud_rollback_remove_qt5ct_palette
      - file: qubes_gui_guest_hud_rollback_remove_config_owner
{% elif tor_launcher_manager_owned %}
qubes_gui_guest_hud_rollback_remove_tor_launcher_manager:
  file.absent:
    - name: {{ tor_launcher_manager }}
    - require_in:
      - file: qubes_gui_guest_hud_rollback_remove_qt5ct_config
      - file: qubes_gui_guest_hud_rollback_remove_qt5ct_palette
      - file: qubes_gui_guest_hud_rollback_remove_config_owner
{% endif %}

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

{% for version in gtksource_versions %}
qubes_gui_guest_hud_rollback_remove_gtksourceview_{{ version|replace('.', '_') }}:
  file.absent:
    - name: /usr/share/gtksourceview-{{ version }}/styles/qubes-hud.xml
    - require:
      - cmd: qubes_gui_guest_hud_rollback_dconf_database
{% endfor %}

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

{% if sdwdate_dropin_root_owned %}
qubes_gui_guest_hud_rollback_empty_sdwdate_dropin_root:
  cmd.run:
    - name: >-
        /bin/sh -c 'changed=no;
        if test -d {{ sdwdate_dropin_root }} &&
        /usr/bin/rmdir {{ sdwdate_dropin_root }} 2>/dev/null;
        then changed=yes; fi;
        /usr/bin/printf "changed=%s\n" "$changed"'
    - stateful: true
    - require:
      - file: qubes_gui_guest_hud_rollback_remove_sdwdate_qt5ct_dropin
      - file: qubes_gui_guest_hud_rollback_remove_sdwdate_dropin_owner
{% endif %}

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
        /etc/qubes-hud/xdg/qt5ct/colors
        /etc/qubes-hud/xdg/qt5ct
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
      - file: qubes_gui_guest_hud_rollback_remove_qt5ct_config
      - file: qubes_gui_guest_hud_rollback_remove_qt5ct_palette
      - file: qubes_gui_guest_hud_rollback_remove_version
      - file: qubes_gui_guest_hud_rollback_remove_config_owner
{% if cyan_icon_manager_owned %}
      - file: qubes_gui_guest_hud_rollback_remove_cyan_icon_manager
{% endif %}
{% if cyan_icon_record_owned %}
      - file: qubes_gui_guest_hud_rollback_remove_cyan_icon_record
{% endif %}
{% if sdwdate_icon_manager_owned %}
      - file: qubes_gui_guest_hud_rollback_remove_sdwdate_icon_manager
{% endif %}
{% if tor_launcher_manager_owned %}
      - file: qubes_gui_guest_hud_rollback_remove_tor_launcher_manager
{% endif %}

qubes_gui_guest_hud_rollback_complete:
  test.nop:
    - name: >-
        Qubes HUD guest selection and assets were removed. Existing user
        preferences and shared runtime packages were left untouched.
    - require:
      - sls: qubes_gui.hud.font-rollback
      - file: qubes_gui_guest_hud_rollback_remove_early_session
      - file: qubes_gui_guest_hud_rollback_remove_late_session
      - file: qubes_gui_guest_hud_rollback_remove_theme_owner
{% if cyan_icon_tree.valid %}
      - cmd: qubes_gui_guest_hud_rollback_remove_cyan_icon_theme
{% endif %}
{% if cyan_icon_backup_tree.valid %}
      - cmd: qubes_gui_guest_hud_rollback_remove_cyan_icon_backup
{% endif %}
{% if cyan_icon_manager_owned %}
      - file: qubes_gui_guest_hud_rollback_remove_cyan_icon_manager
{% endif %}
{% if cyan_icon_record_owned %}
      - file: qubes_gui_guest_hud_rollback_remove_cyan_icon_record
{% endif %}
{% if sdwdate_icon_manager_owned %}
      - file: qubes_gui_guest_hud_rollback_remove_sdwdate_icon_manager
{% endif %}
{% if tor_launcher_manager_owned %}
      - file: qubes_gui_guest_hud_rollback_remove_tor_launcher_manager
{% endif %}
      - cmd: qubes_gui_guest_hud_rollback_dconf_database
{% for version in gtksource_versions %}
      - file: qubes_gui_guest_hud_rollback_remove_gtksourceview_{{ version|replace('.', '_') }}
{% endfor %}
      - cmd: qubes_gui_guest_hud_rollback_empty_theme_directories
      - cmd: qubes_gui_guest_hud_rollback_empty_config_directories
{% if sdwdate_dropin_root_owned %}
      - cmd: qubes_gui_guest_hud_rollback_empty_sdwdate_dropin_root
{% endif %}

{% endif %}
