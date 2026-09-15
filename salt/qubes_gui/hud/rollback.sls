{# Return the next login to packaged i3 and remove only HUD-owned files. #}
{% set settings = salt['pillar.get']('qubes_gui:hud', {}) %}
{% set desktop_user = settings.get('desktop_user', 'user') %}
{% set desktop_group = settings.get('desktop_group', desktop_user) %}
{% set user_info = salt['user.info'](desktop_user) %}
{% set desktop_uid = user_info.get('uid', -1) if user_info else -1 %}
{% set desktop_gid = salt['file.group_to_gid'](desktop_group) %}
{% set desktop_home = user_info.get('home', '/home/' ~ desktop_user) if user_info else '/home/' ~ desktop_user %}
{% set owner_marker = 'Managed by qubes-os-customization Salt formula' %}
{% set hud_asset_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' %}
{% set legacy_i3_sha256 = 'fbd035f0e776acf755cffb021e8ef922b1da005ce4c54b3e54f3af545daf1f8f' %}
{% set i3_compat_sha256 = '5894d81ca085866185170577ec4a957e8094c60cca5f986d532399f15dac8402' %}
{% set release = grains.get('osrelease', '')|string %}
{% set architecture = grains.get('cpuarch', grains.get('osarch', ''))|string %}
{% set platform_ok = grains.get('virtual') == 'Qubes'
    and grains.get('virtual_subtype') == 'Xen Dom0'
    and (release == '4.3' or release.startswith('4.3.'))
    and architecture == 'x86_64' %}

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
{% set official_i3_lightdm_config = '/etc/lightdm/lightdm.conf.d/90-qubes-i3.conf' %}
{% set hud_lightdm_config = '/etc/lightdm/lightdm.conf.d/91-qubes-hud.conf' %}
{% set hud_xsession = '/usr/share/xsessions/qubes-hud.desktop' %}
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
{% set terminal_module = '/usr/local/libexec/qubes-hud/hud_terminal.py' %}
{% set workspace_helper = '/usr/local/libexec/qubes-hud/hud-workspace' %}
{% set night_helper = '/usr/local/libexec/qubes-hud/hud-night-light' %}
{% set output_module = '/usr/local/libexec/qubes-hud/hud_output.py' %}
{% set night_config_dir = desktop_home ~ '/.config/qubes-hud' %}
{% set night_config = night_config_dir ~ '/night-light.ini' %}
{% set night_desktop = '/usr/share/applications/qubes-hud-night-light.desktop' %}
{% set night_units = [
    ('apply', 'qubes-hud-night-light.service'),
    ('timer', 'qubes-hud-night-light.timer'),
    ('restore', 'qubes-hud-night-light-restore.service')
] %}
{% set night_root_targets = [(night_helper, '0755'),
    (output_module, '0644'), (night_desktop, '0644')] %}
{% for unit, filename in night_units %}
  {% set _ = night_root_targets.append(('/usr/lib/systemd/user/' ~ filename, '0644')) %}
{% endfor %}
{% set bindings_data = '/usr/local/libexec/qubes-hud/bindings.json' %}
{% set bindings_desktop = '/usr/share/applications/qubes-hud-bindings.desktop' %}
{% set dom0_logs_desktop = '/usr/share/applications/qubes-hud-dom0-logs.desktop' %}
{% set xen_logs_desktop = '/usr/share/applications/qubes-hud-xen-logs.desktop' %}
{% set terminal_resources = '/usr/local/libexec/qubes-hud/hud-terminal.Xresources' %}
{% set dom0_logs_config = '/usr/local/libexec/qubes-hud/hud-dom0-logs.conf' %}
{% set xen_logs_config = '/usr/local/libexec/qubes-hud/hud-xen-logs.conf' %}
{% set terminal_tmpfiles = '/usr/lib/user-tmpfiles.d/qubes-hud-terminals.conf' %}
{% set terminal_text_targets = [terminal_resources, dom0_logs_config,
    xen_logs_config, terminal_tmpfiles] %}
{% for desktop in ['dom0-logs', 'xen-logs', 'top', 'xentop', 'cgtop'] %}
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

{# Refuse every unexpected inode before any file.absent state can run. #}
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
{# An old custom i3 can still be running from its replaced/unlinked inode.
   Retain its restart pathname until that process exits or restarts officially.
   Unreadable process information conservatively prevents cleanup. #}
{% set legacy_i3_idle_check = "/usr/bin/python3 -c 'import os, pathlib, sys\n"
    ~ 'for entry in pathlib.Path("/proc").iterdir():\n'
    ~ '    if not entry.name.isdecimal(): continue\n'
    ~ '    try: target = os.readlink(entry.joinpath("exe"))\n'
    ~ '    except (FileNotFoundError, ProcessLookupError): continue\n'
    ~ '    except PermissionError: sys.exit(1)\n'
    ~ '    if target in (sys.argv[1], sys.argv[1] + " (deleted)"): sys.exit(1)\n'
    ~ "' " ~ legacy_i3_binary %}
{% set wallpaper_owner_regular = salt['file.file_exists'](hud_wallpaper_owner)
    and not salt['file.is_link'](hud_wallpaper_owner) %}
{% set wallpaper_owner_owned = owner_marker in salt['file.read'](hud_wallpaper_owner)
    if wallpaper_owner_regular else false %}
{% set picom_package_owner_regular = salt['file.file_exists'](picom_package_owner)
    and not salt['file.is_link'](picom_package_owner) %}
{% set picom_package_owner_owned = owner_marker in salt['file.read'](picom_package_owner)
    if picom_package_owner_regular else false %}
{% set icon_settings_owner_regular = salt['file.file_exists'](icon_settings_owner)
    and not salt['file.is_link'](icon_settings_owner) %}
{% set icon_settings_owner_owned = owner_marker in salt['file.read'](icon_settings_owner)
    if icon_settings_owner_regular else false %}
{% set cyan_icon_record_lstat = salt['file.lstat'](cyan_icon_record) %}
{% set cyan_icon_record_exists = cyan_icon_record_lstat|length > 0 %}
{% set cyan_icon_record_regular = salt['file.file_exists'](cyan_icon_record)
    and not salt['file.is_link'](cyan_icon_record) %}
{% set cyan_icon_record_owned = cyan_icon_record_regular
    and owner_marker in salt['file.read'](cyan_icon_record) %}
{% set cyan_icon_manager_lstat = salt['file.lstat'](cyan_icon_manager) %}
{% set cyan_icon_manager_exists = cyan_icon_manager_lstat|length > 0 %}
{% set cyan_icon_manager_regular = salt['file.file_exists'](cyan_icon_manager)
    and not salt['file.is_link'](cyan_icon_manager) %}
{% set cyan_icon_manager_owned = cyan_icon_manager_regular
    and salt['file.get_mode'](cyan_icon_manager) == '0755'
    and salt['file.lstat'](cyan_icon_manager).get('st_uid') == 0
    and salt['file.lstat'](cyan_icon_manager).get('st_gid') == 0
    and hud_asset_marker in salt['file.read'](cyan_icon_manager) %}
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
{% set cyan_icon_tree_valid = salt['cmd.retcode'](
    cyan_icon_manager ~ ' validate-removal', python_shell=false,
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
{% set gtk2_settings_regular = salt['file.file_exists'](user_gtk2_rc)
    and not salt['file.is_link'](user_gtk2_rc) %}
{% set gtk2_settings_owned = (owner_marker in salt['file.read'](user_gtk2_rc)
    or hud_asset_marker in salt['file.read'](user_gtk2_rc))
    if gtk2_settings_regular else false %}
{% set gtk3_settings_regular = salt['file.file_exists'](user_gtk3_settings)
    and not salt['file.is_link'](user_gtk3_settings) %}
{% set gtk3_settings_owned = (owner_marker in salt['file.read'](user_gtk3_settings)
    or hud_asset_marker in salt['file.read'](user_gtk3_settings))
    if gtk3_settings_regular else false %}
{% set gtk4_settings_regular = salt['file.file_exists'](user_gtk4_settings)
    and not salt['file.is_link'](user_gtk4_settings) %}
{% set gtk4_settings_owned = (owner_marker in salt['file.read'](user_gtk4_settings)
    or hud_asset_marker in salt['file.read'](user_gtk4_settings))
    if gtk4_settings_regular else false %}
{% set legacy_picom_regular = salt['file.file_exists'](legacy_picom_config)
    and not salt['file.is_link'](legacy_picom_config) %}
{% set legacy_picom_contents = salt['file.read'](legacy_picom_config)
    if legacy_picom_regular else '' %}
{% set legacy_picom_owned = owner_marker in legacy_picom_contents
    or hud_asset_marker in legacy_picom_contents %}

{% set text_targets = [
    (user_i3_config, [owner_marker]),
    (user_rofi_theme, [owner_marker, hud_asset_marker]),
    (user_dunst_config, [owner_marker, hud_asset_marker]),
    (user_xfce_terminal, [owner_marker, hud_asset_marker]),
    (user_gtk3_css, [owner_marker, hud_asset_marker]),
    (user_gtk4_css, [owner_marker, hud_asset_marker]),
    (official_i3_lightdm_config, [owner_marker]),
    (hud_lightdm_config, [owner_marker]),
    (hud_xsession, [owner_marker]),
    (keyboard_helper, [owner_marker]),
    (hud_autostart_helper, [owner_marker]),
    (glow_helper, [hud_asset_marker]),
    (glow_pixels, [hud_asset_marker]),
    (bindings_helper, [hud_asset_marker]),
    (bindings_keyboard, [hud_asset_marker]),
    (logs_module, [hud_asset_marker]),
    (monitor_module, [hud_asset_marker]),
    (terminal_module, [hud_asset_marker]),
    (workspace_helper, [hud_asset_marker]),
    (bindings_data, [hud_asset_marker]),
    (bindings_desktop, [hud_asset_marker]),
    (dom0_logs_desktop, [hud_asset_marker]),
    (xen_logs_desktop, [hud_asset_marker]),
    (picom_config, [owner_marker, hud_asset_marker]),
    (window_shader, [hud_asset_marker]),
    (picom_package_owner, [owner_marker]),
    (icon_settings_owner, [owner_marker]),
    (tray_mode_manager, [hud_asset_marker]),
    (tray_mode_record, [hud_asset_marker]),
    (hud_wallpaper_owner, [owner_marker])
] %}
{% for path in terminal_text_targets %}
  {% set _ = text_targets.append((path, [hud_asset_marker])) %}
{% endfor %}
{% for path, mode in night_root_targets + [(night_config, '0644')] %}
  {% set _ = text_targets.append((path, [hud_asset_marker])) %}
{% endfor %}
{# Pre-icon-test installs have no record, so preserve pre-existing GTK settings. #}
{% if icon_settings_owner_owned %}
  {% set text_targets = text_targets + [
      (user_gtk2_rc, [owner_marker, hud_asset_marker]),
      (user_gtk3_settings, [owner_marker, hud_asset_marker]),
      (user_gtk4_settings, [owner_marker, hud_asset_marker])
  ] %}
{% endif %}
{% set directory_targets = [
    '/usr',
    '/usr/lib',
    '/usr/lib/user-tmpfiles.d',
    '/usr/lib/systemd',
    '/usr/lib/systemd/user',
    '/usr/share',
    '/usr/share/icons',
    '/usr/share/applications',
    desktop_home,
    desktop_home ~ '/.config',
    night_config_dir,
    desktop_home ~ '/.config/i3',
    desktop_home ~ '/.config/rofi',
    desktop_home ~ '/.config/dunst',
    desktop_home ~ '/.config/xfce4',
    desktop_home ~ '/.config/xfce4/terminal',
    desktop_home ~ '/.config/gtk-3.0',
    desktop_home ~ '/.config/gtk-4.0',
    '/usr/local/libexec/qubes-hud'
] %}
{% if cyan_icon_root_owned %}
  {% set directory_targets = directory_targets + [cyan_icon_root] %}
{% endif %}
{% if cyan_icon_backup_owned %}
  {% set directory_targets = directory_targets + [cyan_icon_backup] %}
{% endif %}
{% set collision = namespace(found=false) %}

{# A current install record makes every generated tree or resumable removal
   state prove ownership. With no record (an older install or a partial first
   run), unknown paths are preserved and only independently proven assets are
   considered. #}
{% if cyan_icon_record_exists and not cyan_icon_record_owned %}
  {% set collision.found = true %}
{% endif %}
{% if cyan_icon_record_owned and (
    (cyan_icon_manager_exists and not cyan_icon_manager_owned)
    or ((cyan_icon_root_exists or cyan_icon_backup_exists)
        and not cyan_icon_manager_owned)
    or (cyan_icon_root_exists and not (
        cyan_icon_tree_valid or cyan_icon_active_removal_valid))
    or (cyan_icon_backup_exists and not (
        cyan_icon_backup_valid or cyan_icon_backup_removal_valid))) %}
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

{% for path in terminal_text_targets + [logs_module, monitor_module, terminal_module] %}
  {% set target_lstat = salt['file.lstat'](path) %}
  {% if target_lstat|length > 0 and (
      target_lstat.get('st_uid') != 0 or target_lstat.get('st_gid') != 0
      or target_lstat.get('st_nlink') != 1
      or salt['file.get_mode'](path) != '0644') %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{% for path, expected_mode in night_root_targets %}
  {% set target_lstat = salt['file.lstat'](path) %}
  {% if target_lstat|length > 0 and (
      target_lstat.get('st_uid') != 0 or target_lstat.get('st_gid') != 0
      or target_lstat.get('st_nlink') != 1
      or salt['file.get_mode'](path) != expected_mode) %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}
{% for path, expected_mode in [(night_config_dir, '0700'), (night_config, '0644')] %}
  {% set target_lstat = salt['file.lstat'](path) %}
  {% if target_lstat|length > 0 and (
      target_lstat.get('st_uid') != desktop_uid
      or target_lstat.get('st_gid') != desktop_gid
      or salt['file.get_mode'](path) != expected_mode
      or (path == night_config and target_lstat.get('st_nlink') != 1)) %}
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
{% set qube_preset = namespace(present=false) %}
{% for path in ['/etc/qubes-hud/qube-workspace.json', '/etc/qubes-hud/qube-workspace.i3',
    '/usr/share/applications/qubes-hud-qube-workspace.desktop'] %}
  {% if salt['file.lstat'](path) %}
    {% set qube_preset.present = true %}
  {% endif %}
{% endfor %}

{% if not platform_ok %}
qubes_gui_hud_rollback_unsupported_platform:
  test.fail_without_changes:
    - name: This rollback supports only Qubes OS 4.3 dom0 on x86_64.

{% elif not user_info %}
qubes_gui_hud_rollback_missing_desktop_user:
  test.fail_without_changes:
    - name: The configured desktop user '{{ desktop_user }}' does not exist.

{% elif not official_i3_verified %}
qubes_gui_hud_rollback_official_i3_required:
  test.fail_without_changes:
    - name: >-
        Refusing rollback without an intact, root-owned /usr/bin/i3 matching
        the installed i3 RPM. Restore the official i3 package first.

{% elif qube_preset.present %}
qubes_gui_hud_rollback_qube_preset_active:
  test.fail_without_changes:
    - name: >-
        First apply qubes_gui.hud.qube-rollback to the configured guest and
        then dom0 with its qube_workspace pillar. This removes guest autostart,
        boot startup and the optional launcher before its HUD helper is removed.

{% elif unmanaged_collision %}
qubes_gui_hud_rollback_unmanaged_target_refused:
  test.fail_without_changes:
    - name: >-
        Refusing rollback because a target is not an owned regular file, or a
        parent config path is not a real directory. No files were changed.

{% else %}

include:
  - qubes_gui.hud.font-rollback

qubes_gui_hud_rollback_official_i3_binary:
  cmd.run:
    - name: /usr/bin/test -x /usr/bin/i3
    - unless: /usr/bin/test -x /usr/bin/i3

qubes_gui_hud_rollback_official_i3_session:
  file.exists:
    - name: /usr/share/xsessions/i3.desktop

qubes_gui_hud_rollback_user_i3_directory:
  file.directory:
    - name: {{ desktop_home }}/.config/i3
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0755'
    - makedirs: true

qubes_gui_hud_rollback_i3_config:
  file.managed:
    - name: {{ user_i3_config }}
    - source: salt://qubes_gui/i3/files/i3-user-config
    - check_cmd: /usr/bin/i3 -C -c
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_rollback_user_i3_directory
      - cmd: qubes_gui_hud_rollback_official_i3_binary

qubes_gui_hud_rollback_official_i3_lightdm_selection:
  file.managed:
    - name: {{ official_i3_lightdm_config }}
    - contents: |
        # {{ owner_marker }}.
        [Seat:*]
        user-session=i3
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_rollback_official_i3_session

qubes_gui_hud_rollback_remove_lightdm_selection:
  file.absent:
    - name: {{ hud_lightdm_config }}

qubes_gui_hud_rollback_accountsservice_session:
  cmd.run:
    - name: >-
        /usr/bin/busctl call org.freedesktop.Accounts
        /org/freedesktop/Accounts/User{{ user_info['uid'] }}
        org.freedesktop.Accounts.User SetXSession s i3
    - unless: >-
        /usr/bin/grep --quiet --fixed-strings XSession=i3
        /var/lib/AccountsService/users/{{ desktop_user }}
    - require:
      - sls: qubes_gui.hud.font-rollback
      - file: qubes_gui_hud_rollback_i3_config
      - file: qubes_gui_hud_rollback_official_i3_lightdm_selection
      - file: qubes_gui_hud_rollback_remove_lightdm_selection
      - file: qubes_gui_hud_rollback_official_i3_session

qubes_gui_hud_rollback_remove_xsession:
  file.absent:
    - name: {{ hud_xsession }}
    - require:
      - cmd: qubes_gui_hud_rollback_accountsservice_session

qubes_gui_hud_rollback_remove_rofi_theme:
  file.absent:
    - name: {{ user_rofi_theme }}

qubes_gui_hud_rollback_remove_dunst_config:
  file.absent:
    - name: {{ user_dunst_config }}

qubes_gui_hud_rollback_remove_xfce_terminal:
  file.absent:
    - name: {{ user_xfce_terminal }}

{% if icon_settings_owner_owned or gtk2_settings_owned %}
qubes_gui_hud_rollback_remove_gtk2_settings:
  file.absent:
    - name: {{ user_gtk2_rc }}
{% endif %}

qubes_gui_hud_rollback_remove_gtk3_css:
  file.absent:
    - name: {{ user_gtk3_css }}

{% if icon_settings_owner_owned or gtk3_settings_owned %}
qubes_gui_hud_rollback_remove_gtk3_settings:
  file.absent:
    - name: {{ user_gtk3_settings }}
{% endif %}

qubes_gui_hud_rollback_remove_gtk4_css:
  file.absent:
    - name: {{ user_gtk4_css }}

{% if icon_settings_owner_owned or gtk4_settings_owned %}
qubes_gui_hud_rollback_remove_gtk4_settings:
  file.absent:
    - name: {{ user_gtk4_settings }}
{% endif %}

{% if icon_settings_owner_owned %}
qubes_gui_hud_rollback_remove_icon_settings_owner:
  file.absent:
    - name: {{ icon_settings_owner }}
    - require:
      - file: qubes_gui_hud_rollback_remove_gtk2_settings
      - file: qubes_gui_hud_rollback_remove_gtk3_settings
      - file: qubes_gui_hud_rollback_remove_gtk4_settings
{% endif %}

{% if cyan_icon_removal_state_valid %}
qubes_gui_hud_rollback_recover_cyan_icon_removal:
  cmd.run:
{% if cyan_icon_active_removal_valid %}
    - name: {{ cyan_icon_manager }} recover-removal
{% else %}
    - name: >-
        {{ cyan_icon_manager }} recover-removal --target {{ cyan_icon_backup }}
{% endif %}
{% endif %}

{% if cyan_icon_tree_valid %}
qubes_gui_hud_rollback_remove_cyan_icon_theme:
  cmd.run:
    - name: {{ cyan_icon_manager }} remove
    - require:
      - file: qubes_gui_hud_rollback_remove_rofi_theme
      - file: qubes_gui_hud_rollback_remove_dunst_config
      - file: qubes_gui_hud_rollback_remove_gtk3_css
      - file: qubes_gui_hud_rollback_remove_gtk4_css
{% if icon_settings_owner_owned or gtk2_settings_owned %}
      - file: qubes_gui_hud_rollback_remove_gtk2_settings
{% endif %}
{% if icon_settings_owner_owned or gtk3_settings_owned %}
      - file: qubes_gui_hud_rollback_remove_gtk3_settings
{% endif %}
{% if icon_settings_owner_owned or gtk4_settings_owned %}
      - file: qubes_gui_hud_rollback_remove_gtk4_settings
{% endif %}
{% if cyan_icon_removal_state_valid %}
      - cmd: qubes_gui_hud_rollback_recover_cyan_icon_removal
{% endif %}
{% endif %}

{% if cyan_icon_backup_valid %}
qubes_gui_hud_rollback_remove_cyan_icon_backup:
  cmd.run:
    - name: {{ cyan_icon_manager }} remove --target {{ cyan_icon_backup }}
{% if cyan_icon_removal_state_valid %}
    - require:
      - cmd: qubes_gui_hud_rollback_recover_cyan_icon_removal
{% endif %}
{% endif %}

{% if cyan_icon_manager_owned %}
qubes_gui_hud_rollback_remove_cyan_icon_manager:
  file.absent:
    - name: {{ cyan_icon_manager }}
{% if cyan_icon_tree_valid or cyan_icon_backup_valid
    or cyan_icon_removal_state_valid %}
    - require:
{% if cyan_icon_tree_valid %}
      - cmd: qubes_gui_hud_rollback_remove_cyan_icon_theme
{% endif %}
{% if cyan_icon_backup_valid %}
      - cmd: qubes_gui_hud_rollback_remove_cyan_icon_backup
{% endif %}
{% if cyan_icon_removal_state_valid %}
      - cmd: qubes_gui_hud_rollback_recover_cyan_icon_removal
{% endif %}
{% endif %}
{% endif %}

{% if cyan_icon_record_owned %}
qubes_gui_hud_rollback_remove_cyan_icon_record:
  file.absent:
    - name: {{ cyan_icon_record }}
{% if cyan_icon_tree_valid or cyan_icon_backup_valid
    or cyan_icon_manager_owned %}
    - require:
{% if cyan_icon_tree_valid %}
      - cmd: qubes_gui_hud_rollback_remove_cyan_icon_theme
{% endif %}
{% if cyan_icon_manager_owned %}
      - file: qubes_gui_hud_rollback_remove_cyan_icon_manager
{% endif %}
{% if cyan_icon_backup_valid %}
      - cmd: qubes_gui_hud_rollback_remove_cyan_icon_backup
{% endif %}
{% endif %}
{% endif %}

{% if tray_mode_record_owned %}
qubes_gui_hud_rollback_restore_tray_mode:
  cmd.run:
    - name: {{ tray_mode_manager }} remove

qubes_gui_hud_rollback_remove_tray_mode_manager:
  file.absent:
    - name: {{ tray_mode_manager }}
    - require:
      - cmd: qubes_gui_hud_rollback_restore_tray_mode
{% elif tray_mode_manager_owned %}
qubes_gui_hud_rollback_remove_tray_mode_manager:
  file.absent:
    - name: {{ tray_mode_manager }}
{% endif %}

qubes_gui_hud_rollback_remove_wallpaper:
  file.absent:
    - name: {{ hud_wallpaper }}

qubes_gui_hud_rollback_remove_wallpaper_owner:
  file.absent:
    - name: {{ hud_wallpaper_owner }}
    - require:
      - file: qubes_gui_hud_rollback_remove_wallpaper

{% if legacy_i3_exists %}
qubes_gui_hud_rollback_remove_idle_legacy_i3_binary:
  file.absent:
    - name: {{ legacy_i3_binary }}
    - onlyif: {{ legacy_i3_idle_check|tojson }}
    - require:
      - cmd: qubes_gui_hud_rollback_accountsservice_session
      - file: qubes_gui_hud_rollback_remove_xsession
{% endif %}

{% if legacy_i3_owner_exists %}
qubes_gui_hud_rollback_remove_legacy_i3_owner:
  file.absent:
    - name: {{ legacy_i3_owner }}
    - onlyif: >-
        /usr/bin/python3 -c 'import os, sys;
        sys.exit(os.path.lexists(sys.argv[1]))' {{ legacy_i3_binary }}
    - require:
      - cmd: qubes_gui_hud_rollback_accountsservice_session
{% if legacy_i3_exists %}
      - file: qubes_gui_hud_rollback_remove_idle_legacy_i3_binary
{% endif %}
{% endif %}

qubes_gui_hud_rollback_remove_keyboard_helper:
  file.absent:
    - name: {{ keyboard_helper }}
    - require:
      - cmd: qubes_gui_hud_rollback_accountsservice_session

qubes_gui_hud_rollback_remove_autostart_helper:
  file.absent:
    - name: {{ hud_autostart_helper }}
    - require:
      - cmd: qubes_gui_hud_rollback_accountsservice_session

{# The user manager retains the display environment from HUD startup. Restore
   saved output transforms before removing their controller or native units.
   With no user bus there is no session service to stop. Keep the user directory
   and runtime state; only its marked preferences file is removed below. #}
qubes_gui_hud_rollback_stop_night_light:
  cmd.run:
    - name: /usr/bin/python3 -B {{ night_helper }} --stop
    - runas: {{ desktop_user }}
    - env:
        XDG_RUNTIME_DIR: /run/user/{{ desktop_uid }}
        DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/{{ desktop_uid }}/bus
    - onlyif:
      - /usr/bin/test -S /run/user/{{ desktop_uid }}/bus
      - /usr/bin/test -f {{ night_helper }}
    - require:
      - file: qubes_gui_hud_rollback_remove_autostart_helper

{% for asset, path in [('night_light_desktop', night_desktop),
    ('night_light_config', night_config)] %}
qubes_gui_hud_rollback_remove_{{ asset }}:
  file.absent:
    - name: {{ path }}
    - require:
      - cmd: qubes_gui_hud_rollback_stop_night_light
{% endfor %}

{% for unit, filename in night_units %}
qubes_gui_hud_rollback_remove_night_light_{{ unit }}_unit:
  file.absent:
    - name: /usr/lib/systemd/user/{{ filename }}
    - require:
      - cmd: qubes_gui_hud_rollback_stop_night_light
{% endfor %}

qubes_gui_hud_rollback_reload_night_light_units:
  cmd.run:
    - name: /usr/bin/systemctl --user daemon-reload
    - runas: {{ desktop_user }}
    - env:
        XDG_RUNTIME_DIR: /run/user/{{ desktop_uid }}
        DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/{{ desktop_uid }}/bus
    - onlyif: /usr/bin/test -S /run/user/{{ desktop_uid }}/bus
    - onchanges:
{% for unit, filename in night_units %}
      - file: qubes_gui_hud_rollback_remove_night_light_{{ unit }}_unit
{% endfor %}

qubes_gui_hud_rollback_remove_night_light_helper:
  file.absent:
    - name: {{ night_helper }}
    - require:
      - cmd: qubes_gui_hud_rollback_stop_night_light
      - cmd: qubes_gui_hud_rollback_reload_night_light_units
      - file: qubes_gui_hud_rollback_remove_night_light_desktop
      - file: qubes_gui_hud_rollback_remove_night_light_config

qubes_gui_hud_rollback_remove_output_module:
  file.absent:
    - name: {{ output_module }}
    - require:
      - file: qubes_gui_hud_rollback_remove_night_light_helper

qubes_gui_hud_rollback_remove_workspace_helper:
  file.absent:
    - name: {{ workspace_helper }}
    - require:
      - file: qubes_gui_hud_rollback_remove_autostart_helper

qubes_gui_hud_rollback_remove_bindings_desktop:
  file.absent:
    - name: {{ bindings_desktop }}
    - require:
      - file: qubes_gui_hud_rollback_remove_autostart_helper

qubes_gui_hud_rollback_remove_dom0_logs_desktop:
  file.absent:
    - name: {{ dom0_logs_desktop }}
    - require:
      - file: qubes_gui_hud_rollback_remove_autostart_helper

qubes_gui_hud_rollback_remove_xen_logs_desktop:
  file.absent:
    - name: {{ xen_logs_desktop }}
    - require:
      - file: qubes_gui_hud_rollback_remove_autostart_helper

{% for view in ['top', 'xentop', 'cgtop'] %}
qubes_gui_hud_rollback_remove_{{ view }}_desktop:
  file.absent:
    - name: /usr/share/applications/qubes-hud-{{ view }}.desktop
    - require:
      - file: qubes_gui_hud_rollback_remove_autostart_helper
      - file: qubes_gui_hud_rollback_remove_workspace_helper
{% endfor %}

{# Active terminals own their runtime data until exit/logout. Removing only
   managed launch/config files leaves current desktop processes undisturbed. #}
{% for asset, path in [('terminal_resources', terminal_resources),
    ('dom0_logs_config', dom0_logs_config), ('xen_logs_config', xen_logs_config),
    ('terminal_tmpfiles', terminal_tmpfiles)] %}
qubes_gui_hud_rollback_remove_{{ asset }}:
  file.absent:
    - name: {{ path }}
    - require:
      - file: qubes_gui_hud_rollback_remove_autostart_helper
      - file: qubes_gui_hud_rollback_remove_workspace_helper
      - file: qubes_gui_hud_rollback_remove_dom0_logs_desktop
      - file: qubes_gui_hud_rollback_remove_xen_logs_desktop
{% for view in ['top', 'xentop', 'cgtop'] %}
      - file: qubes_gui_hud_rollback_remove_{{ view }}_desktop
{% endfor %}
{% endfor %}

qubes_gui_hud_rollback_remove_bindings_helper:
  file.absent:
    - name: {{ bindings_helper }}
    - require:
      - file: qubes_gui_hud_rollback_remove_bindings_desktop
      - file: qubes_gui_hud_rollback_remove_dom0_logs_desktop
      - file: qubes_gui_hud_rollback_remove_xen_logs_desktop
      - file: qubes_gui_hud_rollback_remove_workspace_helper
{% for view in ['top', 'xentop', 'cgtop'] %}
      - file: qubes_gui_hud_rollback_remove_{{ view }}_desktop
{% endfor %}

qubes_gui_hud_rollback_remove_terminal_module:
  file.absent:
    - name: {{ terminal_module }}
    - require:
      - file: qubes_gui_hud_rollback_remove_bindings_helper

qubes_gui_hud_rollback_remove_monitor_module:
  file.absent:
    - name: {{ monitor_module }}
    - require:
      - file: qubes_gui_hud_rollback_remove_bindings_helper

qubes_gui_hud_rollback_remove_logs_module:
  file.absent:
    - name: {{ logs_module }}
    - require:
      - file: qubes_gui_hud_rollback_remove_bindings_helper

qubes_gui_hud_rollback_remove_bindings_keyboard:
  file.absent:
    - name: {{ bindings_keyboard }}
    - require:
      - file: qubes_gui_hud_rollback_remove_bindings_helper

qubes_gui_hud_rollback_remove_bindings_data:
  file.absent:
    - name: {{ bindings_data }}
    - require:
      - file: qubes_gui_hud_rollback_remove_bindings_helper

qubes_gui_hud_rollback_remove_glow_helper:
  file.absent:
    - name: {{ glow_helper }}
    - require:
      - file: qubes_gui_hud_rollback_remove_autostart_helper

qubes_gui_hud_rollback_remove_glow_pixels:
  file.absent:
    - name: {{ glow_pixels }}
    - require:
      - file: qubes_gui_hud_rollback_remove_glow_helper

qubes_gui_hud_rollback_remove_picom_config:
  file.absent:
    - name: {{ picom_config }}
    - require:
      - cmd: qubes_gui_hud_rollback_accountsservice_session

qubes_gui_hud_rollback_remove_window_shader:
  file.absent:
    - name: {{ window_shader }}
    - require:
      - file: qubes_gui_hud_rollback_remove_picom_config

{% if legacy_picom_owned %}
qubes_gui_hud_rollback_remove_owned_legacy_picom_config:
  file.absent:
    - name: {{ legacy_picom_config }}
    - require:
      - cmd: qubes_gui_hud_rollback_accountsservice_session
{% endif %}

{% if picom_package_owner_owned %}
qubes_gui_hud_rollback_remove_owned_picom_package:
  pkg.removed:
    - name: picom
    - require:
      - file: qubes_gui_hud_rollback_remove_autostart_helper
      - file: qubes_gui_hud_rollback_remove_picom_config
      - file: qubes_gui_hud_rollback_remove_window_shader
      - file: qubes_gui_hud_rollback_remove_glow_pixels
{% if legacy_picom_owned %}
      - file: qubes_gui_hud_rollback_remove_owned_legacy_picom_config
{% endif %}

qubes_gui_hud_rollback_remove_picom_package_owner:
  file.absent:
    - name: {{ picom_package_owner }}
    - require:
      - pkg: qubes_gui_hud_rollback_remove_owned_picom_package
{% endif %}

{% endif %}
