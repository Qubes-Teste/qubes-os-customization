{# Return the next login to packaged i3 and remove only HUD-owned files. #}
{% set settings = salt['pillar.get']('qubes_gui:hud', {}) %}
{% set desktop_user = settings.get('desktop_user', 'user') %}
{% set desktop_group = settings.get('desktop_group', desktop_user) %}
{% set user_info = salt['user.info'](desktop_user) %}
{% set desktop_home = user_info.get('home', '/home/' ~ desktop_user) if user_info else '/home/' ~ desktop_user %}
{% set owner_marker = 'Managed by qubes-os-customization Salt formula' %}
{% set hud_asset_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' %}
{% set release = grains.get('osrelease', '')|string %}
{% set architecture = grains.get('cpuarch', grains.get('osarch', ''))|string %}
{% set platform_ok = grains.get('virtual') == 'Qubes'
    and grains.get('virtual_subtype') == 'Xen Dom0'
    and (release == '4.3' or release.startswith('4.3.'))
    and architecture == 'x86_64' %}

{% set user_i3_config = desktop_home ~ '/.config/i3/config' %}
{% set user_rofi_theme = desktop_home ~ '/.config/rofi/config.rasi' %}
{% set user_dunst_config = desktop_home ~ '/.config/dunst/dunstrc' %}
{% set user_xfce_terminal = desktop_home ~ '/.config/xfce4/terminal/terminalrc' %}
{% set user_gtk3_css = desktop_home ~ '/.config/gtk-3.0/gtk.css' %}
{% set user_gtk4_css = desktop_home ~ '/.config/gtk-4.0/gtk.css' %}
{% set official_i3_lightdm_config = '/etc/lightdm/lightdm.conf.d/90-qubes-i3.conf' %}
{% set hud_lightdm_config = '/etc/lightdm/lightdm.conf.d/91-qubes-hud.conf' %}
{% set hud_xsession = '/usr/share/xsessions/qubes-hud.desktop' %}
{% set hud_binary = '/usr/local/libexec/qubes-hud/i3' %}
{% set hud_binary_owner = '/usr/local/libexec/qubes-hud/i3.owner' %}
{% set keyboard_helper = '/usr/local/libexec/qubes-hud/apply-keyboard-layout' %}
{% set hud_autostart_helper = '/usr/local/libexec/qubes-hud/hud-xdg-autostart' %}
{% set picom_config = '/usr/local/libexec/qubes-hud/picom.conf' %}
{% set window_shader = '/usr/local/libexec/qubes-hud/window-glass.glsl' %}
{% set legacy_picom_config = '/etc/xdg/picom.conf' %}
{% set picom_package_owner = '/usr/local/libexec/qubes-hud/picom.package-owner' %}
{% set hud_wallpaper = '/usr/share/backgrounds/qubes-hud.png' %}
{% set hud_wallpaper_owner = '/usr/share/backgrounds/qubes-hud.png.owner' %}

{# Refuse every unexpected inode before any file.absent state can run. #}
{% set binary_owner_regular = salt['file.file_exists'](hud_binary_owner)
    and not salt['file.is_link'](hud_binary_owner) %}
{% set binary_owner_owned = owner_marker in salt['file.read'](hud_binary_owner)
    if binary_owner_regular else false %}
{% set wallpaper_owner_regular = salt['file.file_exists'](hud_wallpaper_owner)
    and not salt['file.is_link'](hud_wallpaper_owner) %}
{% set wallpaper_owner_owned = owner_marker in salt['file.read'](hud_wallpaper_owner)
    if wallpaper_owner_regular else false %}
{% set picom_package_owner_regular = salt['file.file_exists'](picom_package_owner)
    and not salt['file.is_link'](picom_package_owner) %}
{% set picom_package_owner_owned = owner_marker in salt['file.read'](picom_package_owner)
    if picom_package_owner_regular else false %}
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
    (hud_binary_owner, [owner_marker]),
    (keyboard_helper, [owner_marker]),
    (hud_autostart_helper, [owner_marker]),
    (picom_config, [owner_marker, hud_asset_marker]),
    (window_shader, [hud_asset_marker]),
    (picom_package_owner, [owner_marker]),
    (hud_wallpaper_owner, [owner_marker])
] %}
{% set directory_targets = [
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

{% for path in directory_targets %}
  {% set directory_lstat = salt['file.lstat'](path) %}
  {% if directory_lstat|length > 0
      and (not salt['file.directory_exists'](path) or salt['file.is_link'](path)) %}
    {% set collision.found = true %}
  {% endif %}
{% endfor %}

{% for target, owner_owned in [
    (hud_binary, binary_owner_owned),
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

{% set unmanaged_collision = collision.found %}

{% if not platform_ok %}
qubes_gui_hud_rollback_unsupported_platform:
  test.fail_without_changes:
    - name: This rollback supports only Qubes OS 4.3 dom0 on x86_64.

{% elif not user_info %}
qubes_gui_hud_rollback_missing_desktop_user:
  test.fail_without_changes:
    - name: The configured desktop user '{{ desktop_user }}' does not exist.

{% elif unmanaged_collision %}
qubes_gui_hud_rollback_unmanaged_target_refused:
  test.fail_without_changes:
    - name: >-
        Refusing rollback because a target is not an owned regular file, or a
        parent config path is not a real directory. No files were changed.

{% else %}

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

qubes_gui_hud_rollback_remove_gtk3_css:
  file.absent:
    - name: {{ user_gtk3_css }}

qubes_gui_hud_rollback_remove_gtk4_css:
  file.absent:
    - name: {{ user_gtk4_css }}

qubes_gui_hud_rollback_remove_wallpaper:
  file.absent:
    - name: {{ hud_wallpaper }}

qubes_gui_hud_rollback_remove_wallpaper_owner:
  file.absent:
    - name: {{ hud_wallpaper_owner }}
    - require:
      - file: qubes_gui_hud_rollback_remove_wallpaper

qubes_gui_hud_rollback_remove_binary:
  file.absent:
    - name: {{ hud_binary }}
    - require:
      - cmd: qubes_gui_hud_rollback_accountsservice_session

qubes_gui_hud_rollback_remove_binary_owner:
  file.absent:
    - name: {{ hud_binary_owner }}
    - require:
      - file: qubes_gui_hud_rollback_remove_binary

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
