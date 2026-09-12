{# Optional AppVM workspace. Apply in dom0, then the guest, then dom0 ready:true.
   Native XDG autostart launches the programs; no guest runtime helper is used. #}
{% set cfg = salt['pillar.get']('qubes_gui:hud:qube_workspace', {}) %}
{% set name = cfg.get('name', '')|string %}
{% set template = cfg.get('template', '')|string %}
{% set ready = cfg.get('ready', false) %}
{% set rollback = qube_rollback|default(false) %}
{# Installed Qubes qvm.prefs writes properties even in Salt test mode. Never
   render that state during previews; native qvm.prefs remains the apply path. #}
{% set preview = opts.get('test', false) %}
{% set prefs_requisite = 'test' if preview else 'qvm' %}
{% set tag = 'hud-workspace-managed' %}
{% set marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud/qube.' %}
{% set valid = namespace(value=(ready is sameas true or ready is sameas false)) %}
{% for value in [name, template] %}
  {% if not value or value|length > 31 or value[0] not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
      or value in ['dom0', 'Domain-0', 'none', 'default'] or value.endswith('-dm') %}
    {% set valid.value = false %}
  {% endif %}
  {% for character in value %}
    {% if character not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-' %}
      {% set valid.value = false %}
    {% endif %}
  {% endfor %}
{% endfor %}
{% set release = grains.get('osrelease', '')|string %}
{% set dom0 = grains.get('virtual') == 'Qubes' and grains.get('virtual_subtype') == 'Xen Dom0'
    and (release == '4.3' or release.startswith('4.3.'))
    and grains.get('cpuarch', grains.get('osarch', '')) == 'x86_64' %}

{% if not name %}
qubes_gui_hud_qube_disabled:
  test.nop:
    - name: No optional qube workspace selected.
{% elif not valid.value or name == template %}
qubes_gui_hud_qube_invalid:
  test.fail_without_changes:
    - name: Set distinct valid name/template qube names and boolean ready under qubes_gui:hud:qube_workspace.
{% elif dom0 %}
{% set exists = salt['cmd.retcode']('/usr/bin/qvm-check --quiet ' ~ name,
    python_shell=false, ignore_retcode=true) == 0 %}
{% set tags = salt['cmd.run']('/usr/bin/qvm-tags ' ~ name ~ ' list',
    python_shell=false, ignore_retcode=true).splitlines() if exists else [] %}
{% set klass = salt['cmd.run']('/usr/bin/qvm-ls --raw-data --fields CLASS -- ' ~ name,
    python_shell=false, ignore_retcode=true)|trim if exists else '' %}
{% set actual_template = salt['cmd.run']('/usr/bin/qvm-prefs ' ~ name ~ ' template',
    python_shell=false, ignore_retcode=true)|trim if exists else '' %}
{% if exists and (tag not in tags or klass != 'AppVM' or actual_template != template) %}
qubes_gui_hud_qube_existing_refused:
  test.fail_without_changes:
    - name: Refusing an existing qube without the ownership tag, matching AppVM class and configured template.
{% elif ready and not exists and not rollback %}
qubes_gui_hud_qube_missing_setup:
  test.fail_without_changes:
    - name: Create the qube and apply its guest state before finalizing with ready true.
{% else %}
{% set files = {
    '/etc/qubes-hud/qube-workspace.json': '{"name":"' ~ name ~ '","workspace":2}',
    '/etc/qubes-hud/qube-workspace.i3': '# ' ~ marker ~ '\nassign [class="^' ~ name|replace('.', '[.]') ~ ':"] number 2\nfor_window [class="^' ~ name|replace('.', '[.]') ~ ':"] exec --no-startup-id /usr/local/libexec/qubes-hud/hud-workspace --qube --prepare',
    '/usr/share/applications/qubes-hud-qube-workspace.desktop': '[Desktop Entry]\n# ' ~ marker ~ '\nType=Application\nName=' ~ name ~ ': Start workspace\nExec=/usr/local/libexec/qubes-hud/hud-workspace --qube\nIcon=qubes\nTerminal=false\nCategories=System;X-Qubes-VM;\nX-Qubes-VmName=' ~ name ~ '\nX-Qubes-AppName=hud-start-workspace'
} %}
{% set safe = namespace(value=true) %}
{% if ready or rollback %}
  {% for path in ['/etc', '/etc/qubes-hud', '/usr', '/usr/share', '/usr/share/applications',
      '/usr/local', '/usr/local/libexec', '/usr/local/libexec/qubes-hud'] %}
    {% set st = salt['file.lstat'](path) %}
    {% if st and (not salt['file.directory_exists'](path) or salt['file.is_link'](path)
        or st.get('st_uid') != 0 or st.get('st_gid') != 0 or salt['file.get_mode'](path) != '0755') %}
      {% set safe.value = false %}
    {% endif %}
  {% endfor %}
  {% for path, content in files.items() %}
    {% set st = salt['file.lstat'](path) %}
    {% if st and (not salt['file.file_exists'](path) or salt['file.is_link'](path)
        or st.get('st_nlink') != 1 or st.get('st_uid') != 0 or st.get('st_gid') != 0
        or salt['file.get_mode'](path) != '0644'
        or salt['file.read'](path)|trim != content|trim) %}
      {% set safe.value = false %}
    {% endif %}
  {% endfor %}
  {% if not rollback %}
  {% set helper = '/usr/local/libexec/qubes-hud/hud-workspace' %}
  {% set st = salt['file.lstat'](helper) %}
  {% if not st or not salt['file.file_exists'](helper) or salt['file.is_link'](helper)
      or st.get('st_uid') != 0 or st.get('st_gid') != 0 or st.get('st_nlink') != 1
      or salt['file.get_mode'](helper) != '0755'
      or 'Qubes HUD managed file. Owner: salt/qubes_gui/hud.' not in salt['file.read'](helper) %}
    {% set safe.value = false %}
  {% elif salt['cmd.retcode']('/usr/bin/python3 -B ' ~ helper ~ ' --qube --check',
      python_shell=false, ignore_retcode=true) != 0 %}
    {% set safe.value = false %}
  {% endif %}
  {% endif %}
{% endif %}
{% if not safe.value %}
qubes_gui_hud_qube_files_refused:
  test.fail_without_changes:
    - name: Refusing unowned or modified workspace assets, unsafe directories, or a missing managed HUD helper.
{% elif rollback %}
{# The optional state only creates new AppVMs, whose original autostart is false.
   Preserve the qube, private volume, tag and unrelated preferences on rollback. #}
{% if exists and salt['file.lstat']('/etc/qubes-hud/qube-workspace.json') %}
qubes_gui_hud_qube_boot_disabled:
{% if preview %}
  test.nop:
    - name: Would restore the managed AppVM's original autostart false before removing its workspace assets.
{% else %}
  qvm.prefs:
    - name: '{{ name }}'
    - autostart: false
{% endif %}
{% endif %}
{% for path in files %}
qubes_gui_hud_qube_asset_{{ loop.index }}_removed:
  file.absent:
    - name: '{{ path }}'
{% if exists and salt['file.lstat']('/etc/qubes-hud/qube-workspace.json') %}
    - require:
      - {{ prefs_requisite }}: qubes_gui_hud_qube_boot_disabled
{% endif %}
{% endfor %}
{% else %}
qubes_gui_hud_qube_template:
  qvm.exists:
    - name: '{{ template }}'
    - flags: [template]

qubes_gui_hud_qube_netvm:
  qvm.exists:
    - name: sys-firewall

qubes_gui_hud_qube_present:
  qvm.present:
    - name: '{{ name }}'
    - class: AppVM
    - template: '{{ template }}'
    - label: green
    - require:
      - qvm: qubes_gui_hud_qube_template
      - qvm: qubes_gui_hud_qube_netvm

{% if not exists and preview %}
{# Native qvm.tags/prefs cannot query a domain that qvm.present only planned. #}
qubes_gui_hud_qube_new_preferences_planned:
  test.nop:
    - name: The newly created AppVM will receive the ownership tag, sys-firewall netvm and autostart false.
    - require:
      - qvm: qubes_gui_hud_qube_present
{% else %}
qubes_gui_hud_qube_tag:
  qvm.tags:
    - name: '{{ name }}'
    - add: [{{ tag }}]
    - require:
      - qvm: qubes_gui_hud_qube_present

qubes_gui_hud_qube_preferences:
{% if preview %}
  test.nop:
    - name: Would configure the managed AppVM's netvm as sys-firewall.
{% else %}
  qvm.prefs:
    - name: '{{ name }}'
    - netvm: sys-firewall
{% if not exists %}
    - autostart: false
{% endif %}
{% endif %}
    - require:
      - qvm: qubes_gui_hud_qube_tag
{% endif %}

{% if ready %}
qubes_gui_hud_qube_config_directory:
  file.directory:
    - name: /etc/qubes-hud
    - user: root
    - group: root
    - mode: '0755'

{% for path, content in files.items() %}
qubes_gui_hud_qube_asset_{{ loop.index }}:
  file.managed:
    - name: '{{ path }}'
    - user: root
    - group: root
    - mode: '0644'
    - contents: {{ content|tojson }}
{% if path.endswith('.i3') %}
    - check_cmd: /usr/bin/i3 -C -c
{% endif %}
    - require:
      - file: qubes_gui_hud_qube_config_directory
      - {{ prefs_requisite }}: qubes_gui_hud_qube_preferences
{% endfor %}

qubes_gui_hud_qube_boot:
{% if preview %}
  test.nop:
    - name: Would enable the managed AppVM's boot autostart after installing and validating its workspace assets.
{% else %}
  qvm.prefs:
    - name: '{{ name }}'
    - autostart: true
{% endif %}
    - require:
{% for path in files %}
      - file: qubes_gui_hud_qube_asset_{{ loop.index }}
{% endfor %}
{% else %}
qubes_gui_hud_qube_next_phase:
  test.nop:
    - name: Apply qubes_gui.hud.qube inside the new AppVM, then repeat in dom0 with ready true.
    - require:
{% if not exists and preview %}
      - test: qubes_gui_hud_qube_new_preferences_planned
{% else %}
      - {{ prefs_requisite }}: qubes_gui_hud_qube_preferences
{% endif %}
{% endif %}
{% endif %}
{% endif %}
{% else %}
{% set qdb = '/usr/bin/qubesdb-read' %}
{% set vmname = salt['cmd.run'](qdb ~ ' /name', python_shell=false,
    ignore_retcode=true)|trim if salt['file.file_exists'](qdb) else '' %}
{% set vmtype = salt['cmd.run'](qdb ~ ' /type', python_shell=false,
    ignore_retcode=true)|trim if salt['file.file_exists'](qdb) else '' %}
{% set username = salt['cmd.run'](qdb ~ ' /default-user', python_shell=false,
    ignore_retcode=true)|trim if salt['file.file_exists'](qdb) else '' %}
{% set user = salt['user.info'](username) if username else {} %}
{% set home = user.get('home', '') %}
{% set detected_browser = salt['cmd.which']('firefox') or salt['cmd.which']('firefox-esr') %}
{% set browser = detected_browser or '/usr/bin/firefox' %}
{% set programs_available = detected_browser in ['/usr/bin/firefox', '/usr/bin/firefox-esr']
    and salt['cmd.which']('xfce4-terminal') == '/usr/bin/xfce4-terminal'
    and salt['cmd.which']('thunar') == '/usr/bin/thunar' %}
{% set supported = grains.get('kernel') == 'Linux' and grains.get('virtual')|lower == 'xen'
    and grains.get('os_family') in ['Debian', 'RedHat'] and vmtype == 'AppVM'
    and vmname == name and user.get('uid', 0) > 0 and home == '/home/' ~ username
    and (rollback or programs_available) %}
{% set safe = namespace(value=supported) %}
{% if supported %}
  {% for path in ['/home', home, home ~ '/.config', home ~ '/.config/autostart'] %}
    {% set st = salt['file.lstat'](path) %}
    {% if (not st and path in ['/home', home])
        or st and (not salt['file.directory_exists'](path) or salt['file.is_link'](path)
        or st.get('st_uid') != (0 if path == '/home' else user.uid)
        or st.get('st_gid') != (0 if path == '/home' else user.gid)
        or salt['file.get_mode'](path) not in ['0700', '0750', '0755']) %}
      {% set safe.value = false %}
    {% endif %}
  {% endfor %}
{% endif %}
{% set apps = {
    'browser': browser ~ ' --class HudQubeBrowser --new-window about:blank',
    'terminal-top': '/usr/bin/xfce4-terminal --disable-server --class=HudQubeTermTop',
    'terminal-bottom': '/usr/bin/xfce4-terminal --disable-server --class=HudQubeTermBottom',
    'files': '/usr/bin/thunar'
} %}
{% set contents = {} %}
{% for app, command in apps.items() %}
  {% set content = '[Desktop Entry]\n# ' ~ marker ~ '\nType=Application\nName=HUD workspace ' ~ app ~ '\nExec=' ~ command ~ '\nTerminal=false\nStartupNotify=false' %}
  {% do contents.update({app: content}) %}
  {% if supported %}
    {% set path = home ~ '/.config/autostart/qubes-hud-workspace-' ~ app ~ '.desktop' %}
    {% set st = salt['file.lstat'](path) %}
    {% set accepted = [content|trim] %}
    {% if rollback and app == 'browser' %}
      {% set accepted = [content|replace(browser, '/usr/bin/firefox')|trim,
          content|replace(browser, '/usr/bin/firefox-esr')|trim] %}
    {% endif %}
    {% if st and (not salt['file.file_exists'](path) or salt['file.is_link'](path)
        or st.get('st_nlink') != 1 or st.get('st_uid') != user.uid or st.get('st_gid') != user.gid
        or salt['file.get_mode'](path) != '0644' or salt['file.read'](path)|trim not in accepted) %}
      {% set safe.value = false %}
    {% endif %}
  {% endif %}
{% endfor %}
{% if not safe.value %}
qubes_gui_hud_qube_guest_refused:
  test.fail_without_changes:
    - name: Expected the selected Linux AppVM, its normal home, stock Firefox/Xfce terminal/Thunar and safe owned autostart paths.
{% elif rollback %}
{% for app in contents %}
qubes_gui_hud_qube_guest_{{ app }}_removed:
  file.absent:
    - name: '{{ home }}/.config/autostart/qubes-hud-workspace-{{ app }}.desktop'
{% endfor %}
{% else %}
{% for path in [home ~ '/.config', home ~ '/.config/autostart'] %}
qubes_gui_hud_qube_guest_directory_{{ loop.index }}:
  file.directory:
    - name: '{{ path }}'
    - user: {{ user.uid }}
    - group: {{ user.gid }}
{% if not salt['file.lstat'](path) %}
    - mode: '0700'
{% endif %}
{% if loop.index == 2 %}
    - require:
      - file: qubes_gui_hud_qube_guest_directory_1
{% endif %}
{% endfor %}

{% for app, content in contents.items() %}
qubes_gui_hud_qube_guest_{{ app }}:
  file.managed:
    - name: '{{ home }}/.config/autostart/qubes-hud-workspace-{{ app }}.desktop'
    - user: {{ user.uid }}
    - group: {{ user.gid }}
    - mode: '0644'
    - contents: {{ content|tojson }}
    - require:
      - file: qubes_gui_hud_qube_guest_directory_2
{% endfor %}
{% endif %}
{% endif %}
