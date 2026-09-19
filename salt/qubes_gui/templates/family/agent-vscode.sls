{# Guest-only native Microsoft package repository and data-only builtin theme. #}
{% from 'qubes_gui/templates/family/scope.jinja' import scope with context %}
{% if not scope.valid or scope.role != 'agent' %}
qubes_gui_template_agent_vscode_scope_refused:
  test.fail_without_changes:
    - name: VS Code requires the owned Debian Agent TemplateVM.
{% else %}
{% set key = '/etc/apt/keyrings/qubes-hud-vscode.asc' %}
{% set source = '/etc/apt/sources.list.d/qubes-hud-vscode.sources' %}
{% set pin = '/etc/apt/preferences.d/qubes-hud-vscode' %}
{% set extensions = '/usr/share/code/resources/app/extensions' %}
{% set theme = extensions ~ '/qubes-hud-theme' %}
{% set owner = 'Qubes HUD managed file. Owner: salt/qubes_gui/templates/family.' %}
{% set safe = namespace(value=true) %}
{% set optional_dirs = ['/etc/apt/keyrings', '/usr/share/code',
    '/usr/share/code/resources', '/usr/share/code/resources/app', extensions, theme] %}
{% for path in ['/', '/etc', '/etc/apt', '/etc/apt/sources.list.d',
    '/etc/apt/preferences.d', '/usr', '/usr/bin', '/usr/share', '/usr/local',
    '/usr/local/bin'] + optional_dirs %}
  {% set st = salt['file.lstat'](path) %}
  {% if (not st and path not in optional_dirs) or (st and (
      st.get('st_uid') != 0 or st.get('st_gid') != 0
      or st.get('st_mode') not in ([16749, 16877] if path == '/' else [16877]))) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{# Microsoft's package postinst removes this path unconditionally. #}
{% if salt['file.lstat']('/usr/local/bin/code') %}{% set safe.value = false %}{% endif %}
{% set installed = salt['pkg.version']('code') %}
{% if (salt['file.lstat']('/usr/bin/code') or salt['file.lstat']('/usr/share/code')) and not installed %}
  {% set safe.value = false %}
{% endif %}
{% for path in [key, source, pin, theme ~ '/package.json', theme ~ '/qubes-hud-color-theme.json'] if safe.value %}
  {% set st = salt['file.lstat'](path) %}
  {% if st %}
    {% if st.get('st_mode') != 33188 or st.get('st_uid') != 0
        or st.get('st_gid') != 0 or st.get('st_nlink') != 1 %}
      {% set safe.value = false %}
    {% elif path == key %}
      {% if salt['file.get_hash'](path, 'sha256') != '2fa9c05d591a1582a9aba276272478c262e95ad00acf60eaee1644d93941e3c6' %}
        {% set safe.value = false %}
      {% endif %}
    {% elif path in [source, pin] %}
      {% if owner not in salt['file.read'](path) %}{% set safe.value = false %}{% endif %}
    {% else %}
      {% set data = salt['file.read'](path)|load_json %}
      {% if data is not mapping or (path.endswith('/package.json') and (
          data.get('name') != 'qubes-hud-theme' or data.get('publisher') != 'qubes-hud'
          or data.get('description') != 'Qubes HUD managed theme. Owner: salt/qubes_gui/templates/family.'))
          or (path.endswith('/qubes-hud-color-theme.json') and data.get('name') != 'Qubes HUD') %}
        {% set safe.value = false %}
      {% endif %}
    {% endif %}
  {% elif path == theme ~ '/package.json' and salt['file.lstat'](theme) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% if not safe.value %}
qubes_gui_template_agent_vscode_paths_refused:
  test.fail_without_changes:
    - name: Refusing unsafe or unowned VS Code repository/theme paths or a local Code installation.
{% else %}
qubes_gui_template_agent_vscode_keyring_dir:
  file.directory:
    - name: /etc/apt/keyrings
    - user: root
    - group: root
    - mode: '0755'

qubes_gui_template_agent_vscode_key:
  file.managed:
    - name: {{ key }}
    - source: salt://qubes_gui/templates/family/files/microsoft-vscode.asc
    - source_hash: sha256=2fa9c05d591a1582a9aba276272478c262e95ad00acf60eaee1644d93941e3c6
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_template_agent_vscode_keyring_dir

qubes_gui_template_agent_vscode_source:
  file.managed:
    - name: {{ source }}
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        # {{ owner }}
        Types: deb
        URIs: https://packages.microsoft.com/repos/code
        Suites: stable
        Components: main
        Architectures: amd64
        Signed-By: {{ key }}
    - require:
      - file: qubes_gui_template_agent_vscode_key

qubes_gui_template_agent_vscode_pin:
  file.managed:
    - name: {{ pin }}
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        # {{ owner }}
        Package: code
        Pin: origin "packages.microsoft.com"
        Pin-Priority: 500

        Package: *
        Pin: origin "packages.microsoft.com"
        Pin-Priority: -1

qubes_gui_template_agent_vscode_debconf:
  {# Salt's debconf module requires extra debconf-utils; Debian already ships
     these native configuration commands. Do not install a helper package. #}
  cmd.run:
    - name: /usr/bin/debconf-set-selections
    - stdin: 'code code/add-microsoft-repo boolean false'
    - unless: >-
        test "$(printf 'GET code/add-microsoft-repo\n' |
        /usr/bin/debconf-communicate code)" = '0 false'

qubes_gui_template_agent_vscode_refresh:
  module.run:
    - pkg.refresh_db:
      - failhard: true
    - onchanges:
      - file: qubes_gui_template_agent_vscode_key
      - file: qubes_gui_template_agent_vscode_source
      - file: qubes_gui_template_agent_vscode_pin

{# A fresh test cannot discover a package from a source it has not created. #}
{% set planned = opts.get('test', false) and not installed and not salt['file.file_exists'](source) %}
qubes_gui_template_agent_vscode_package:
{% if planned %}
  test.nop:
    - name: Would install code from the signed Microsoft source after its first APT refresh.
{% else %}
  pkg.installed:
    - name: code
    - install_recommends: false
    - refresh: true
{% endif %}
    - require:
      - module: qubes_gui_template_agent_vscode_refresh
      - cmd: qubes_gui_template_agent_vscode_debconf

qubes_gui_template_agent_vscode_theme_dir:
  file.directory:
    - name: {{ theme }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - {{ 'test' if planned else 'pkg' }}: qubes_gui_template_agent_vscode_package

{% for filename in ['package.json', 'qubes-hud-color-theme.json'] %}
qubes_gui_template_agent_vscode_theme_{{ loop.index }}:
  file.managed:
    - name: {{ theme }}/{{ filename }}
    - source: salt://qubes_gui/templates/family/files/vscode-hud/{{ filename }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_template_agent_vscode_theme_dir
{% endfor %}
{% endif %}
{% endif %}
