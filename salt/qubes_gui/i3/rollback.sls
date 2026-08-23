{# Select Xfce for the next LightDM login without removing i3 or user files. #}
{% set settings = salt['pillar.get']('qubes_gui:i3', {}) %}
{% set desktop_user = settings.get('desktop_user', 'user') %}
{% set user_info = salt['user.info'](desktop_user) %}
{% set release = grains.get('osrelease', '')|string %}
{% set platform_ok = grains.get('virtual') == 'Qubes'
    and grains.get('virtual_subtype') == 'Xen Dom0'
    and (release == '4.3' or release.startswith('4.3.')) %}

{% if not platform_ok %}
qubes_gui_i3_rollback_unsupported_platform:
  test.fail_without_changes:
    - name: This rollback supports only Qubes OS 4.3 dom0.
{% elif not user_info %}
qubes_gui_i3_rollback_missing_user:
  test.fail_without_changes:
    - name: The configured desktop user '{{ desktop_user }}' does not exist.
{% else %}
/etc/lightdm/lightdm.conf.d/90-qubes-i3.conf:
  file.managed:
    - source: salt://qubes_gui/i3/files/90-qubes-xfce.conf
    - user: root
    - group: root
    - mode: '0644'

/usr/share/xsessions/xfce.desktop:
  file.exists: []

qubes_gui_i3_rollback_accountsservice_session:
  cmd.run:
    - name: >-
        /usr/bin/busctl call org.freedesktop.Accounts
        /org/freedesktop/Accounts/User{{ user_info['uid'] }}
        org.freedesktop.Accounts.User SetXSession s xfce
    - unless: >-
        /usr/bin/grep --quiet --fixed-strings XSession=xfce
        /var/lib/AccountsService/users/{{ desktop_user }}
    - require:
      - file: /etc/lightdm/lightdm.conf.d/90-qubes-i3.conf
      - file: /usr/share/xsessions/xfce.desktop
{% endif %}
