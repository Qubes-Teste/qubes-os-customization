{# Optional native font trial. Default no-op; no packages or runtime helper. #}
{% set rollback = font_rollback|default(false) %}
{% set config = salt['pillar.get']('qubes_gui:hud:font', {}) %}
{% set cfg = config if config is mapping else {} %}
{% set family = cfg.get('family', '') %}
{% set preview_qube = cfg.get('preview_qube', '') %}
{% set marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud/font.' %}
{% set font_root = '/usr/share/qubes-hud-font-trial' %}
{% set owner_file = font_root ~ '/.qubes-hud-owner' %}
{% set owner_text = marker ~ '\n' %}
{% set selector = '/etc/fonts/conf.d/99-qubes-hud-font.conf' %}
{% set browser_text = '// ' ~ marker ~ '\n// Editable default; browser profile choices still take precedence.\npref("browser.display.use_document_fonts", 0);\n' %}
{% set directories = {'Xolonium': 'xolonium', 'Induction': 'induction',
    'Neuropol': 'neuropol', 'Johnny Fever': 'johnny-fever'} %}
{# Each fixed entry is source path, SHA-256, byte size. Keep old entries when
   adding a family so its installed files remain verifiable during switching. #}
{% set cc0 = ['typodermic-cc0/CC0-1.0.txt',
    'a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499', 7048] %}
{% set fonts = {
    'Xolonium': {
        'Xolonium-Regular.otf': ['xolonium/Xolonium-Regular.otf',
            'b1a23611ac3730b88fa80f3712ee2e50250f79d5b43cd289979faf4454fd9db4', 215648],
        'Xolonium-Bold.otf': ['xolonium/Xolonium-Bold.otf',
            '201472d072b25d3d66c8d0018b2f78b20c2c7f85b83c1f462b38975f8c6d3cb3', 217288],
        'Xolonium-LICENSE.txt': ['xolonium/LICENSE.txt',
            'ff0ce4c1d38b297d26fd24a4f27d1e650adec94c6b21ed1a981d967ce3c9c51e', 4447]
    },
    'Induction': {
        'Induction.otf': ['typodermic-cc0/Induction.otf',
            'e745deeb0d9d9f49ef60df6a9b5e7723c109809e954a8d1fd120dd66443f75e8', 27164],
        'Typodermic-CC0-1.0.txt': cc0
    },
    'Neuropol': {
        'Neuropol.otf': ['typodermic-cc0/Neuropol.otf',
            '5b6b7b0536019ebda9c73c48dd1f71ae079a11ae7e3590fd4017f5759f338fc5', 51656],
        'Typodermic-CC0-1.0.txt': cc0
    },
    'Johnny Fever': {
        'Johnny-Fever.otf': ['typodermic-cc0/Johnny-Fever.otf',
            '95754e0775367dd1415885f6450d4d11d6319497d591b958e2c3e43ca98d0e8a', 29556],
        'Typodermic-CC0-1.0.txt': cc0
    }
} %}
{% macro font_config(name) -%}
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- {{ marker }} -->
<fontconfig>
  <dir>{{ font_root }}/{{ directories[name] }}</dir>
  <match target="pattern">
    <test name="family" qual="first" compare="not_contains"><string>Symbol</string></test>
    <test name="family" qual="first" compare="not_contains"><string>Emoji</string></test>
    <test name="family" qual="first" compare="not_contains"><string>Awesome</string></test>
    <test name="family" qual="first" compare="not_contains"><string>Icon</string></test>
    <test name="family" qual="first" compare="not_contains"><string>Dingbat</string></test>
    <test name="family" qual="first" compare="not_contains"><string>D050000L</string></test>
    <edit name="family" mode="prepend_first" binding="strong"><string>{{ name }}</string></edit>
  </match>
</fontconfig>
{%- endmacro %}
{% set known = namespace(files={}, selectors=[]) %}
{% for name, files in fonts.items() %}
  {% for filename, asset in files.items() %}
    {% do known.files.update({directories[name] ~ '/' ~ filename: asset}) %}
  {% endfor %}
  {% do known.selectors.append(font_config(name) ~ '\n') %}
{% endfor %}

{% if config is not mapping or family is not string or preview_qube is not string %}
qubes_gui_hud_font_invalid:
  test.fail_without_changes:
    - name: Set a font family and optional preview_qube as strings under qubes_gui:hud:font.
{% elif not family %}
qubes_gui_hud_font_disabled:
  test.nop:
    - name: No optional HUD font trial selected.
{% elif family not in fonts %}
qubes_gui_hud_font_unknown:
  test.fail_without_changes:
    - name: The selected font family has no committed and verified trial assets.
{% else %}
{% set release = grains.get('osrelease', '')|string %}
{% set dom0 = grains.get('virtual') == 'Qubes'
    and grains.get('virtual_subtype') == 'Xen Dom0'
    and (release == '4.3' or release.startswith('4.3.')) %}
{% set qubesdb = '/usr/bin/qubesdb-read' %}
{% set has_qubesdb = not dom0 and salt['file.file_exists'](qubesdb) %}
{% set vm_type = salt['cmd.run'](qubesdb ~ ' /qubes-vm-type',
    python_shell=false, ignore_retcode=true)|trim
    if has_qubesdb else '' %}
{% set vm_name = salt['cmd.run'](qubesdb ~ ' /name',
    python_shell=false, ignore_retcode=true)|trim
    if preview_qube and has_qubesdb else '' %}
{% set guest = grains.get('virtual', '')|lower == 'xen'
    and (grains.get('os_family') == 'Debian' or grains.get('os') == 'Fedora')
    and ((not preview_qube and vm_type == 'TemplateVM')
         or (preview_qube and vm_type == 'AppVM' and preview_qube == vm_name)) %}
{% if grains.get('kernel') != 'Linux' or not ((dom0 and not preview_qube) or guest) %}
qubes_gui_hud_font_target_refused:
  test.fail_without_changes:
    - name: Select Qubes 4.3 dom0, a supported TemplateVM, or an explicitly named AppVM preview.
{% else %}
{# Native lstat st_mode includes type and special bits: directory 0755=16877,
   directory 0555=16749, regular file 0644=33188. Exact equality also rejects
   symlinks, devices, sockets and special permission bits in one local check. #}
{% set safe = namespace(value=true, files={}) %}
{% for path in ['/', '/usr', '/usr/share', '/etc', '/etc/fonts', '/etc/fonts/conf.d'] %}
  {% set st = salt['file.lstat'](path) %}
  {% if not st or st.get('st_uid') != 0 or st.get('st_gid') != 0
      or st.get('st_mode') not in ([16749, 16877] if path == '/' else [16877]) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% set root_stat = salt['file.lstat'](font_root) if safe.value else {} %}
{% if root_stat and (root_stat.get('st_mode') != 16877 or root_stat.get('st_uid') != 0
    or root_stat.get('st_gid') != 0) %}
  {% set safe.value = false %}
{% endif %}
{% if root_stat and safe.value %}
  {% set st = salt['file.lstat'](owner_file) %}
  {% if not st or st.get('st_mode') != 33188 or st.get('st_uid') != 0
      or st.get('st_gid') != 0 or st.get('st_nlink') != 1 or st.get('st_size') != owner_text|length
      or salt['file.read'](owner_file) != owner_text %}
    {% set safe.value = false %}
  {% endif %}
  {% for name in salt['file.readdir'](font_root) %}
    {% if name not in ['.', '..', '.qubes-hud-owner'] and name not in directories.values() %}
      {% set safe.value = false %}
    {% endif %}
  {% endfor %}
  {% for name, directory in directories.items() %}
    {% set path = font_root ~ '/' ~ directory %}
    {% set st = salt['file.lstat'](path) %}
    {% if st %}
      {% if st.get('st_mode') != 16877 or st.get('st_uid') != 0 or st.get('st_gid') != 0 %}
        {% set safe.value = false %}
      {% else %}
        {% for filename in salt['file.readdir'](path) %}
          {% if filename not in ['.', '..'] and filename not in fonts[name] %}
            {% set safe.value = false %}
          {% endif %}
        {% endfor %}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endif %}
{% if safe.value %}
  {% for name, asset in known.files.items() %}
    {% set path = font_root ~ '/' ~ name %}
    {% set st = salt['file.lstat'](path) %}
    {% do safe.files.update({name: st}) %}
    {% if st and (st.get('st_mode') != 33188 or st.get('st_uid') != 0
        or st.get('st_gid') != 0 or st.get('st_nlink') != 1 or st.get('st_size') != asset[2]
        or salt['file.get_hash'](path, 'sha256') != asset[1]) %}
      {% set safe.value = false %}
    {% endif %}
  {% endfor %}
  {% set st = salt['file.lstat'](selector) %}
  {% if st %}
    {% if st.get('st_mode') != 33188 or st.get('st_uid') != 0 or st.get('st_gid') != 0
        or st.get('st_nlink') != 1 or st.get('st_size', 0) > 8192 %}
      {% set safe.value = false %}
    {% else %}
      {% set active_selector = salt['file.read'](selector) %}
      {% if active_selector not in known.selectors %}{% set safe.value = false %}{% endif %}
      {% for name, files in fonts.items() if not rollback and active_selector == font_config(name) ~ '\n' %}
        {% for filename in files %}
          {% if not safe.files.get(directories[name] ~ '/' ~ filename) %}
            {% set safe.value = false %}
          {% endif %}
        {% endfor %}
      {% endfor %}
    {% endif %}
  {% endif %}
{% endif %}
{# Ordinary distribution Firefox only; never enter Tor Browser or a profile. #}
{% set package = 'firefox-esr' if grains.get('os_family') == 'Debian' else 'firefox' %}
{% set libdir = '/usr/lib' if package == 'firefox-esr' else '/usr/lib64' %}
{% set browser_root = libdir ~ '/' ~ package %}
{% set browser_pref = browser_root ~ '/defaults/pref/qubes-hud-font.js' %}
{% set browser = namespace(enabled=false) %}
{% if guest and safe.value %}
  {% set installed = salt['pkg.version'](package) if not rollback else '' %}
  {% set browser_stat = salt['file.lstat'](browser_pref) %}
  {% set browser.enabled = installed or browser_stat %}
  {% if browser.enabled %}
    {% for path in [libdir, browser_root, browser_root ~ '/defaults', browser_root ~ '/defaults/pref'] %}
      {% set st = salt['file.lstat'](path) %}
      {% if not st or st.get('st_mode') != 16877 or st.get('st_uid') != 0 or st.get('st_gid') != 0 %}
        {% set safe.value = false %}
      {% endif %}
    {% endfor %}
    {% set st = browser_stat if safe.value else {} %}
    {% if st and (st.get('st_mode') != 33188 or st.get('st_uid') != 0
        or st.get('st_gid') != 0 or st.get('st_nlink') != 1 or st.get('st_size') != browser_text|length
        or salt['file.read'](browser_pref) != browser_text) %}
      {% set safe.value = false %}
    {% endif %}
    {% if safe.value %}
      {% set query = ['/usr/bin/dpkg-query', '--search'] if package == 'firefox-esr'
          else ['/usr/bin/rpm', '--query', '--whatprovides', '--queryformat', '%{NAME}'] %}
      {% set owner = salt['cmd.run_all'](query + [browser_pref],
          python_shell=false, ignore_retcode=true, env={'LC_ALL': 'C'}) %}
      {% if owner.get('retcode') != 1 %}{% set safe.value = false %}{% endif %}
      {% if installed %}
        {% set channel = salt['cmd.run_all'](query + [browser_root ~ '/defaults/pref/channel-prefs.js'],
            python_shell=false, ignore_retcode=true, env={'LC_ALL': 'C'}) %}
        {% if channel.get('retcode') != 0 or channel.get('stdout', '').split(':', 1)[0]|trim != package %}
          {% set safe.value = false %}
        {% endif %}
      {% endif %}
    {% endif %}
  {% endif %}
{% endif %}
{% if not safe.value %}
qubes_gui_hud_font_collision:
  test.fail_without_changes:
    - name: Refusing unsafe font paths or unknown or modified owned files.
{% elif not salt['file.file_exists']('/usr/bin/fc-cache') %}
qubes_gui_hud_font_runtime_missing:
  test.fail_without_changes:
    - name: The stock desktop Fontconfig cache utility is required; no package is installed by this state.
{% elif rollback %}
{% if browser.enabled %}
qubes_gui_hud_font_browser_removed:
  file.absent:
    - name: {{ browser_pref }}
{% endif %}
qubes_gui_hud_font_selector_removed:
  file.absent:
    - name: {{ selector }}
{% if browser.enabled %}
    - require:
      - file: qubes_gui_hud_font_browser_removed
{% endif %}
{% for name in known.files %}
qubes_gui_hud_font_removed_{{ loop.index }}:
  file.absent:
    - name: {{ font_root }}/{{ name }}
    - require:
      - file: qubes_gui_hud_font_selector_removed
{% endfor %}
qubes_gui_hud_font_cache:
  cmd.run:
    - name: /usr/bin/fc-cache --force
    - onchanges:
      - file: qubes_gui_hud_font_selector_removed
{% for name in known.files %}
      - file: qubes_gui_hud_font_removed_{{ loop.index }}
{% endfor %}
{% else %}
qubes_gui_hud_font_owner:
  file.managed:
    - name: {{ owner_file }}
    - contents: {{ owner_text|tojson }}
    - user: root
    - group: root
    - mode: '0644'
    - dir_mode: '0755'
    - makedirs: true
{% for directory in directories.values() %}
qubes_gui_hud_font_directory_{{ directory }}:
  file.directory:
    - name: {{ font_root }}/{{ directory }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_font_owner
{% endfor %}
{% for name, asset in known.files.items() %}
qubes_gui_hud_font_asset_{{ loop.index }}:
  file.managed:
    - name: {{ font_root }}/{{ name }}
    - source: salt://qubes_gui/hud/files/fonts/{{ asset[0] }}
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: false
    - replace: false
    - require:
      - file: qubes_gui_hud_font_directory_{{ name.split('/')[0] }}
{% endfor %}
qubes_gui_hud_font_hashes:
{% if opts.get('test', false) %}
  test.nop:
    - name: Apply will verify the staged font SHA-256 values before enabling the selected family.
{% else %}
  test.fail_without_changes:
    - name: Font assets must match their pinned SHA-256 before Fontconfig can load them.
{% endif %}
    - require:
{% for name in known.files %}
      - file: qubes_gui_hud_font_asset_{{ loop.index }}
{% endfor %}
{% if not opts.get('test', false) %}
    - unless:
{% for name, asset in known.files.items() %}
      - fun: file.file_exists
        path: {{ font_root }}/{{ name }}
      - fun: file.check_hash
        path: {{ font_root }}/{{ name }}
        file_hash: sha256={{ asset[1] }}
{% endfor %}
{% endif %}
qubes_gui_hud_font_selector:
  file.managed:
    - name: {{ selector }}
    - contents: {{ (font_config(family) ~ '\n')|tojson }}
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: false
    - require:
      - test: qubes_gui_hud_font_hashes
{% if browser.enabled %}
qubes_gui_hud_font_browser:
  file.managed:
    - name: {{ browser_pref }}
    - contents: {{ browser_text|tojson }}
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: false
    - require:
      - file: qubes_gui_hud_font_selector
{% endif %}
qubes_gui_hud_font_cache:
  cmd.run:
    - name: /usr/bin/fc-cache --force
    - onchanges:
      - file: qubes_gui_hud_font_selector
{% for name in known.files %}
      - file: qubes_gui_hud_font_asset_{{ loop.index }}
{% endfor %}
{% endif %}
{% endif %}
{% endif %}
