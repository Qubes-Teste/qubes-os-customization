{# Stock Electrum uses the shared native Qt palette only through its launcher. #}
{% from 'qubes_gui/templates/family/scope.jinja' import scope with context %}
{% set owner = 'Qubes HUD managed file. Owner: salt/qubes_gui/guest_hud.' %}
{% set root = '/etc/qubes-hud/xdg/qt5ct' %}
{% set desktop = '/usr/share/applications/electrum.desktop' %}
{% if not scope.valid or scope.role != 'trader' %}
qubes_gui_template_trader_scope_refused:
  test.fail_without_changes:
    - name: Trader packages require the owned Debian Trader TemplateVM.
{% else %}
{% set safe = namespace(value=true) %}
{% set optional_dirs = ['/etc/qubes-hud', '/etc/qubes-hud/xdg', root, root ~ '/colors'] %}
{% for path in ['/', '/etc', '/usr', '/usr/share', '/usr/share/applications'] + optional_dirs %}
  {% set st = salt['file.lstat'](path) %}
  {# Exact native modes include the file type: directories 0755, root also 0555. #}
  {% if (not st and path not in optional_dirs) or (st and (
      st.get('st_uid') != 0 or st.get('st_gid') != 0
      or st.get('st_mode') not in ([16749, 16877] if path == '/' else [16877]))) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% for path in ['/etc/qubes-hud/.salt-owner', root ~ '/qt5ct.conf', root ~ '/colors/qubes-hud.conf'] if safe.value %}
  {% set st = salt['file.lstat'](path) %}
  {% if st %}
    {% if st.get('st_mode') != 33188 or st.get('st_uid') != 0
        or st.get('st_gid') != 0 or st.get('st_nlink') != 1 %}
      {% set safe.value = false %}
    {% elif owner not in salt['file.read'](path) %}
      {% set safe.value = false %}
    {% endif %}
  {% elif path == '/etc/qubes-hud/.salt-owner'
      and salt['file.lstat']('/etc/qubes-hud') %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% set st = salt['file.lstat'](desktop) if safe.value else {} %}
{% if st %}
  {% set package = salt['cmd.run_all'](
      ['/usr/bin/dpkg-query', '--search', desktop], python_shell=false,
      ignore_retcode=true, env={'LC_ALL': 'C'}) %}
  {% if st.get('st_mode') != 33188 or st.get('st_uid') != 0
      or st.get('st_gid') != 0 or st.get('st_nlink') != 1
      or package.get('retcode') != 0
      or package.get('stdout', '').split(':', 1)[0] != 'electrum' %}
    {% set safe.value = false %}
  {% endif %}
{% elif safe.value and salt['pkg.version']('electrum') %}
  {% set safe.value = false %}
{% endif %}
{% if not safe.value %}
qubes_gui_template_trader_paths_refused:
  test.fail_without_changes:
    - name: Refusing unsafe or unowned Trader Qt configuration or a non-package Electrum launcher.
{% else %}
include:
  - qubes_gui.templates.family.base

qubes_gui_template_trader_electrum:
  pkg.installed:
    - pkgs:
      - electrum
      - qt5ct
    - install_recommends: false
    - require:
      - sls: qubes_gui.templates.family.base

qubes_gui_template_trader_qt5ct_root:
  file.directory:
    - name: {{ root }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - sls: qubes_gui.templates.family.base

qubes_gui_template_trader_qt5ct_colors:
  file.directory:
    - name: {{ root }}/colors
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_template_trader_qt5ct_root

{% for name, source in [('qt5ct.conf', 'qt5ct.conf'), ('colors/qubes-hud.conf', 'qt5ct-qubes-hud.conf')] %}
qubes_gui_template_trader_qt5ct_file_{{ loop.index }}:
  file.managed:
    - name: {{ root }}/{{ name }}
    - source: salt://qubes_gui/guest_hud/files/{{ source }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: qubes_gui_template_trader_electrum
      - file: qubes_gui_template_trader_qt5ct_colors
{% endfor %}

{# Preserve all desktop metadata and URL handling. Electrum data uses HOME or
   ELECTRUMDIR, independently of XDG_CONFIG_HOME; neither is changed here. #}
qubes_gui_template_trader_electrum_launcher:
  ini.options_present:
    - name: {{ desktop }}
    - sections:
        Desktop Entry:
          Exec: '/usr/bin/env QT_QPA_PLATFORMTHEME=qt5ct XDG_CONFIG_HOME=/etc/qubes-hud/xdg /usr/bin/electrum %u'
    - strict: false
    - no_spaces: true
    - encoding: UTF-8
    - require:
      - pkg: qubes_gui_template_trader_electrum
      - file: qubes_gui_template_trader_qt5ct_file_1
      - file: qubes_gui_template_trader_qt5ct_file_2

qubes_gui_template_trader_menu_sync:
  cmd.run:
    - name: /usr/lib/qubes/qubes-trigger-sync-appmenus.sh
    - onchanges:
      - ini: qubes_gui_template_trader_electrum_launcher
{% endif %}
{% endif %}
