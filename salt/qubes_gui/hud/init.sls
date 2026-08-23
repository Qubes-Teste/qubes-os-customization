{# Qubes OS 4.3 dom0 HUD session. No running desktop process is restarted. #}
{% set settings = salt['pillar.get']('qubes_gui:hud', {}) %}
{% set desktop_user = settings.get('desktop_user', 'user') %}
{% set desktop_group = settings.get('desktop_group', desktop_user) %}
{% set transport = settings.get('package_transport', 'auto') %}
{% set user_info = salt['user.info'](desktop_user) %}
{% set desktop_home = user_info.get('home', '/home/' ~ desktop_user) if user_info else '/home/' ~ desktop_user %}
{% set owner_marker = 'Managed by qubes-os-customization Salt formula' %}
{% set hud_asset_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' %}
{% set i3_hud_sha256 = '2dec876a423d73d3ab08912cc0487a0cd23a2112546a903a8467010b2d561721' %}
{% set expected_i3_evr = '1000:4.25.1-1.fc41.x86_64' %}
{% set expected_i3_settings_evr = '1.14-1.fc41' %}
{% set release = grains.get('osrelease', '')|string %}
{% set architecture = grains.get('cpuarch', grains.get('osarch', ''))|string %}
{% set platform_ok = grains.get('virtual') == 'Qubes'
    and grains.get('virtual_subtype') == 'Xen Dom0'
    and (release == '4.3' or release.startswith('4.3.'))
    and architecture == 'x86_64' %}
{% set installed_i3_evr = salt['cmd.run'](
    "/usr/bin/rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}' i3",
    python_shell=false,
    ignore_retcode=true)|trim %}
{% set installed_i3_settings_evr = salt['cmd.run'](
    "/usr/bin/rpm -q --qf '%{VERSION}-%{RELEASE}' i3-settings-qubes",
    python_shell=false,
    ignore_retcode=true)|trim %}
{% set binary_hash_ready = i3_hud_sha256|length == 64 %}
{% set runtime_packages = ['rofi', 'feh', 'picom'] %}

{% set user_i3_config = desktop_home ~ '/.config/i3/config' %}
{% set user_rofi_theme = desktop_home ~ '/.config/rofi/config.rasi' %}
{% set user_dunst_config = desktop_home ~ '/.config/dunst/dunstrc' %}
{% set user_gtk3_css = desktop_home ~ '/.config/gtk-3.0/gtk.css' %}
{% set user_gtk4_css = desktop_home ~ '/.config/gtk-4.0/gtk.css' %}
{% set lightdm_config = '/etc/lightdm/lightdm.conf.d/91-qubes-hud.conf' %}
{% set xsession_file = '/usr/share/xsessions/qubes-hud.desktop' %}
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
{% set picom_preinstalled = salt['cmd.retcode'](
    '/usr/bin/rpm --quiet -q picom', python_shell=false,
    ignore_retcode=true) == 0 %}

{% set text_targets = [
    (user_i3_config, [owner_marker]),
    (user_rofi_theme, [owner_marker, hud_asset_marker]),
    (user_dunst_config, [owner_marker, hud_asset_marker]),
    (user_gtk3_css, [owner_marker, hud_asset_marker]),
    (user_gtk4_css, [owner_marker, hud_asset_marker]),
    (lightdm_config, [owner_marker]),
    (xsession_file, [owner_marker]),
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

{# Binary assets use a regular, owner-marked adjacent text record. #}
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

{% elif installed_i3_evr != expected_i3_evr %}
qubes_gui_hud_unsupported_i3_build:
  test.fail_without_changes:
    - name: >-
        Refusing to install the pinned HUD binary: installed i3 is
        '{{ installed_i3_evr }}', expected exactly '{{ expected_i3_evr }}'.

{% elif installed_i3_settings_evr != expected_i3_settings_evr %}
qubes_gui_hud_unsupported_i3_settings_build:
  test.fail_without_changes:
    - name: >-
        Refusing to install the HUD config: installed i3-settings-qubes is
        '{{ installed_i3_settings_evr }}', expected exactly
        '{{ expected_i3_settings_evr }}'.

{% elif not binary_hash_ready %}
qubes_gui_hud_binary_hash_not_pinned:
  test.fail_without_changes:
    - name: >-
        Set i3_hud_sha256 in qubes_gui/hud/init.sls to the audited,
        64-character files/i3-hud SHA-256 before applying this state.

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

qubes_gui_hud_official_i3_fallback_present:
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

qubes_gui_hud_i3_binary:
  file.managed:
    - name: {{ hud_binary }}
    - source: salt://qubes_gui/hud/files/i3-hud
    - check_cmd: >-
        /usr/bin/bash -c '/usr/bin/printf "%s  %s\n" "{{ i3_hud_sha256 }}"
        "$1" | /usr/bin/sha256sum --check --status -' --
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_binary_directory
      - cmd: qubes_gui_hud_official_i3_fallback_present

qubes_gui_hud_i3_binary_owner:
  file.managed:
    - name: {{ hud_binary_owner }}
    - contents: |
        # {{ owner_marker }}.
        target={{ hud_binary }}
        sha256={{ i3_hud_sha256 }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_hud_i3_binary

qubes_gui_hud_i3_binary_checksum:
  cmd.run:
    - name: >-
        /usr/bin/bash -c '/usr/bin/printf "%s  %s\n" "{{ i3_hud_sha256 }}"
        "{{ hud_binary }}" | /usr/bin/sha256sum --check --status -'
    - unless: >-
        /usr/bin/bash -c '/usr/bin/printf "%s  %s\n" "{{ i3_hud_sha256 }}"
        "{{ hud_binary }}" | /usr/bin/sha256sum --check --status -'
    - require:
      - file: qubes_gui_hud_i3_binary
      - file: qubes_gui_hud_i3_binary_owner

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
    - check_cmd: {{ hud_binary }} -C -c
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: qubes_gui_hud_user_i3_directory
      - file: qubes_gui_hud_keyboard_helper
      - file: qubes_gui_hud_autostart_helper
      - cmd: qubes_gui_hud_i3_binary_checksum

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
      - cmd: qubes_gui_hud_i3_binary_checksum
      - file: qubes_gui_hud_i3_config
      - file: qubes_gui_hud_picom_config
      - file: qubes_gui_hud_autostart_helper
      - file: qubes_gui_hud_wallpaper

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
