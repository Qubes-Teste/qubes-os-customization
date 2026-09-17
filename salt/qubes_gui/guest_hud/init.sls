{# System application theme for Qubes TemplateVMs. Never writes /home. #}
{% from 'qubes_gui/guest_hud/map.jinja' import guest_hud_platform with context %}
{% set owner_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/guest_hud.' %}
{% set shared_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' %}
{% set theme_name = 'Qubes-HUD' %}
{% set theme_root = '/usr/share/themes/' ~ theme_name %}
{% set theme_owner = theme_root ~ '/.salt-owner' %}
{% set config_root = '/etc/qubes-hud' %}
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
{% set xdg_root = config_root ~ '/xdg' %}
{% set xfce_xsettings = xdg_root ~ '/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml' %}
{% set xfce_terminal = xdg_root ~ '/xfce4/terminal/terminalrc' %}
{% set qt5ct_root = xdg_root ~ '/qt5ct' %}
{% set qt5ct_colors_root = qt5ct_root ~ '/colors' %}
{% set qt5ct_config = qt5ct_root ~ '/qt5ct.conf' %}
{% set qt5ct_palette = qt5ct_colors_root ~ '/qubes-hud.conf' %}
{% set sdwdate_user_unit = '/usr/lib/systemd/user/sdwdate-gui.service' %}
{% set sdwdate_dropin_root = '/etc/systemd/user/sdwdate-gui.service.d' %}
{% set sdwdate_dropin_owner = sdwdate_dropin_root ~ '/.qubes-hud-owner' %}
{% set sdwdate_dropin = sdwdate_dropin_root ~ '/90-qubes-hud.conf' %}
{% set qt5ct = guest_hud_platform.get('qt5ct', false) %}
{% set sdwdate_qt5ct = guest_hud_platform.get('sdwdate_qt5ct', false) %}
{% set tor_control_panel_qt5ct = guest_hud_platform.get(
    'tor_control_panel_qt5ct', false) %}
{% set dconf_defaults = '/etc/dconf/db/local.d/90-qubes-hud' %}
{% set dconf_locks = '/etc/dconf/db/local.d/locks/90-qubes-hud' %}
{% set dconf_database = '/etc/dconf/db/local' %}
{% set dconf_source_root = '/etc/dconf/db/local.d' %}
{% set dconf_locks_root = dconf_source_root ~ '/locks' %}
{% set dconf_profile = '/etc/dconf/profile/user' %}
{% set gtksource_versions = ['3.0', '4'] %}
{% set qubesdb_read = '/usr/bin/qubesdb-read' %}
{% set vm_type = salt['cmd.run'](
    qubesdb_read ~ ' /qubes-vm-type', python_shell=false,
    ignore_retcode=true)|trim if salt['file.file_exists'](qubesdb_read) else '' %}
{% set platform_ok = grains.get('kernel') == 'Linux'
    and grains.get('virtual')|lower == 'xen'
    and vm_type == 'TemplateVM'
    and guest_hud_platform.get('supported', false) %}
{% set sdwdate_user_unit_regular = salt['file.file_exists'](sdwdate_user_unit)
    and not salt['file.is_link'](sdwdate_user_unit) %}

{% set config_root_lstat = salt['file.lstat'](config_root) %}
{% set config_root_real = config_root_lstat|length > 0
    and salt['file.directory_exists'](config_root)
    and not salt['file.is_link'](config_root) %}
{% set cyan_icon_root_lstat = salt['file.lstat'](cyan_icon_root) %}
{% set cyan_icon_root_exists = cyan_icon_root_lstat|length > 0 %}
{% set cyan_icon_root_real = cyan_icon_root_exists
    and salt['file.directory_exists'](cyan_icon_root)
    and not salt['file.is_link'](cyan_icon_root) %}
{% set cyan_icon_owner_regular = cyan_icon_root_real
    and salt['file.file_exists'](cyan_icon_owner)
    and not salt['file.is_link'](cyan_icon_owner) %}
{% set cyan_icon_root_owned = cyan_icon_owner_regular
    and shared_marker in salt['file.read'](cyan_icon_owner) %}
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
{% set manage_tor_launcher = tor_control_panel_qt5ct
    or tor_launcher_record_exists or tor_launcher_manager_exists %}
{% set cyan_icon_tree = namespace(valid=false) %}
{% if platform_ok and cyan_icon_root_owned and cyan_icon_manager_owned %}
  {% set cyan_icon_tree.valid = salt['cmd.retcode'](
      cyan_icon_manager ~ ' validate', python_shell=false,
      ignore_retcode=true) == 0 %}
{% endif %}
{% set cyan_icon_backup_tree = namespace(valid=false) %}
{% if platform_ok and cyan_icon_backup_owned and cyan_icon_manager_owned %}
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
{% set sdwdate_dropin_owner_regular = sdwdate_dropin_root_real
    and salt['file.file_exists'](sdwdate_dropin_owner)
    and not salt['file.is_link'](sdwdate_dropin_owner) %}
{% set sdwdate_dropin_root_owned = sdwdate_dropin_owner_regular
    and owner_marker in salt['file.read'](sdwdate_dropin_owner) %}

{# Refuse to adopt a pre-existing namespace or file we do not own. #}
{% set collision = namespace(found=false) %}
{# Use existing stock style directories; never create or replace a toolkit. #}
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
{% for directory, marker_file in [
    (theme_root, theme_owner),
    (config_root, config_owner)
] %}
  {% set directory_lstat = salt['file.lstat'](directory) %}
  {% set directory_exists = directory_lstat|length > 0 %}
  {% set marker_regular = salt['file.file_exists'](marker_file)
      and not salt['file.is_link'](marker_file) %}
  {% set marker_owned = owner_marker in salt['file.read'](marker_file)
      if marker_regular else false %}
  {% if directory_exists and (
      not salt['file.directory_exists'](directory)
      or salt['file.is_link'](directory)
      or not marker_owned) %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{# Refuse traversal through a symlink or non-directory at every parent that
   this state writes beneath. Standard shared parents need not be owned. #}
{% set managed_directories = [
    '/usr',
    '/usr/share',
    '/usr/share/icons',
    '/usr/share/sdwdate-gui',
    '/usr/share/sdwdate-gui/icons',
    cyan_icon_root,
    cyan_icon_backup,
    '/usr/share/themes',
    theme_root,
    theme_root ~ '/gtk-2.0',
    theme_root ~ '/gtk-3.0',
    theme_root ~ '/gtk-4.0',
    '/etc',
    config_root,
    xdg_root,
    xdg_root ~ '/xfce4',
    xdg_root ~ '/xfce4/xfconf',
    xdg_root ~ '/xfce4/xfconf/xfce-perchannel-xml',
    xdg_root ~ '/xfce4/terminal',
    '/etc/dconf',
    '/etc/dconf/db',
    dconf_source_root,
    dconf_locks_root
] + guest_hud_platform.get('session_directories', [])
  + ([
      '/usr/libexec',
      '/usr/libexec/tor-control-panel'
    ] if manage_tor_launcher else [])
  + ([
      qt5ct_root,
      qt5ct_colors_root
    ] if qt5ct else [])
  + ([
      '/etc/systemd',
      '/etc/systemd/user',
      sdwdate_dropin_root
    ] if sdwdate_qt5ct else []) %}
{% for directory in managed_directories %}
  {% set directory_lstat = salt['file.lstat'](directory) %}
  {% if directory_lstat|length > 0 and (
      not salt['file.directory_exists'](directory)
      or salt['file.is_link'](directory)) %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

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
    (cyan_icon_manager, [shared_marker]),
    (cyan_icon_record, [owner_marker]),
    (sdwdate_icon_manager, [owner_marker]),
    (sdwdate_icon_record, [owner_marker]),
    (tor_launcher_manager, [owner_marker]),
    (tor_launcher_record, [owner_marker]),
    (cyan_icon_owner, [shared_marker]),
    (cyan_icon_backup_owner, [shared_marker]),
    (xfce_xsettings, [owner_marker]),
    (xfce_terminal, [owner_marker]),
    (dconf_defaults, [owner_marker]),
    (dconf_locks, [owner_marker]),
    (guest_hud_platform.get('early_session', ''), [owner_marker]),
    (guest_hud_platform.get('late_session', ''), [owner_marker])
] + ([
    (qt5ct_config, [owner_marker]),
    (qt5ct_palette, [owner_marker])
  ] if qt5ct else [])
  + ([
    (sdwdate_dropin, [owner_marker]),
    (sdwdate_dropin_owner, [owner_marker])
  ] if sdwdate_qt5ct else []) %}
{% for path, markers in text_targets if path %}
  {% set target_lstat = salt['file.lstat'](path) %}
  {% set target_exists = target_lstat|length > 0 %}
  {% set target_regular = salt['file.file_exists'](path)
      and not salt['file.is_link'](path) %}
  {% set target_contents = salt['file.read'](path) if target_regular else '' %}
  {% set target_owned = namespace(found=false) %}
  {% for marker in markers %}
    {% if marker in target_contents %}
      {% set target_owned.found = true %}
    {% endif %}
  {% endfor %}
  {% if target_exists and (not target_regular or not target_owned.found) %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{% if cyan_icon_root_exists and not (
    cyan_icon_root_owned
    and cyan_icon_manager_owned
    and (cyan_icon_tree.valid or cyan_icon_active_removal_valid)) %}
  {% set collision.found = true %}
{% endif %}
{% if cyan_icon_backup_exists and not (
    cyan_icon_backup_owned
    and cyan_icon_manager_owned
    and (cyan_icon_backup_tree.valid or cyan_icon_backup_removal_valid)) %}
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
{% if sdwdate_qt5ct and sdwdate_dropin_root_exists
    and not sdwdate_dropin_root_owned %}
  {% set collision.found = true %}
{% endif %}

{% set dconf_profile_regular = salt['file.file_exists'](dconf_profile)
    and not salt['file.is_link'](dconf_profile) %}
{% set dconf_profile_usable = namespace(found=false) %}
{% if dconf_profile_regular %}
  {% for profile_line in salt['file.read'](dconf_profile).splitlines() %}
    {% if profile_line.split('#', 1)[0]|trim == 'system-db:local' %}
      {% set dconf_profile_usable.found = true %}
    {% endif %}
  {% endfor %}
{% endif %}

{% if not platform_ok %}
qubes_gui_guest_hud_unsupported_target:
  test.fail_without_changes:
    - name: >-
        qubes_gui.guest_hud supports Qubes Linux TemplateVMs from the Debian
        OS family and Fedora; it refuses dom0, AppVMs, StandaloneVMs, and
        other operating systems.

{% elif collision.found %}
qubes_gui_guest_hud_unmanaged_target_refused:
  test.fail_without_changes:
    - name: >-
        Refusing to overwrite a pre-existing Qubes-HUD path that is not an
        owned regular file or an owned real directory. No files were changed.

{% elif not dconf_profile_usable.found %}
qubes_gui_guest_hud_dconf_profile_unsupported:
  test.fail_without_changes:
    - name: >-
        The template's regular /etc/dconf/profile/user must include
        system-db:local before Qubes HUD system defaults can be enforced.

{% elif sdwdate_qt5ct and not sdwdate_user_unit_regular %}
qubes_gui_guest_hud_sdwdate_unit_unsupported:
  test.fail_without_changes:
    - name: >-
        The installed Sdwdate/PyQt5 target requires a regular
        /usr/lib/systemd/user/sdwdate-gui.service before its Qt palette can be
        scoped without changing the desktop-wide Qt environment.

{% else %}

include:
  - qubes_gui.hud.font

qubes_gui_guest_hud_runtime_packages:
  pkg.installed:
    - pkgs:
{% for package in guest_hud_platform.get('packages', []) %}
      - {{ package }}
{% endfor %}
    - require_in:
      - sls: qubes_gui.hud.font

qubes_gui_guest_hud_theme_root:
  file.directory:
    - name: {{ theme_root }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true

qubes_gui_guest_hud_theme_owner:
  file.managed:
    - name: {{ theme_owner }}
    - contents: |
        # {{ owner_marker }}
        theme={{ theme_name }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_theme_root

{% for toolkit in ['gtk-2.0', 'gtk-3.0', 'gtk-4.0'] %}
qubes_gui_guest_hud_{{ toolkit|replace('.', '_') }}_directory:
  file.directory:
    - name: {{ theme_root }}/{{ toolkit }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_guest_hud_theme_owner
{% endfor %}

qubes_gui_guest_hud_index:
  file.managed:
    - name: {{ theme_root }}/index.theme
    - source: salt://qubes_gui/guest_hud/files/index.theme
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_theme_owner

qubes_gui_guest_hud_gtk2_theme:
  file.managed:
    - name: {{ theme_root }}/gtk-2.0/gtkrc
    - source: salt://qubes_gui/guest_hud/files/gtkrc
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_gtk-2_0_directory

{% for toolkit in ['3', '4'] %}
qubes_gui_guest_hud_gtk{{ toolkit }}_wrapper:
  file.managed:
    - name: {{ theme_root }}/gtk-{{ toolkit }}.0/gtk.css
    - source: salt://qubes_gui/guest_hud/files/gtk-{{ toolkit }}.css
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_gtk-{{ toolkit }}_0_directory

qubes_gui_guest_hud_gtk{{ toolkit }}_dark_wrapper:
  file.managed:
    - name: {{ theme_root }}/gtk-{{ toolkit }}.0/gtk-dark.css
    - source: salt://qubes_gui/guest_hud/files/gtk-{{ toolkit }}.css
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_gtk{{ toolkit }}_wrapper

qubes_gui_guest_hud_gtk{{ toolkit }}_overlay:
  file.managed:
    - name: {{ theme_root }}/gtk-{{ toolkit }}.0/qubes-hud.css
    - source: salt://qubes_gui/hud/files/gtk-{{ toolkit }}.css
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_gtk{{ toolkit }}_wrapper
{% endfor %}

qubes_gui_guest_hud_config_root:
  file.directory:
    - name: {{ config_root }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true

qubes_gui_guest_hud_config_owner:
  file.managed:
    - name: {{ config_owner }}
    - contents: |
        # {{ owner_marker }}
        purpose=system application styling for Qubes TemplateVMs
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_config_root

{% if qt5ct %}
qubes_gui_guest_hud_qt5ct_root:
  file.directory:
    - name: {{ qt5ct_root }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true
    - require:
      - file: qubes_gui_guest_hud_config_owner

qubes_gui_guest_hud_qt5ct_colors_root:
  file.directory:
    - name: {{ qt5ct_colors_root }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_guest_hud_qt5ct_root

qubes_gui_guest_hud_qt5ct_palette:
  file.managed:
    - name: {{ qt5ct_palette }}
    - source: salt://qubes_gui/guest_hud/files/qt5ct-qubes-hud.conf
    - check_cmd: >-
        /usr/bin/python3 -c 'import configparser, re, sys;
        parser = configparser.ConfigParser(interpolation=None);
        assert parser.read(sys.argv[1]); section = parser["ColorScheme"];
        values = [section[key].split(",") for key in
        ("active_colors", "inactive_colors", "disabled_colors")];
        assert all(len(group) == 21 for group in values);
        assert all(re.fullmatch(r"#[0-9a-fA-F]{8}", color.strip())
        for group in values for color in group)'
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_qt5ct_colors_root

qubes_gui_guest_hud_qt5ct_config:
  file.managed:
    - name: {{ qt5ct_config }}
    - source: salt://qubes_gui/guest_hud/files/qt5ct.conf
    - check_cmd: >-
        /usr/bin/python3 -c 'import configparser, sys;
        parser = configparser.ConfigParser(interpolation=None);
        assert parser.read(sys.argv[1]); section = parser["Appearance"];
        assert section.getboolean("custom_palette");
        assert section["color_scheme_path"] ==
        "$XDG_CONFIG_HOME/qt5ct/colors/qubes-hud.conf";
        assert section["icon_theme"] == "Qubes-HUD-Cyan";
        assert section["standard_dialogs"] == "default";
        assert section["style"] == "Fusion"'
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: qubes_gui_guest_hud_runtime_packages
      - file: qubes_gui_guest_hud_qt5ct_palette

{% endif %}

{% if sdwdate_qt5ct %}
qubes_gui_guest_hud_sdwdate_dropin_root:
  file.directory:
    - name: {{ sdwdate_dropin_root }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true
    - require:
      - pkg: qubes_gui_guest_hud_runtime_packages

qubes_gui_guest_hud_sdwdate_dropin_owner:
  file.managed:
    - name: {{ sdwdate_dropin_owner }}
    - contents: |
        # {{ owner_marker }}
        purpose=scope the Qubes HUD Qt palette to Sdwdate and its children
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_sdwdate_dropin_root

qubes_gui_guest_hud_sdwdate_qt5ct_dropin:
  file.managed:
    - name: {{ sdwdate_dropin }}
    - source: salt://qubes_gui/guest_hud/files/sdwdate-gui-qubes-hud.conf
    - check_cmd: >-
        /usr/bin/python3 -c 'import sys;
        lines = [line.strip() for line in
        open(sys.argv[1], encoding="utf-8") if line.strip()
        and not line.lstrip().startswith("#")];
        assert lines == ["[Service]",
        "Environment=QT_QPA_PLATFORMTHEME=qt5ct",
        "Environment=XDG_CONFIG_HOME=/etc/qubes-hud/xdg"]'
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_qt5ct_config
      - file: qubes_gui_guest_hud_sdwdate_dropin_owner
{% endif %}

qubes_gui_guest_hud_sdwdate_icon_manager:
  file.managed:
    - name: {{ sdwdate_icon_manager }}
    - source: salt://qubes_gui/guest_hud/files/manage-sdwdate-tray-icons
    - check_cmd: >-
        /usr/bin/python3 -c 'import ast, sys;
        compile(ast.parse(open(sys.argv[1], encoding="utf-8").read(),
        filename=sys.argv[1]), sys.argv[1], "exec")'
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_guest_hud_config_owner

qubes_gui_guest_hud_sdwdate_tray_icons:
  cmd.run:
    - name: {{ sdwdate_icon_manager }} install
    - unless: {{ sdwdate_icon_manager }} check
    - failhard: true
    - require:
      - file: qubes_gui_guest_hud_sdwdate_icon_manager

{% if manage_tor_launcher %}
qubes_gui_guest_hud_tor_launcher_manager:
  file.managed:
    - name: {{ tor_launcher_manager }}
    - source: >-
        salt://qubes_gui/guest_hud/files/manage-tor-control-panel-launcher
    - check_cmd: >-
        /usr/bin/python3 -c 'import ast, sys;
        compile(ast.parse(open(sys.argv[1], encoding="utf-8").read(),
        filename=sys.argv[1]), sys.argv[1], "exec")'
    - user: root
    - group: root
    - mode: '0755'
    - backup: minion
    - require:
      - file: qubes_gui_guest_hud_config_owner

qubes_gui_guest_hud_tor_control_panel_launcher:
  cmd.run:
    - name: {{ tor_launcher_manager }} install
    - unless: {{ tor_launcher_manager }} check
    - failhard: true
    - require:
      - file: qubes_gui_guest_hud_tor_launcher_manager
{% if tor_control_panel_qt5ct %}
      - file: qubes_gui_guest_hud_qt5ct_config
{% endif %}
{% endif %}

qubes_gui_guest_hud_cyan_icon_manager:
  file.managed:
    - name: {{ cyan_icon_manager }}
    - source: salt://qubes_gui/hud/files/manage-cyan-icon-theme
    - check_cmd: >-
        /usr/bin/python3 -c 'import ast, sys;
        ast.parse(open(sys.argv[1], encoding="utf-8").read(),
        filename=sys.argv[1])'
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_guest_hud_config_owner
      - pkg: qubes_gui_guest_hud_runtime_packages

qubes_gui_guest_hud_cyan_icon_theme:
  cmd.run:
    - name: {{ cyan_icon_manager }} install
    - unless: {{ cyan_icon_manager }} check
    - require:
      - file: qubes_gui_guest_hud_cyan_icon_manager

qubes_gui_guest_hud_cyan_icon_record:
  file.managed:
    - name: {{ cyan_icon_record }}
    - contents: |
        # {{ owner_marker }}
        schema=1
        theme={{ cyan_icon_root }}
        manager={{ cyan_icon_manager }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: qubes_gui_guest_hud_cyan_icon_theme

qubes_gui_guest_hud_version:
  file.managed:
    - name: {{ config_root }}/VERSION
    - contents: |
        # {{ owner_marker }}
        7
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_config_owner
      - file: qubes_gui_guest_hud_cyan_icon_record
      - cmd: qubes_gui_guest_hud_sdwdate_tray_icons
{% if manage_tor_launcher %}
      - cmd: qubes_gui_guest_hud_tor_control_panel_launcher
{% endif %}
{% if sdwdate_qt5ct %}
      - file: qubes_gui_guest_hud_sdwdate_qt5ct_dropin
{% endif %}

qubes_gui_guest_hud_xfce_xsettings:
  file.managed:
    - name: {{ xfce_xsettings }}
    - source: salt://qubes_gui/guest_hud/files/xsettings.xml
    - check_cmd: >-
        /usr/bin/python3 -c 'import sys; import xml.etree.ElementTree as ET;
        ET.parse(sys.argv[1])'
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: true
    - require:
      - file: qubes_gui_guest_hud_config_owner
      - file: qubes_gui_guest_hud_cyan_icon_record

qubes_gui_guest_hud_xfce_terminal:
  file.managed:
    - name: {{ xfce_terminal }}
    - source: salt://qubes_gui/guest_hud/files/terminalrc
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: true
    - require:
      - file: qubes_gui_guest_hud_config_owner

qubes_gui_guest_hud_early_session:
  file.managed:
    - name: {{ guest_hud_platform['early_session'] }}
    - source: salt://qubes_gui/guest_hud/files/59qubes-hud-xdg
    - check_cmd: /bin/sh -n
    - user: root
    - group: root
    - mode: '{{ guest_hud_platform['session_mode'] }}'
    - backup: minion
    - require:
      - file: qubes_gui_guest_hud_xfce_xsettings

qubes_gui_guest_hud_late_session:
  file.managed:
    - name: {{ guest_hud_platform['late_session'] }}
    - source: salt://qubes_gui/guest_hud/files/90qubes-hud-qt
    - check_cmd: /bin/sh -n
    - user: root
    - group: root
    - mode: '{{ guest_hud_platform['session_mode'] }}'
    - backup: minion
    - require:
      - file: qubes_gui_guest_hud_early_session

qubes_gui_guest_hud_dconf_locks_directory:
  file.directory:
    - name: {{ dconf_locks_root }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true

qubes_gui_guest_hud_dconf_defaults:
  file.managed:
    - name: {{ dconf_defaults }}
    - source: salt://qubes_gui/guest_hud/files/dconf-defaults
    - user: root
    - group: root
    - mode: '0644'
    - backup: minion
    - require:
      - pkg: qubes_gui_guest_hud_runtime_packages
      - file: qubes_gui_guest_hud_cyan_icon_record
{% for version in gtksource_versions
    if salt['file.directory_exists']('/usr/share/gtksourceview-' ~ version ~ '/styles') %}
      - file: qubes_gui_guest_hud_gtksourceview_{{ version|replace('.', '_') }}
{% endfor %}

{% for version in gtksource_versions
    if salt['file.directory_exists']('/usr/share/gtksourceview-' ~ version ~ '/styles') %}
qubes_gui_guest_hud_gtksourceview_{{ version|replace('.', '_') }}:
  file.managed:
    - name: /usr/share/gtksourceview-{{ version }}/styles/qubes-hud.xml
    - source: salt://qubes_gui/guest_hud/files/gtksourceview.xml
    - check_cmd: >-
        /usr/bin/python3 -c 'import sys, xml.etree.ElementTree as ET;
        root = ET.parse(sys.argv[1]).getroot();
        assert root.tag == "style-scheme" and root.get("id") == "qubes-hud"
        and root.get("version") == "1.0"'
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: qubes_gui_guest_hud_runtime_packages
{% endfor %}

qubes_gui_guest_hud_dconf_locks:
  file.managed:
    - name: {{ dconf_locks }}
    - source: salt://qubes_gui/guest_hud/files/dconf-locks
    - user: root
    - group: root
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_guest_hud_dconf_locks_directory
      - file: qubes_gui_guest_hud_dconf_defaults

qubes_gui_guest_hud_dconf_database:
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
      - file: qubes_gui_guest_hud_dconf_defaults
      - file: qubes_gui_guest_hud_dconf_locks

qubes_gui_guest_hud_complete:
  test.nop:
    - name: >-
        Qubes HUD guest theme is installed in this TemplateVM. Dependent qubes
        receive it after they restart.
    - require:
      - sls: qubes_gui.hud.font
      - file: qubes_gui_guest_hud_gtk2_theme
      - file: qubes_gui_guest_hud_gtk3_overlay
      - file: qubes_gui_guest_hud_gtk4_overlay
      - file: qubes_gui_guest_hud_late_session
      - file: qubes_gui_guest_hud_xfce_terminal
      - file: qubes_gui_guest_hud_cyan_icon_record
      - cmd: qubes_gui_guest_hud_sdwdate_tray_icons
{% if manage_tor_launcher %}
      - cmd: qubes_gui_guest_hud_tor_control_panel_launcher
{% endif %}
{% if qt5ct %}
      - file: qubes_gui_guest_hud_qt5ct_palette
      - file: qubes_gui_guest_hud_qt5ct_config
{% endif %}
{% if sdwdate_qt5ct %}
      - file: qubes_gui_guest_hud_sdwdate_qt5ct_dropin
{% endif %}
      - cmd: qubes_gui_guest_hud_dconf_database

{% endif %}
