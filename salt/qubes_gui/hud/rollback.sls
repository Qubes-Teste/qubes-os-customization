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
{% set user_gtk3_css = desktop_home ~ '/.config/gtk-3.0/gtk.css' %}
{% set user_gtk4_css = desktop_home ~ '/.config/gtk-4.0/gtk.css' %}
{% set official_i3_lightdm_config = '/etc/lightdm/lightdm.conf.d/90-qubes-i3.conf' %}
{% set hud_lightdm_config = '/etc/lightdm/lightdm.conf.d/91-qubes-hud.conf' %}
{% set hud_xsession = '/usr/share/xsessions/qubes-hud.desktop' %}
{% set hud_binary = '/usr/local/libexec/qubes-hud/i3' %}
{% set hud_binary_owner = '/usr/local/libexec/qubes-hud/i3.owner' %}
{% set hud_wallpaper = '/usr/share/backgrounds/qubes-hud.png' %}
{% set hud_wallpaper_owner = '/usr/share/backgrounds/qubes-hud.png.owner' %}

{% set i3_exists = salt['file.file_exists'](user_i3_config) %}
{% set rofi_exists = salt['file.file_exists'](user_rofi_theme) %}
{% set dunst_exists = salt['file.file_exists'](user_dunst_config) %}
{% set gtk3_exists = salt['file.file_exists'](user_gtk3_css) %}
{% set gtk4_exists = salt['file.file_exists'](user_gtk4_css) %}
{% set official_lightdm_exists = salt['file.file_exists'](official_i3_lightdm_config) %}
{% set hud_lightdm_exists = salt['file.file_exists'](hud_lightdm_config) %}
{% set hud_xsession_exists = salt['file.file_exists'](hud_xsession) %}
{% set i3_owned = owner_marker in salt['file.read'](user_i3_config) if i3_exists else false %}
{% set rofi_owned = (owner_marker in salt['file.read'](user_rofi_theme) or hud_asset_marker in salt['file.read'](user_rofi_theme)) if rofi_exists else false %}
{% set dunst_owned = (owner_marker in salt['file.read'](user_dunst_config) or hud_asset_marker in salt['file.read'](user_dunst_config)) if dunst_exists else false %}
{% set gtk3_owned = (owner_marker in salt['file.read'](user_gtk3_css) or hud_asset_marker in salt['file.read'](user_gtk3_css)) if gtk3_exists else false %}
{% set gtk4_owned = (owner_marker in salt['file.read'](user_gtk4_css) or hud_asset_marker in salt['file.read'](user_gtk4_css)) if gtk4_exists else false %}
{% set official_lightdm_owned = owner_marker in salt['file.read'](official_i3_lightdm_config) if official_lightdm_exists else false %}
{% set hud_lightdm_owned = owner_marker in salt['file.read'](hud_lightdm_config) if hud_lightdm_exists else false %}
{% set hud_xsession_owned = owner_marker in salt['file.read'](hud_xsession) if hud_xsession_exists else false %}

{% set binary_exists = salt['file.file_exists'](hud_binary) %}
{% set binary_owner_exists = salt['file.file_exists'](hud_binary_owner) %}
{% set binary_owner_owned = owner_marker in salt['file.read'](hud_binary_owner) if binary_owner_exists else false %}
{% set wallpaper_exists = salt['file.file_exists'](hud_wallpaper) %}
{% set wallpaper_owner_exists = salt['file.file_exists'](hud_wallpaper_owner) %}
{% set wallpaper_owner_owned = owner_marker in salt['file.read'](hud_wallpaper_owner) if wallpaper_owner_exists else false %}

{% set unmanaged_collision =
    (i3_exists and not i3_owned)
    or (rofi_exists and not rofi_owned)
    or (dunst_exists and not dunst_owned)
    or (gtk3_exists and not gtk3_owned)
    or (gtk4_exists and not gtk4_owned)
    or (official_lightdm_exists and not official_lightdm_owned)
    or (hud_lightdm_exists and not hud_lightdm_owned)
    or (hud_xsession_exists and not hud_xsession_owned)
    or (binary_exists and not binary_owner_owned)
    or (binary_owner_exists and not binary_owner_owned)
    or (wallpaper_exists and not wallpaper_owner_owned)
    or (wallpaper_owner_exists and not wallpaper_owner_owned)
    or salt['file.is_link'](user_i3_config)
    or salt['file.is_link'](user_rofi_theme)
    or salt['file.is_link'](user_dunst_config)
    or salt['file.is_link'](user_gtk3_css)
    or salt['file.is_link'](user_gtk4_css)
    or salt['file.is_link'](official_i3_lightdm_config)
    or salt['file.is_link'](hud_lightdm_config)
    or salt['file.is_link'](hud_xsession)
    or salt['file.is_link'](hud_binary)
    or salt['file.is_link'](hud_binary_owner)
    or salt['file.is_link'](hud_wallpaper)
    or salt['file.is_link'](hud_wallpaper_owner)
    or salt['file.is_link'](desktop_home ~ '/.config/i3')
    or salt['file.is_link'](desktop_home ~ '/.config/rofi')
    or salt['file.is_link'](desktop_home ~ '/.config/dunst')
    or salt['file.is_link'](desktop_home ~ '/.config/gtk-3.0')
    or salt['file.is_link'](desktop_home ~ '/.config/gtk-4.0')
    or salt['file.is_link']('/usr/local/libexec/qubes-hud') %}

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
        Refusing rollback because a target is a symlink or no longer contains
        a recognized HUD ownership marker. No files were changed.

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

{% endif %}
