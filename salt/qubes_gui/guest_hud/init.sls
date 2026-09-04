{# System application theme for Qubes TemplateVMs. Never writes /home. #}
{% from 'qubes_gui/guest_hud/map.jinja' import guest_hud_platform with context %}
{% set owner_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/guest_hud.' %}
{% set shared_marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' %}
{% set theme_name = 'Qubes-HUD' %}
{% set theme_root = '/usr/share/themes/' ~ theme_name %}
{% set theme_owner = theme_root ~ '/.salt-owner' %}
{% set config_root = '/etc/qubes-hud' %}
{% set config_owner = config_root ~ '/.salt-owner' %}
{% set xdg_root = config_root ~ '/xdg' %}
{% set xfce_xsettings = xdg_root ~ '/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml' %}
{% set xfce_terminal = xdg_root ~ '/xfce4/terminal/terminalrc' %}
{% set dconf_defaults = '/etc/dconf/db/local.d/90-qubes-hud' %}
{% set dconf_locks = '/etc/dconf/db/local.d/locks/90-qubes-hud' %}
{% set dconf_database = '/etc/dconf/db/local' %}
{% set dconf_source_root = '/etc/dconf/db/local.d' %}
{% set dconf_locks_root = dconf_source_root ~ '/locks' %}
{% set dconf_profile = '/etc/dconf/profile/user' %}
{% set qubesdb_read = '/usr/bin/qubesdb-read' %}
{% set vm_type = salt['cmd.run'](
    qubesdb_read ~ ' /qubes-vm-type', python_shell=false,
    ignore_retcode=true)|trim if salt['file.file_exists'](qubesdb_read) else '' %}
{% set platform_ok = grains.get('kernel') == 'Linux'
    and grains.get('virtual')|lower == 'xen'
    and vm_type == 'TemplateVM'
    and guest_hud_platform.get('supported', false) %}

{# Refuse to adopt a pre-existing namespace or file we do not own. #}
{% set collision = namespace(found=false) %}
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
] + guest_hud_platform.get('session_directories', []) %}
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
    (xfce_xsettings, [owner_marker]),
    (xfce_terminal, [owner_marker]),
    (dconf_defaults, [owner_marker]),
    (dconf_locks, [owner_marker]),
    (guest_hud_platform.get('early_session', ''), [owner_marker]),
    (guest_hud_platform.get('late_session', ''), [owner_marker])
] %}
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

{% else %}

qubes_gui_guest_hud_runtime_packages:
  pkg.installed:
    - pkgs:
{% for package in guest_hud_platform.get('packages', []) %}
      - {{ package }}
{% endfor %}

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

qubes_gui_guest_hud_version:
  file.managed:
    - name: {{ config_root }}/VERSION
    - contents: |
        # {{ owner_marker }}
        2
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_guest_hud_config_owner

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
      - file: qubes_gui_guest_hud_gtk2_theme
      - file: qubes_gui_guest_hud_gtk3_overlay
      - file: qubes_gui_guest_hud_gtk4_overlay
      - file: qubes_gui_guest_hud_late_session
      - file: qubes_gui_guest_hud_xfce_terminal
      - cmd: qubes_gui_guest_hud_dconf_database

{% endif %}
