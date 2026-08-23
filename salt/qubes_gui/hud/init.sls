{# Qubes OS 4.3 dom0 HUD session. No running desktop process is restarted. #}
{% set settings = salt['pillar.get']('qubes_gui:hud', {}) %}
{% set desktop_user = settings.get('desktop_user', 'user') %}
{% set desktop_group = settings.get('desktop_group', desktop_user) %}
{% set transport = settings.get('package_transport', 'auto') %}
{% set user_info = salt['user.info'](desktop_user) %}
{% set desktop_home = user_info.get('home', '/home/' ~ desktop_user) if user_info else '/home/' ~ desktop_user %}
{% set owner_marker = 'Managed by qubes-os-customization Salt formula' %}
{% set hud_asset_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' %}
{% set i3_hud_sha256 = '9f044f081661e1b3ef04ee2ef58be07d8044b083a2282c38918bde9792051e7c' %}
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
{% set runtime_packages = ['rofi', 'feh'] %}

{% set user_i3_config = desktop_home ~ '/.config/i3/config' %}
{% set user_rofi_theme = desktop_home ~ '/.config/rofi/config.rasi' %}
{% set user_dunst_config = desktop_home ~ '/.config/dunst/dunstrc' %}
{% set user_gtk3_css = desktop_home ~ '/.config/gtk-3.0/gtk.css' %}
{% set user_gtk4_css = desktop_home ~ '/.config/gtk-4.0/gtk.css' %}
{% set lightdm_config = '/etc/lightdm/lightdm.conf.d/91-qubes-hud.conf' %}
{% set xsession_file = '/usr/share/xsessions/qubes-hud.desktop' %}
{% set hud_binary = '/usr/local/libexec/qubes-hud/i3' %}
{% set hud_binary_owner = '/usr/local/libexec/qubes-hud/i3.owner' %}
{% set hud_wallpaper = '/usr/share/backgrounds/qubes-hud.png' %}
{% set hud_wallpaper_owner = '/usr/share/backgrounds/qubes-hud.png.owner' %}

{# Refuse to adopt a text target unless it already carries our marker. #}
{% set i3_exists = salt['file.file_exists'](user_i3_config) %}
{% set rofi_exists = salt['file.file_exists'](user_rofi_theme) %}
{% set dunst_exists = salt['file.file_exists'](user_dunst_config) %}
{% set gtk3_exists = salt['file.file_exists'](user_gtk3_css) %}
{% set gtk4_exists = salt['file.file_exists'](user_gtk4_css) %}
{% set lightdm_exists = salt['file.file_exists'](lightdm_config) %}
{% set xsession_exists = salt['file.file_exists'](xsession_file) %}
{% set i3_owned = owner_marker in salt['file.read'](user_i3_config) if i3_exists else false %}
{% set rofi_owned = (owner_marker in salt['file.read'](user_rofi_theme) or hud_asset_marker in salt['file.read'](user_rofi_theme)) if rofi_exists else false %}
{% set dunst_owned = (owner_marker in salt['file.read'](user_dunst_config) or hud_asset_marker in salt['file.read'](user_dunst_config)) if dunst_exists else false %}
{% set gtk3_owned = (owner_marker in salt['file.read'](user_gtk3_css) or hud_asset_marker in salt['file.read'](user_gtk3_css)) if gtk3_exists else false %}
{% set gtk4_owned = (owner_marker in salt['file.read'](user_gtk4_css) or hud_asset_marker in salt['file.read'](user_gtk4_css)) if gtk4_exists else false %}
{% set lightdm_owned = owner_marker in salt['file.read'](lightdm_config) if lightdm_exists else false %}
{% set xsession_owned = owner_marker in salt['file.read'](xsession_file) if xsession_exists else false %}

{# Binary assets use an adjacent text ownership record. #}
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
    or (lightdm_exists and not lightdm_owned)
    or (xsession_exists and not xsession_owned)
    or (binary_exists and not binary_owner_owned)
    or (binary_owner_exists and not binary_owner_owned)
    or (wallpaper_exists and not wallpaper_owner_owned)
    or (wallpaper_owner_exists and not wallpaper_owner_owned)
    or salt['file.is_link'](user_i3_config)
    or salt['file.is_link'](user_rofi_theme)
    or salt['file.is_link'](user_dunst_config)
    or salt['file.is_link'](user_gtk3_css)
    or salt['file.is_link'](user_gtk4_css)
    or salt['file.is_link'](lightdm_config)
    or salt['file.is_link'](xsession_file)
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
        Refusing to overwrite a pre-existing HUD target that is a symlink or
        does not contain a recognized HUD ownership marker. See the
        collision-safety section in qubes_gui/hud/README.md.

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
