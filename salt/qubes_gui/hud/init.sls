{# Qubes OS 4.3 dom0 HUD session. No running desktop process is restarted. #}
{% set settings = salt['pillar.get']('qubes_gui:hud', {}) %}
{% set desktop_user = settings.get('desktop_user', 'user') %}
{% set desktop_group = settings.get('desktop_group', desktop_user) %}
{% set transport = settings.get('package_transport', 'qubes-updatevm') %}
{% set user_info = salt['user.info'](desktop_user) %}
{% set desktop_uid = user_info.get('uid', -1) if user_info else -1 %}
{% set desktop_home = user_info.get('home', '/home/' ~ desktop_user) if user_info else '/home/' ~ desktop_user %}
{% set owner_marker = 'Managed by qubes-os-customization Salt formula' %}
{% set hud_asset_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' %}
{% set legacy_i3_sha256 = 'fbd035f0e776acf755cffb021e8ef922b1da005ce4c54b3e54f3af545daf1f8f' %}
{% set i3_compat_sha256 = '5894d81ca085866185170577ec4a957e8094c60cca5f986d532399f15dac8402' %}
{% set expected_i3_settings_evr = '1.14-1.fc41' %}
{% set release = grains.get('osrelease', '')|string %}
{% set architecture = grains.get('cpuarch', grains.get('osarch', ''))|string %}
{% set platform_ok = grains.get('virtual') == 'Qubes'
    and grains.get('virtual_subtype') == 'Xen Dom0'
    and (release == '4.3' or release.startswith('4.3.'))
    and architecture == 'x86_64' %}
{% set installed_i3_settings_evr = salt['cmd.run'](
    "/usr/bin/rpm -q --qf '%{VERSION}-%{RELEASE}' i3-settings-qubes",
    python_shell=false,
    ignore_retcode=true)|trim %}
{% set runtime_packages = ['rofi', 'feh', 'picom', 'breeze-icon-theme'] %}

{# The base formula supplies i3. Match /usr/bin/i3 to the installed RPM's
   SHA-256 record so a package update is accepted without trusting a replacement
   binary merely because it is present at the packaged pathname. #}
{% set official_i3_lstat = salt['file.lstat']('/usr/bin/i3') %}
{% set official_i3_package = salt['cmd.run'](
    "/usr/bin/rpm -qf --qf '%{NAME}' /usr/bin/i3",
    python_shell=false, ignore_retcode=true)|trim %}
{% set official_i3_digest_algorithm = salt['cmd.run'](
    "/usr/bin/rpm -q --qf '%{FILEDIGESTALGO}' i3",
    python_shell=false, ignore_retcode=true)|trim %}
{% set official_i3_files = salt['cmd.run'](
    "/usr/bin/rpm -q --qf '[%{FILENAMES}\\t%{FILEDIGESTS}\\n]' i3",
    python_shell=false, ignore_retcode=true) %}
{% set official_i3_digest = namespace(value='') %}
{% for line in official_i3_files.splitlines() %}
  {% set fields = line.split('\t') %}
  {% if fields|length == 2 and fields[0] == '/usr/bin/i3' %}
    {% set official_i3_digest.value = fields[1] %}
  {% endif %}
{% endfor %}
{% set official_i3_verified = official_i3_package == 'i3'
    and official_i3_digest_algorithm == '8'
    and official_i3_digest.value|length == 64
    and salt['file.file_exists']('/usr/bin/i3')
    and not salt['file.is_link']('/usr/bin/i3')
    and official_i3_lstat.get('st_uid') == 0
    and official_i3_lstat.get('st_gid') == 0
    and salt['file.get_mode']('/usr/bin/i3') == '0755'
    and salt['file.get_hash']('/usr/bin/i3', 'sha256')
        == official_i3_digest.value %}

{% set user_i3_config = desktop_home ~ '/.config/i3/config' %}
{% set user_rofi_theme = desktop_home ~ '/.config/rofi/config.rasi' %}
{% set user_dunst_config = desktop_home ~ '/.config/dunst/dunstrc' %}
{% set user_xfce_terminal = desktop_home ~ '/.config/xfce4/terminal/terminalrc' %}
{% set user_gtk2_rc = desktop_home ~ '/.gtkrc-2.0' %}
{% set user_gtk3_css = desktop_home ~ '/.config/gtk-3.0/gtk.css' %}
{% set user_gtk3_settings = desktop_home ~ '/.config/gtk-3.0/settings.ini' %}
{% set user_gtk4_css = desktop_home ~ '/.config/gtk-4.0/gtk.css' %}
{% set user_gtk4_settings = desktop_home ~ '/.config/gtk-4.0/settings.ini' %}
{% set lightdm_config = '/etc/lightdm/lightdm.conf.d/91-qubes-hud.conf' %}
{% set xsession_file = '/usr/share/xsessions/qubes-hud.desktop' %}
{% set legacy_i3_binary = '/usr/local/libexec/qubes-hud/i3' %}
{% set legacy_i3_owner = '/usr/local/libexec/qubes-hud/i3.owner' %}
{% set keyboard_helper = '/usr/local/libexec/qubes-hud/apply-keyboard-layout' %}
{% set hud_autostart_helper = '/usr/local/libexec/qubes-hud/hud-xdg-autostart' %}
{% set glow_helper = '/usr/local/libexec/qubes-hud/hud-glow' %}
{% set glow_pixels = '/usr/local/libexec/qubes-hud/glow_pixels.py' %}
{% set bindings_helper = '/usr/local/libexec/qubes-hud/hud-bindings' %}
{% set bindings_keyboard = '/usr/local/libexec/qubes-hud/bindings_keyboard.py' %}
{% set logs_module = '/usr/local/libexec/qubes-hud/hud_logs.py' %}
{% set monitor_module = '/usr/local/libexec/qubes-hud/hud_monitor.py' %}
{% set workspace_helper = '/usr/local/libexec/qubes-hud/hud-workspace' %}
{% set bindings_data = '/usr/local/libexec/qubes-hud/bindings.json' %}
{% set bindings_desktop = '/usr/share/applications/qubes-hud-bindings.desktop' %}
{% set dom0_logs_desktop = '/usr/share/applications/qubes-hud-dom0-logs.desktop' %}
{% set xen_logs_desktop = '/usr/share/applications/qubes-hud-xen-logs.desktop' %}
{% set terminal_resources = '/usr/local/libexec/qubes-hud/hud-terminal.Xresources' %}
{% set dom0_logs_config = '/usr/local/libexec/qubes-hud/hud-dom0-logs.conf' %}
{% set xen_logs_config = '/usr/local/libexec/qubes-hud/hud-xen-logs.conf' %}
{% set terminal_tmpfiles = '/usr/lib/user-tmpfiles.d/qubes-hud-terminals.conf' %}
{% set terminal_views = [
    ('dom0', 'dom0-logs', 'HUD Dom0 Logs', 'QubesHudDom0Logs',
     '/usr/sbin/rsyslogd -n -iNONE -f ' ~ dom0_logs_config),
    ('xen', 'xen-logs', 'HUD Xen Logs', 'QubesHudXenLogs',
     '/usr/sbin/rsyslogd -n -iNONE -f ' ~ xen_logs_config),
    ('top', 'top', 'HUD top', 'QubesHudTop', '/usr/bin/top --secure-mode'),
    ('xentop', 'xentop', 'HUD xentop', 'QubesHudXentop',
     '/usr/sbin/xentop --delay=2 --full-name'),
    ('cgtop', 'cgtop', 'HUD systemd-cgtop', 'QubesHudCgtop',
     '/usr/bin/systemd-cgtop --delay=2 --depth=2')
] %}
{% set user_runtime = '/run/user/' ~ desktop_uid %}
{% set terminal_runtime_root = user_runtime ~ '/qubes-hud-terminals' %}
{% set terminal_text_targets = [terminal_resources, dom0_logs_config,
    xen_logs_config, terminal_tmpfiles] %}
{% for view, desktop, title, wmclass, command in terminal_views %}
  {% set _ = terminal_text_targets.append('/usr/share/applications/qubes-hud-' ~ desktop ~ '.desktop') %}
{% endfor %}
{% set picom_config = '/usr/local/libexec/qubes-hud/picom.conf' %}
{% set window_shader = '/usr/local/libexec/qubes-hud/window-glass.glsl' %}
{% set legacy_picom_config = '/etc/xdg/picom.conf' %}
{% set picom_package_owner = '/usr/local/libexec/qubes-hud/picom.package-owner' %}
{% set icon_settings_owner = '/usr/local/libexec/qubes-hud/icon-settings.owner' %}
{% set cyan_icon_manager = '/usr/local/libexec/qubes-hud/manage-cyan-icon-theme' %}
{% set cyan_icon_record = '/usr/local/libexec/qubes-hud/cyan-icon-theme.owner' %}
{% set tray_mode_manager = '/usr/local/libexec/qubes-hud/manage-trayicon-mode' %}
{% set tray_mode_record = '/usr/local/libexec/qubes-hud/trayicon-mode.owner' %}
{% set cyan_icon_root = '/usr/share/icons/Qubes-HUD-Cyan' %}
{% set cyan_icon_owner = cyan_icon_root ~ '/.qubes-hud-owner' %}
{% set cyan_icon_backup = '/usr/share/icons/.Qubes-HUD-Cyan.previous' %}
{% set cyan_icon_backup_owner = cyan_icon_backup ~ '/.qubes-hud-owner' %}
{% set cyan_icon_removal_tombstone = '/usr/share/icons/.Qubes-HUD-Cyan.removing' %}
{% set cyan_icon_removal_record = '/usr/share/icons/.Qubes-HUD-Cyan.removing.json' %}
{% set cyan_icon_removal_external_temp = '/usr/share/icons/.Qubes-HUD-Cyan.removing.json.tmp' %}
{% set cyan_icon_active_removal_temp = cyan_icon_root ~ '/.Qubes-HUD-Cyan.removing.json.tmp' %}
{% set cyan_icon_backup_removal_temp = cyan_icon_backup ~ '/.Qubes-HUD-Cyan.removing.json.tmp' %}
{% set hud_wallpaper = '/usr/share/backgrounds/qubes-hud.png' %}
{% set hud_wallpaper_owner = '/usr/share/backgrounds/qubes-hud.png.owner' %}

{#
  Every target is checked with lstat before marker reads. This catches broken
  symlinks, directories, FIFOs, devices, and sockets that file.file_exists
  deliberately ignores. It also prevents rollback's file.absent states from
  ever recursively deleting an unexpected directory.
#}
{% set legacy_picom_regular = salt['file.file_exists'](legacy_picom_config)
    and not salt['file.is_link'](legacy_picom_config) %}
{% set legacy_picom_contents = salt['file.read'](legacy_picom_config)
    if legacy_picom_regular else '' %}
{% set legacy_picom_owned = owner_marker in legacy_picom_contents
    or hud_asset_marker in legacy_picom_contents %}

{# The retired executable is replaced only when its exact bytes and adjacent
   record prove ownership. Either known record may accompany either known file
   during an interrupted migration. Writing the new record first also makes a
   partial first install, with only the record present, recoverable. #}
{% set legacy_i3_lstat = salt['file.lstat'](legacy_i3_binary) %}
{% set legacy_i3_exists = legacy_i3_lstat|length > 0 %}
{% set legacy_i3_owner_lstat = salt['file.lstat'](legacy_i3_owner) %}
{% set legacy_i3_owner_exists = legacy_i3_owner_lstat|length > 0 %}
{% set legacy_i3_owner_regular = salt['file.file_exists'](legacy_i3_owner)
    and not salt['file.is_link'](legacy_i3_owner) %}
{% set legacy_i3_expected_record = '# ' ~ owner_marker ~ '.\n'
    ~ 'target=' ~ legacy_i3_binary ~ '\n'
    ~ 'sha256=' ~ legacy_i3_sha256 ~ '\n' %}
{% set i3_compat_expected_record = '# ' ~ owner_marker ~ '.\n'
    ~ 'target=' ~ legacy_i3_binary ~ '\n'
    ~ 'sha256=' ~ i3_compat_sha256 ~ '\n' %}
{% set legacy_i3_owner_owned = legacy_i3_owner_regular
    and legacy_i3_owner_lstat.get('st_uid') == 0
    and legacy_i3_owner_lstat.get('st_gid') == 0
    and salt['file.get_mode'](legacy_i3_owner) == '0644'
    and salt['file.read'](legacy_i3_owner) in [
        legacy_i3_expected_record, i3_compat_expected_record] %}
{% set legacy_i3_owned = legacy_i3_exists
    and salt['file.file_exists'](legacy_i3_binary)
    and not salt['file.is_link'](legacy_i3_binary)
    and legacy_i3_lstat.get('st_uid') == 0
    and legacy_i3_lstat.get('st_gid') == 0
    and salt['file.get_mode'](legacy_i3_binary) == '0755'
    and legacy_i3_owner_owned
    and salt['file.get_hash'](legacy_i3_binary, 'sha256') in [
        legacy_i3_sha256, i3_compat_sha256] %}
{% set wallpaper_owner_regular = salt['file.file_exists'](hud_wallpaper_owner)
    and not salt['file.is_link'](hud_wallpaper_owner) %}
{% set wallpaper_owner_owned = owner_marker in salt['file.read'](hud_wallpaper_owner)
    if wallpaper_owner_regular else false %}
{% set picom_package_owner_regular = salt['file.file_exists'](picom_package_owner)
    and not salt['file.is_link'](picom_package_owner) %}
{% set picom_package_owner_owned = owner_marker in salt['file.read'](picom_package_owner)
    if picom_package_owner_regular else false %}
{% set picom_preinstalled = salt['cmd.retcode'](
    '/usr/bin/rpm --quiet -q picom', python_shell=false,
    ignore_retcode=true) == 0 %}
{% set cyan_icon_root_lstat = salt['file.lstat'](cyan_icon_root) %}
{% set cyan_icon_root_exists = cyan_icon_root_lstat|length > 0 %}
{% set cyan_icon_root_real = cyan_icon_root_exists
    and salt['file.directory_exists'](cyan_icon_root)
    and not salt['file.is_link'](cyan_icon_root) %}
{% set cyan_icon_owner_regular = cyan_icon_root_real
    and salt['file.file_exists'](cyan_icon_owner)
    and not salt['file.is_link'](cyan_icon_owner) %}
{% set cyan_icon_root_owned = cyan_icon_owner_regular
    and hud_asset_marker in salt['file.read'](cyan_icon_owner) %}
{% set cyan_icon_manager_regular = salt['file.file_exists'](cyan_icon_manager)
    and not salt['file.is_link'](cyan_icon_manager) %}
{% set cyan_icon_manager_owned = cyan_icon_manager_regular
    and salt['file.get_mode'](cyan_icon_manager) == '0755'
    and salt['file.lstat'](cyan_icon_manager).get('st_uid') == 0
    and salt['file.lstat'](cyan_icon_manager).get('st_gid') == 0
    and hud_asset_marker in salt['file.read'](cyan_icon_manager) %}
{% set cyan_icon_tree_valid = salt['cmd.retcode'](
    cyan_icon_manager ~ ' validate', python_shell=false,
    ignore_retcode=true) == 0
    if platform_ok and cyan_icon_root_owned and cyan_icon_manager_owned else false %}
{% set cyan_icon_backup_lstat = salt['file.lstat'](cyan_icon_backup) %}
{% set cyan_icon_backup_exists = cyan_icon_backup_lstat|length > 0 %}
{% set cyan_icon_backup_real = cyan_icon_backup_exists
    and salt['file.directory_exists'](cyan_icon_backup)
    and not salt['file.is_link'](cyan_icon_backup) %}
{% set cyan_icon_backup_owner_regular = cyan_icon_backup_real
    and salt['file.file_exists'](cyan_icon_backup_owner)
    and not salt['file.is_link'](cyan_icon_backup_owner) %}
{% set cyan_icon_backup_owned = cyan_icon_backup_owner_regular
    and hud_asset_marker in salt['file.read'](cyan_icon_backup_owner) %}
{% set cyan_icon_backup_valid = salt['cmd.retcode'](
    cyan_icon_manager ~ ' validate-removal --target ' ~ cyan_icon_backup,
    python_shell=false, ignore_retcode=true) == 0
    if platform_ok and cyan_icon_backup_owned and cyan_icon_manager_owned
    else false %}
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
{% set tray_mode_manager_lstat = salt['file.lstat'](tray_mode_manager) %}
{% set tray_mode_manager_exists = tray_mode_manager_lstat|length > 0 %}
{% set tray_mode_manager_regular = salt['file.file_exists'](tray_mode_manager)
    and not salt['file.is_link'](tray_mode_manager) %}
{% set tray_mode_manager_owned = tray_mode_manager_regular
    and salt['file.get_mode'](tray_mode_manager) == '0755'
    and tray_mode_manager_lstat.get('st_uid') == 0
    and tray_mode_manager_lstat.get('st_gid') == 0
    and hud_asset_marker in salt['file.read'](tray_mode_manager) %}
{% set tray_mode_record_lstat = salt['file.lstat'](tray_mode_record) %}
{% set tray_mode_record_exists = tray_mode_record_lstat|length > 0 %}
{% set tray_mode_record_regular = salt['file.file_exists'](tray_mode_record)
    and not salt['file.is_link'](tray_mode_record) %}
{% set tray_mode_record_owned = tray_mode_record_regular
    and salt['file.get_mode'](tray_mode_record) == '0644'
    and tray_mode_record_lstat.get('st_uid') == 0
    and tray_mode_record_lstat.get('st_gid') == 0
    and hud_asset_marker in salt['file.read'](tray_mode_record) %}
{% set tray_mode_state_valid = salt['cmd.retcode'](
    tray_mode_manager ~ ' validate-removal', python_shell=false,
    ignore_retcode=true) == 0
    if platform_ok and tray_mode_record_owned and tray_mode_manager_owned
    else false %}

{% set text_targets = [
    (user_i3_config, [owner_marker]),
    (user_rofi_theme, [owner_marker, hud_asset_marker]),
    (user_dunst_config, [owner_marker, hud_asset_marker]),
    (user_xfce_terminal, [owner_marker, hud_asset_marker]),
    (user_gtk2_rc, [owner_marker, hud_asset_marker]),
    (user_gtk3_css, [owner_marker, hud_asset_marker]),
    (user_gtk3_settings, [owner_marker, hud_asset_marker]),
    (user_gtk4_css, [owner_marker, hud_asset_marker]),
    (user_gtk4_settings, [owner_marker, hud_asset_marker]),
    (lightdm_config, [owner_marker]),
    (xsession_file, [owner_marker]),
    (keyboard_helper, [owner_marker]),
    (hud_autostart_helper, [owner_marker]),
    (glow_helper, [hud_asset_marker]),
    (glow_pixels, [hud_asset_marker]),
    (bindings_helper, [hud_asset_marker]),
    (bindings_keyboard, [hud_asset_marker]),
    (logs_module, [hud_asset_marker]),
    (monitor_module, [hud_asset_marker]),
    (workspace_helper, [hud_asset_marker]),
    (bindings_data, [hud_asset_marker]),
    (bindings_desktop, [hud_asset_marker]),
    (dom0_logs_desktop, [hud_asset_marker]),
    (xen_logs_desktop, [hud_asset_marker]),
    (picom_config, [owner_marker, hud_asset_marker]),
    (window_shader, [hud_asset_marker]),
    (picom_package_owner, [owner_marker]),
    (icon_settings_owner, [owner_marker]),
    (cyan_icon_manager, [hud_asset_marker]),
    (cyan_icon_record, [owner_marker]),
    (tray_mode_manager, [hud_asset_marker]),
    (tray_mode_record, [hud_asset_marker]),
    (cyan_icon_owner, [hud_asset_marker]),
    (hud_wallpaper_owner, [owner_marker])
] %}
{% for path in terminal_text_targets %}
  {% set _ = text_targets.append((path, [hud_asset_marker])) %}
{% endfor %}
{% set directory_targets = [
    '/usr',
    '/usr/lib',
    '/usr/lib/user-tmpfiles.d',
    '/usr/share',
    '/usr/share/icons',
    '/usr/share/applications',
    cyan_icon_root,
    cyan_icon_backup,
    desktop_home,
    desktop_home ~ '/.config',
    desktop_home ~ '/.config/i3',
    desktop_home ~ '/.config/rofi',
    desktop_home ~ '/.config/dunst',
    desktop_home ~ '/.config/xfce4',
    desktop_home ~ '/.config/xfce4/terminal',
    desktop_home ~ '/.config/gtk-3.0',
    desktop_home ~ '/.config/gtk-4.0',
    '/usr/local/libexec/qubes-hud'
] %}
{% set collision = namespace(found=false) %}

{% for path, markers in text_targets %}
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

{% for path, expected_mode in [
    (glow_helper, '0755'), (glow_pixels, '0644'),
    (bindings_helper, '0755'), (bindings_keyboard, '0644'),
    (logs_module, '0644'), (bindings_data, '0644'),
    (monitor_module, '0644'), (workspace_helper, '0755'),
    (bindings_desktop, '0644'), (dom0_logs_desktop, '0644'),
    (xen_logs_desktop, '0644')
] %}
  {% set target_lstat = salt['file.lstat'](path) %}
  {% if target_lstat|length > 0 and (
      target_lstat.get('st_uid') != 0 or target_lstat.get('st_gid') != 0
      or salt['file.get_mode'](path) != expected_mode) %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{% for path in terminal_text_targets + [logs_module, monitor_module] %}
  {% set target_lstat = salt['file.lstat'](path) %}
  {% if target_lstat|length > 0 and (
      target_lstat.get('st_uid') != 0 or target_lstat.get('st_gid') != 0
      or target_lstat.get('st_nlink') != 1
      or salt['file.get_mode'](path) != '0644') %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{# The native tmpfiles command may only touch private, unlinked user-owned
   runtime objects. Leave the directory absent when no login runtime exists. #}
{% for path in [user_runtime, terminal_runtime_root,
    terminal_runtime_root ~ '/dom0', terminal_runtime_root ~ '/xen'] %}
  {% set target_lstat = salt['file.lstat'](path) %}
  {% if target_lstat|length > 0 and (
      not salt['file.directory_exists'](path) or salt['file.is_link'](path)
      or target_lstat.get('st_uid') != desktop_uid
      or salt['file.get_mode'](path) != '0700') %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}
{% for view, desktop, title, wmclass, command in terminal_views %}
  {% set path = terminal_runtime_root ~ '/' ~ view ~ '.lock' %}
  {% set target_lstat = salt['file.lstat'](path) %}
  {% if target_lstat|length > 0 and (
      not salt['file.file_exists'](path) or salt['file.is_link'](path)
      or target_lstat.get('st_uid') != desktop_uid
      or target_lstat.get('st_nlink') != 1
      or salt['file.get_mode'](path) != '0600') %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{% for path in directory_targets %}
  {% set directory_lstat = salt['file.lstat'](path) %}
  {% if directory_lstat|length > 0
      and (not salt['file.directory_exists'](path) or salt['file.is_link'](path)) %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{# Existing generated content must pass its hash-and-inode manifest before any
   other HUD state is allowed to change the machine. #}
{% if cyan_icon_root_exists and (
    not cyan_icon_root_owned
    or not cyan_icon_manager_owned
    or (not cyan_icon_tree_valid and not cyan_icon_active_removal_valid)) %}
  {% set collision.found = true %}
{% endif %}
{% if cyan_icon_backup_exists and (
    not cyan_icon_backup_owned
    or not cyan_icon_manager_owned
    or (not cyan_icon_backup_valid and not cyan_icon_backup_removal_valid)) %}
  {% set collision.found = true %}
{% endif %}
{% if cyan_icon_removal_state_exists and not (
    cyan_icon_manager_owned and cyan_icon_removal_state_valid) %}
  {% set collision.found = true %}
{% endif %}
{% if tray_mode_manager_exists and not tray_mode_manager_owned %}
  {% set collision.found = true %}
{% endif %}
{% if tray_mode_record_exists and (
    not tray_mode_record_owned
    or not tray_mode_manager_owned
    or not tray_mode_state_valid) %}
  {% set collision.found = true %}
{% endif %}

{# Binary assets use a regular, owner-marked adjacent text record. #}
{% for target, owner_owned in [
    (hud_wallpaper, wallpaper_owner_owned)
] %}
  {% set target_lstat = salt['file.lstat'](target) %}
  {% if target_lstat|length > 0
      and (not salt['file.file_exists'](target)
           or salt['file.is_link'](target)
           or not owner_owned) %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{% if legacy_i3_owner_exists and not legacy_i3_owner_owned %}
  {% set collision.found = true %}
{% endif %}
{% if legacy_i3_exists and not legacy_i3_owned %}
  {% set collision.found = true %}
{% endif %}

{% set unmanaged_collision = collision.found %}

{% if transport == 'auto' %}
  {% set direct_route = salt['cmd.run']('/usr/sbin/ip -4 route show default', python_shell=false)|trim %}
  {% set transport = 'direct-dom0' if direct_route else 'qubes-updatevm' %}
{% endif %}

{% if not platform_ok %}
qubes_gui_hud_unsupported_platform:
  test.fail_without_changes:
    - name: This formula supports only Qubes OS 4.3 dom0 on x86_64.

{% elif not user_info %}
qubes_gui_hud_missing_desktop_user:
  test.fail_without_changes:
    - name: The configured desktop user '{{ desktop_user }}' does not exist.

{% elif transport not in ['direct-dom0', 'qubes-updatevm'] %}
qubes_gui_hud_invalid_transport:
  test.fail_without_changes:
    - name: The package transport must be auto, direct-dom0, or qubes-updatevm.

{% elif not official_i3_verified %}
qubes_gui_hud_official_i3_required:
  test.fail_without_changes:
    - name: >-
        Refusing to activate the HUD session without an intact, root-owned
        /usr/bin/i3 matching the installed i3 RPM. Apply qubes_gui.i3 first.

{% elif installed_i3_settings_evr != expected_i3_settings_evr %}
qubes_gui_hud_unsupported_i3_settings_build:
  test.fail_without_changes:
    - name: >-
        Refusing to install the HUD config: installed i3-settings-qubes is
        '{{ installed_i3_settings_evr }}', expected exactly
        '{{ expected_i3_settings_evr }}'.

{% elif unmanaged_collision %}
qubes_gui_hud_unmanaged_target_refused:
  test.fail_without_changes:
    - name: >-
        Refusing to overwrite a pre-existing HUD target that is not an owned
        regular file, or whose parent config path is not a real directory.
        See the collision-safety section in qubes_gui/hud/README.md.

{% else %}

{% if transport == 'direct-dom0' %}
qubes_gui_hud_runtime_packages_direct:
  cmd.run:
    - name: >-
        /usr/bin/dnf --setopt=reposdir=/etc/yum.repos.d --refresh
        --assumeyes install {{ runtime_packages|join(' ') }}
    - unless: /usr/bin/rpm --quiet -q {{ runtime_packages|join(' ') }}
{% else %}
qubes_gui_hud_runtime_packages_qubes_updatevm:
  pkg.installed:
    - pkgs:
{% for package in runtime_packages %}
      - {{ package }}
{% endfor %}
    - refresh: true
{% endif %}

qubes_gui_hud_official_i3_binary_present:
  cmd.run:
    - name: /usr/bin/test -x /usr/bin/i3
    - unless: /usr/bin/test -x /usr/bin/i3

qubes_gui_hud_official_i3_session_present:
  cmd.run:
    - name: /usr/bin/test -f /usr/share/xsessions/i3.desktop
    - unless: /usr/bin/test -f /usr/share/xsessions/i3.desktop

qubes_gui_hud_binary_directory:
  file.directory:
    - name: /usr/local/libexec/qubes-hud
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true

qubes_gui_hud_keyboard_helper:
  file.managed:
    - name: {{ keyboard_helper }}
    - source: salt://qubes_gui/hud/files/apply-keyboard-layout
    - check_cmd: /usr/bin/bash -n
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_binary_directory

qubes_gui_hud_cyan_icon_manager:
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
      - file: qubes_gui_hud_binary_directory
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_hud_runtime_packages_direct
{% else %}
      - pkg: qubes_gui_hud_runtime_packages_qubes_updatevm
{% endif %}

qubes_gui_hud_cyan_icon_theme:
  cmd.run:
    - name: {{ cyan_icon_manager }} install
    - unless: {{ cyan_icon_manager }} check
    - require:
      - file: qubes_gui_hud_cyan_icon_manager

qubes_gui_hud_cyan_icon_record:
  file.managed:
    - name: {{ cyan_icon_record }}
    - contents: |
        # {{ owner_marker }}.
        schema=1
        theme={{ cyan_icon_root }}
        manager={{ cyan_icon_manager }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: qubes_gui_hud_cyan_icon_theme

qubes_gui_hud_tray_mode_manager:
  file.managed:
    - name: {{ tray_mode_manager }}
    - source: salt://qubes_gui/hud/files/manage-trayicon-mode
    - check_cmd: >-
        /usr/bin/python3 -c 'import ast, sys;
        ast.parse(open(sys.argv[1], encoding="utf-8").read(),
        filename=sys.argv[1])'
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_binary_directory

qubes_gui_hud_tray_mode:
  cmd.run:
    - name: {{ tray_mode_manager }} install
    - unless: {{ tray_mode_manager }} check
    - require:
      - file: qubes_gui_hud_tray_mode_manager

qubes_gui_hud_window_shader:
  file.managed:
    - name: {{ window_shader }}
    - source: salt://qubes_gui/hud/files/window-glass.glsl
    - user: root
    - group: root
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_binary_directory

qubes_gui_hud_glow_pixels:
  file.managed:
    - name: {{ glow_pixels }}
    - source: salt://qubes_gui/hud/files/glow_pixels.py
    - check_cmd: >-
        /usr/bin/python3 -c 'import ast, sys;
        ast.parse(open(sys.argv[1], encoding="utf-8").read(),
        filename=sys.argv[1])'
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_binary_directory

qubes_gui_hud_glow_helper:
  file.managed:
    - name: {{ glow_helper }}
    - source: salt://qubes_gui/hud/files/hud-glow
    - check_cmd: >-
        /usr/bin/python3 -c 'import ast, sys;
        ast.parse(open(sys.argv[1], encoding="utf-8").read(),
        filename=sys.argv[1])'
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_binary_directory
      - file: qubes_gui_hud_glow_pixels

qubes_gui_hud_glow_runtime:
  cmd.run:
    - name: /usr/bin/python3 -B {{ glow_helper }} --check
    - unless: /usr/bin/python3 -B {{ glow_helper }} --check
    - require:
      - file: qubes_gui_hud_glow_pixels
      - file: qubes_gui_hud_glow_helper
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_hud_runtime_packages_direct
{% else %}
      - pkg: qubes_gui_hud_runtime_packages_qubes_updatevm
{% endif %}

qubes_gui_hud_bindings_keyboard:
  file.managed:
    - name: {{ bindings_keyboard }}
    - source: salt://qubes_gui/hud/files/bindings_keyboard.py
    - check_cmd: >-
        /usr/bin/python3 -c 'import ast, sys;
        ast.parse(open(sys.argv[1], encoding="utf-8").read(),
        filename=sys.argv[1])'
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_binary_directory

qubes_gui_hud_bindings_helper:
  file.managed:
    - name: {{ bindings_helper }}
    - source: salt://qubes_gui/hud/files/hud-bindings
    - check_cmd: >-
        /usr/bin/python3 -c 'import ast, sys;
        ast.parse(open(sys.argv[1], encoding="utf-8").read(),
        filename=sys.argv[1])'
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_binary_directory
      - file: qubes_gui_hud_bindings_keyboard
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_hud_runtime_packages_direct
{% else %}
      - pkg: qubes_gui_hud_runtime_packages_qubes_updatevm
{% endif %}

qubes_gui_hud_bindings_data:
  file.managed:
    - name: {{ bindings_data }}
    - source: salt://qubes_gui/hud/files/bindings.json
    - check_cmd: /usr/bin/python3 -B {{ bindings_helper }} --check --data
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_binary_directory
      - file: qubes_gui_hud_bindings_helper

qubes_gui_hud_bindings_runtime:
  cmd.run:
    - name: /usr/bin/python3 -B {{ bindings_helper }} --check
    - unless: /usr/bin/python3 -B {{ bindings_helper }} --check
    - require:
      - file: qubes_gui_hud_bindings_keyboard
      - file: qubes_gui_hud_bindings_helper
      - file: qubes_gui_hud_bindings_data
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_hud_runtime_packages_direct
{% else %}
      - pkg: qubes_gui_hud_runtime_packages_qubes_updatevm
{% endif %}

qubes_gui_hud_workspace_helper:
  file.managed:
    - name: {{ workspace_helper }}
    - source: salt://qubes_gui/hud/files/hud-workspace
    - check_cmd: >-
        /usr/bin/python3 -c 'import ast, sys;
        ast.parse(open(sys.argv[1], encoding="utf-8").read(),
        filename=sys.argv[1])'
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_binary_directory
      - cmd: qubes_gui_hud_bindings_runtime

qubes_gui_hud_workspace_runtime:
  cmd.run:
    - name: /usr/bin/python3 -B {{ workspace_helper }} --check
    - unless: /usr/bin/python3 -B {{ workspace_helper }} --check
    - require:
      - file: qubes_gui_hud_workspace_helper
      - cmd: qubes_gui_hud_bindings_runtime
      - cmd: qubes_gui_hud_official_i3_binary_present

qubes_gui_hud_bindings_desktop:
  file.managed:
    - name: {{ bindings_desktop }}
    - source: salt://qubes_gui/hud/files/qubes-hud-bindings.desktop
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: qubes_gui_hud_bindings_runtime

qubes_gui_hud_terminal_resources:
  file.managed:
    - name: {{ terminal_resources }}
    - source: salt://qubes_gui/hud/files/hud-terminal.Xresources
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_binary_directory

{% for view, target in [('dom0', dom0_logs_config), ('xen', xen_logs_config)] %}
qubes_gui_hud_{{ view }}_logs_config:
  file.managed:
    - name: {{ target }}
    - source: salt://qubes_gui/hud/files/hud-{{ view }}-logs.conf
    - check_cmd: /usr/bin/env HUD_LOG_STATE=/tmp /usr/sbin/rsyslogd -N1 -iNONE -f
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_binary_directory
{% endfor %}

qubes_gui_hud_terminal_tmpfiles:
  file.managed:
    - name: {{ terminal_tmpfiles }}
    - source: salt://qubes_gui/hud/files/hud-terminal-tmpfiles.conf
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: true

{% set terminal_runtime_check =
    '/usr/bin/xterm -version && '
    ~ '/usr/bin/env HUD_LOG_STATE=/tmp /usr/sbin/rsyslogd -N1 -iNONE -f ' ~ dom0_logs_config ~ ' && '
    ~ '/usr/bin/env HUD_LOG_STATE=/tmp /usr/sbin/rsyslogd -N1 -iNONE -f ' ~ xen_logs_config ~ ' && '
    ~ '/usr/bin/test -x /usr/bin/setpriv && '
    ~ '/usr/bin/test -x /usr/bin/setsid && '
    ~ '/usr/bin/test -x /usr/bin/flock && '
    ~ '/usr/bin/test -x /usr/bin/gtk-launch && '
    ~ '/usr/bin/test -x /usr/bin/systemd-tmpfiles && '
    ~ '/usr/bin/test -x /usr/bin/top && '
    ~ '/usr/bin/test -x /usr/sbin/xentop && '
    ~ '/usr/bin/test -x /usr/bin/systemd-cgtop' %}
qubes_gui_hud_terminal_runtime:
  cmd.run:
    - name: {{ terminal_runtime_check }}
    - unless: {{ terminal_runtime_check }}
    - require:
      - file: qubes_gui_hud_terminal_resources
      - file: qubes_gui_hud_dom0_logs_config
      - file: qubes_gui_hud_xen_logs_config
      - file: qubes_gui_hud_terminal_tmpfiles

{# A logged-in user's runtime tree is temporary. Native user-tmpfiles creates
   it at login as well; Salt neither starts a session nor removes active state. #}
{% set terminal_runtime_ready = [
    '/usr/bin/test -d ' ~ terminal_runtime_root ~ '/dom0',
    '/usr/bin/test -d ' ~ terminal_runtime_root ~ '/xen'
] %}
{% for view, desktop, title, wmclass, command in terminal_views %}
  {% set _ = terminal_runtime_ready.append('/usr/bin/test -f '
      ~ terminal_runtime_root ~ '/' ~ view ~ '.lock') %}
{% endfor %}
qubes_gui_hud_terminal_current_runtime:
  cmd.run:
    - name: /usr/bin/systemd-tmpfiles --user --create {{ terminal_tmpfiles }}
    - runas: {{ desktop_user }}
    - env:
        XDG_RUNTIME_DIR: /run/user/{{ desktop_uid }}
    - onlyif: /usr/bin/test -d /run/user/{{ desktop_uid }}
    - unless: {{ terminal_runtime_ready|join(' && ') }}
    - require:
      - cmd: qubes_gui_hud_terminal_runtime

{% for view, desktop, title, wmclass, command in terminal_views %}
qubes_gui_hud_{{ view }}{% if view in ['dom0', 'xen'] %}_logs{% endif %}_desktop:
  file.managed:
    - name: /usr/share/applications/qubes-hud-{{ desktop }}.desktop
    - source: salt://qubes_gui/hud/files/qubes-hud-terminal.desktop
    - template: jinja
    - context:
        desktop_uid: {{ desktop_uid }}
        view: {{ view }}
        wmclass: {{ wmclass }}
        title: {{ title }}
        command: {{ command }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: qubes_gui_hud_terminal_runtime
      - cmd: qubes_gui_hud_terminal_current_runtime
{% endfor %}

{# Delete only guarded legacy modules after both the bindings-only entrypoint
   and its native replacements validate. Running Python panes retain imports. #}
{% for module, path in [('logs', logs_module), ('monitor', monitor_module)] %}
qubes_gui_hud_remove_legacy_{{ module }}_module:
  file.absent:
    - name: {{ path }}
    - require:
      - cmd: qubes_gui_hud_bindings_runtime
      - cmd: qubes_gui_hud_workspace_runtime
{% for view, desktop, title, wmclass, command in terminal_views %}
      - file: qubes_gui_hud_{{ view }}{% if view in ['dom0', 'xen'] %}_logs{% endif %}_desktop
{% endfor %}
{% endfor %}

qubes_gui_hud_picom_config:
  file.managed:
    - name: {{ picom_config }}
    - source: salt://qubes_gui/hud/files/picom.conf
    - user: root
    - group: root
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_binary_directory
      - file: qubes_gui_hud_window_shader
      - cmd: qubes_gui_hud_glow_runtime
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_hud_runtime_packages_direct
{% else %}
      - pkg: qubes_gui_hud_runtime_packages_qubes_updatevm
{% endif %}

qubes_gui_hud_autostart_helper:
  file.managed:
    - name: {{ hud_autostart_helper }}
    - source: salt://qubes_gui/hud/files/hud-xdg-autostart
    - check_cmd: /usr/bin/bash -n
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_picom_config
      - cmd: qubes_gui_hud_glow_runtime
      - cmd: qubes_gui_hud_bindings_runtime
      - cmd: qubes_gui_hud_workspace_runtime
      - cmd: qubes_gui_hud_terminal_runtime
      - cmd: qubes_gui_hud_terminal_current_runtime
{% for view, desktop, title, wmclass, command in terminal_views %}
      - file: qubes_gui_hud_{{ view }}{% if view in ['dom0', 'xen'] %}_logs{% endif %}_desktop
{% endfor %}
      - file: qubes_gui_hud_remove_legacy_logs_module
      - file: qubes_gui_hud_remove_legacy_monitor_module

{% if legacy_picom_owned %}
qubes_gui_hud_remove_owned_legacy_picom_config:
  file.absent:
    - name: {{ legacy_picom_config }}
    - require:
      - file: qubes_gui_hud_picom_config
{% endif %}

{# A legacy HUD config proves file ownership, not who installed the RPM. #}
{% if not picom_preinstalled or picom_package_owner_owned %}
qubes_gui_hud_picom_package_owner:
  file.managed:
    - name: {{ picom_package_owner }}
    - contents: |
        # {{ owner_marker }}.
        package=picom
        removal-policy=remove-on-hud-rollback
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_binary_directory
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_hud_runtime_packages_direct
{% else %}
      - pkg: qubes_gui_hud_runtime_packages_qubes_updatevm
{% endif %}
{% endif %}

qubes_gui_hud_user_i3_directory:
  file.directory:
    - name: {{ desktop_home }}/.config/i3
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0755'
    - makedirs: true

qubes_gui_hud_user_rofi_directory:
  file.directory:
    - name: {{ desktop_home }}/.config/rofi
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0755'
    - makedirs: true

qubes_gui_hud_user_dunst_directory:
  file.directory:
    - name: {{ desktop_home }}/.config/dunst
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0755'
    - makedirs: true

qubes_gui_hud_user_xfce_terminal_directory:
  file.directory:
    - name: {{ desktop_home }}/.config/xfce4/terminal
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0755'
    - makedirs: true

qubes_gui_hud_user_gtk3_directory:
  file.directory:
    - name: {{ desktop_home }}/.config/gtk-3.0
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0755'
    - makedirs: true

qubes_gui_hud_user_gtk4_directory:
  file.directory:
    - name: {{ desktop_home }}/.config/gtk-4.0
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0755'
    - makedirs: true

qubes_gui_hud_i3_config:
  file.managed:
    - name: {{ user_i3_config }}
    - source: salt://qubes_gui/hud/files/i3-config
    - check_cmd: /usr/bin/i3 -C -c
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_user_i3_directory
      - file: qubes_gui_hud_keyboard_helper
      - file: qubes_gui_hud_autostart_helper
      - cmd: qubes_gui_hud_official_i3_binary_present

qubes_gui_hud_rofi_theme:
  file.managed:
    - name: {{ user_rofi_theme }}
    - source: salt://qubes_gui/hud/files/qubes-hud.rasi
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_user_rofi_directory
      - cmd: qubes_gui_hud_cyan_icon_theme
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_hud_runtime_packages_direct
{% else %}
      - pkg: qubes_gui_hud_runtime_packages_qubes_updatevm
{% endif %}

qubes_gui_hud_dunst_config:
  file.managed:
    - name: {{ user_dunst_config }}
    - source: salt://qubes_gui/hud/files/dunstrc
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_user_dunst_directory
      - cmd: qubes_gui_hud_cyan_icon_theme

qubes_gui_hud_xfce_terminal:
  file.managed:
    - name: {{ user_xfce_terminal }}
    - source: salt://qubes_gui/hud/files/terminalrc
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_user_xfce_terminal_directory

qubes_gui_hud_gtk2_settings:
  file.managed:
    - name: {{ user_gtk2_rc }}
    - source: salt://qubes_gui/hud/files/gtkrc-2.0
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - cmd: qubes_gui_hud_cyan_icon_theme

qubes_gui_hud_gtk3_css:
  file.managed:
    - name: {{ user_gtk3_css }}
    - source: salt://qubes_gui/hud/files/gtk-3.css
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_user_gtk3_directory
      - cmd: qubes_gui_hud_cyan_icon_theme

qubes_gui_hud_gtk3_settings:
  file.managed:
    - name: {{ user_gtk3_settings }}
    - source: salt://qubes_gui/hud/files/gtk-settings.ini
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_user_gtk3_directory
      - cmd: qubes_gui_hud_cyan_icon_theme

qubes_gui_hud_gtk4_css:
  file.managed:
    - name: {{ user_gtk4_css }}
    - source: salt://qubes_gui/hud/files/gtk-4.css
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_user_gtk4_directory
      - cmd: qubes_gui_hud_cyan_icon_theme

qubes_gui_hud_gtk4_settings:
  file.managed:
    - name: {{ user_gtk4_settings }}
    - source: salt://qubes_gui/hud/files/gtk-settings.ini
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_user_gtk4_directory
      - cmd: qubes_gui_hud_cyan_icon_theme

qubes_gui_hud_icon_settings_owner:
  file.managed:
    - name: {{ icon_settings_owner }}
    - contents: |
        # {{ owner_marker }}.
        schema=2
        gtk2={{ user_gtk2_rc }}
        gtk3={{ user_gtk3_settings }}
        gtk4={{ user_gtk4_settings }}
        theme={{ cyan_icon_root }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_binary_directory
      - file: qubes_gui_hud_gtk2_settings
      - file: qubes_gui_hud_gtk3_settings
      - file: qubes_gui_hud_gtk4_settings
      - file: qubes_gui_hud_cyan_icon_record

qubes_gui_hud_wallpaper:
  file.managed:
    - name: {{ hud_wallpaper }}
    - source: salt://qubes_gui/hud/files/qubes-hud-wallpaper.png
    - user: root
    - group: root
    - mode: '0644'

qubes_gui_hud_wallpaper_owner:
  file.managed:
    - name: {{ hud_wallpaper_owner }}
    - contents: |
        # {{ owner_marker }}.
        target={{ hud_wallpaper }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_wallpaper

qubes_gui_hud_xsession:
  file.managed:
    - name: {{ xsession_file }}
    - source: salt://qubes_gui/hud/files/qubes-hud.desktop
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: qubes_gui_hud_official_i3_binary_present
      - file: qubes_gui_hud_i3_config
      - file: qubes_gui_hud_rofi_theme
      - file: qubes_gui_hud_dunst_config
      - file: qubes_gui_hud_xfce_terminal
      - file: qubes_gui_hud_gtk2_settings
      - file: qubes_gui_hud_gtk3_css
      - file: qubes_gui_hud_gtk3_settings
      - file: qubes_gui_hud_gtk4_css
      - file: qubes_gui_hud_gtk4_settings
      - file: qubes_gui_hud_icon_settings_owner
      - file: qubes_gui_hud_cyan_icon_record
      - cmd: qubes_gui_hud_tray_mode
      - file: qubes_gui_hud_picom_config
      - file: qubes_gui_hud_autostart_helper
      - file: qubes_gui_hud_wallpaper
      - file: qubes_gui_hud_wallpaper_owner
      - file: qubes_gui_hud_bindings_desktop
      - file: qubes_gui_hud_dom0_logs_desktop
      - file: qubes_gui_hud_xen_logs_desktop

{# Keep the old restart pathname, but replace the custom machine code with
   an auditable launcher only after the official HUD session is installed.
   The record is written first so interrupted first installs remain owned. #}
qubes_gui_hud_i3_compat_owner:
  file.managed:
    - name: {{ legacy_i3_owner }}
    - contents: |
        # {{ owner_marker }}.
        target={{ legacy_i3_binary }}
        sha256={{ i3_compat_sha256 }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_xsession

qubes_gui_hud_i3_compat_launcher:
  file.managed:
    - name: {{ legacy_i3_binary }}
    - source: salt://qubes_gui/hud/files/i3-official-compat
    - check_cmd: >-
        /usr/bin/bash -c '/usr/bin/printf "%s  %s\n" "{{ i3_compat_sha256 }}"
        "$1" | /usr/bin/sha256sum --check --status -' --
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_i3_compat_owner
      - cmd: qubes_gui_hud_official_i3_session_present

qubes_gui_hud_lightdm_selection:
  file.managed:
    - name: {{ lightdm_config }}
    - contents: |
        # {{ owner_marker }}.
        [Seat:*]
        user-session=qubes-hud
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_xsession

qubes_gui_hud_accountsservice_session:
  cmd.run:
    - name: >-
        /usr/bin/busctl call org.freedesktop.Accounts
        /org/freedesktop/Accounts/User{{ user_info['uid'] }}
        org.freedesktop.Accounts.User SetXSession s qubes-hud
    - unless: >-
        /usr/bin/grep --quiet --fixed-strings XSession=qubes-hud
        /var/lib/AccountsService/users/{{ desktop_user }}
    - require:
      - file: qubes_gui_hud_lightdm_selection
      - file: qubes_gui_hud_xsession
      - file: qubes_gui_hud_i3_config

{% endif %}
