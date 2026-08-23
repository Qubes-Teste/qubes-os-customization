{# Qubes OS 4.3 dom0 i3 state. #}
{% set settings = salt['pillar.get']('qubes_gui:i3', {}) %}
{% set desktop_user = settings.get('desktop_user', 'user') %}
{% set desktop_group = settings.get('desktop_group', desktop_user) %}
{% set modifier = settings.get('modifier', 'Mod4') %}
{% set set_default_session = settings.get('set_default_session', true) %}
{% set force_replace = settings.get('force_replace_user_config', false) %}
{% set transport = settings.get('package_transport', 'auto') %}
{% set user_info = salt['user.info'](desktop_user) %}
{% set desktop_home = user_info.get('home', '/home/' ~ desktop_user) if user_info else '/home/' ~ desktop_user %}
{% set user_config = desktop_home ~ '/.config/i3/config' %}
{% set managed_marker = 'Managed by qubes-os-customization Salt formula' %}
{% set existing_config = salt['file.read'](user_config) if salt['file.file_exists'](user_config) else '' %}
{% set config_collision = existing_config and managed_marker not in existing_config and not force_replace %}
{% set release = grains.get('osrelease', '')|string %}
{% set packages = [
    'i3',
    'i3-settings-qubes',
    'j4-dmenu-desktop',
    'dmenu',
    'dunst',
    'pulseaudio-utils',
    'xss-lock',
] %}
{% set platform_ok = grains.get('virtual') == 'Qubes'
    and grains.get('virtual_subtype') == 'Xen Dom0'
    and (release == '4.3' or release.startswith('4.3.')) %}

{% if transport == 'auto' %}
  {% set direct_route = salt['cmd.run']('/usr/sbin/ip -4 route show default', python_shell=false)|trim %}
  {% set transport = 'direct-dom0' if direct_route else 'qubes-updatevm' %}
{% endif %}

{% if not platform_ok %}
qubes_gui_i3_unsupported_platform:
  test.fail_without_changes:
    - name: This formula supports only Qubes OS 4.3 dom0.

{% elif not user_info %}
qubes_gui_i3_missing_desktop_user:
  test.fail_without_changes:
    - name: The configured desktop user '{{ desktop_user }}' does not exist.

{% elif modifier not in ['Mod1', 'Mod4'] %}
qubes_gui_i3_invalid_modifier:
  test.fail_without_changes:
    - name: The i3 modifier must be Mod1 or Mod4, not '{{ modifier }}'.

{% elif transport not in ['direct-dom0', 'qubes-updatevm'] %}
qubes_gui_i3_invalid_transport:
  test.fail_without_changes:
    - name: The package transport must be auto, direct-dom0, or qubes-updatevm.

{% elif config_collision %}
qubes_gui_i3_existing_config_refused:
  test.fail_without_changes:
    - name: >-
        Refusing to replace unmanaged i3 config {{ user_config }}. Set
        qubes_gui:i3:force_replace_user_config to true to adopt it explicitly.

{% else %}

{% if transport == 'direct-dom0' %}
qubes_gui_i3_packages_direct:
  cmd.run:
    - name: >-
        /usr/bin/dnf --setopt=reposdir=/etc/yum.repos.d --refresh
        --assumeyes install {{ packages|join(' ') }}
    - unless: /usr/bin/rpm --quiet -q {{ packages|join(' ') }}
{% else %}
qubes_gui_i3_packages_qubes_updatevm:
  pkg.installed:
    - pkgs:
{% for package in packages %}
      - {{ package }}
{% endfor %}
    - refresh: true
{% endif %}

qubes_gui_i3_session_file_present:
  cmd.run:
    - name: /usr/bin/test -f /usr/share/xsessions/i3.desktop
    - unless: /usr/bin/test -f /usr/share/xsessions/i3.desktop
    - require:
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_i3_packages_direct
{% else %}
      - pkg: qubes_gui_i3_packages_qubes_updatevm
{% endif %}

qubes_gui_i3_keycodes_present:
  cmd.run:
    - name: /usr/bin/test -f /etc/i3/config.keycodes
    - unless: /usr/bin/test -f /etc/i3/config.keycodes
    - require:
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_i3_packages_direct
{% else %}
      - pkg: qubes_gui_i3_packages_qubes_updatevm
{% endif %}

/etc/i3/config.d:
  file.directory:
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true
    - require:
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_i3_packages_direct
{% else %}
      - pkg: qubes_gui_i3_packages_qubes_updatevm
{% endif %}

/etc/i3/config.d/10-qubes-customization.conf:
  file.managed:
    - source: salt://qubes_gui/i3/files/10-qubes-customization.conf.jinja
    - template: jinja
    - context:
        modifier: '{{ modifier }}'
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: /etc/i3/config.d

{{ desktop_home }}/.config/i3:
  file.directory:
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0755'
    - makedirs: true
    - require:
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_i3_packages_direct
{% else %}
      - pkg: qubes_gui_i3_packages_qubes_updatevm
{% endif %}

{{ user_config }}:
  file.managed:
    - source: salt://qubes_gui/i3/files/i3-user-config
    - check_cmd: /usr/bin/i3 -C -c
    - user: {{ desktop_user }}
    - group: {{ desktop_group }}
    - mode: '0644'
    - backup: minion
    - require:
      - file: {{ desktop_home }}/.config/i3
      - cmd: qubes_gui_i3_keycodes_present
      - file: /etc/i3/config.d/10-qubes-customization.conf

{% if set_default_session %}
/etc/lightdm/lightdm.conf.d/90-qubes-i3.conf:
  file.managed:
    - source: salt://qubes_gui/i3/files/90-qubes-i3.conf
    - user: root
    - group: root
    - mode: '0644'
    - require:
{% if transport == 'direct-dom0' %}
      - cmd: qubes_gui_i3_packages_direct
{% else %}
      - pkg: qubes_gui_i3_packages_qubes_updatevm
{% endif %}
      - cmd: qubes_gui_i3_session_file_present

qubes_gui_i3_accountsservice_session:
  cmd.run:
    - name: >-
        /usr/bin/busctl call org.freedesktop.Accounts
        /org/freedesktop/Accounts/User{{ user_info['uid'] }}
        org.freedesktop.Accounts.User SetXSession s i3
    - unless: >-
        /usr/bin/grep --quiet --fixed-strings XSession=i3
        /var/lib/AccountsService/users/{{ desktop_user }}
    - require:
      - file: /etc/lightdm/lightdm.conf.d/90-qubes-i3.conf
      - file: {{ user_config }}
{% else %}
/etc/lightdm/lightdm.conf.d/90-qubes-i3.conf:
  file.absent
{% endif %}

{% endif %}
