{# Final HUD pair. Stock Fontconfig; no packages or runtime helper here. #}
{% set rollback = font_rollback|default(false) %}
{% set config = salt['pillar.get']('qubes_gui:hud:font', {}) %}
{% set cfg = config if config is mapping else {} %}
{% set family = cfg.get('family', 'Zen Dots') %}
{% set monospace_family = cfg.get('monospace_family', 'White Rabbit') %}
{% set preview_qube = cfg.get('preview_qube', '') %}
{% set marker = 'Qubes HUD managed file. Owner: salt/qubes_gui/hud/font.' %}
{# Keep the original owned path so upgrades need no directory migration. #}
{% set font_root = '/usr/share/qubes-hud-font-trial' %}
{% set owner_file = font_root ~ '/.qubes-hud-owner' %}
{% set owner_text = marker ~ '\n' %}
{% set selector = '/etc/fonts/conf.d/99-qubes-hud-font.conf' %}
{% set browser_text = '// ' ~ marker ~ '\n// Editable default; browser profile choices still take precedence.\npref("browser.display.use_document_fonts", 0);\n' %}
{% set directories = {'Xolonium': 'xolonium', 'Induction': 'induction',
    'Neuropol': 'neuropol', 'Johnny Fever': 'johnny-fever',
    'Zen Dots': 'zen-dots', 'Orbitron': 'orbitron', 'Wallpoet': 'wallpoet',
    'White Rabbit': 'white-rabbit'} %}
{# Entries are source, SHA-256, byte size. None means retired: recognize only
   for safe cleanup, never install. Pins derive from the d94b359 trial state. #}
{% set cc0 = [none,
    'a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499', 7048] %}
{% set fonts = {
    'Xolonium': {
        'Xolonium-Regular.otf': [none,
            'b1a23611ac3730b88fa80f3712ee2e50250f79d5b43cd289979faf4454fd9db4', 215648],
        'Xolonium-Bold.otf': [none,
            '201472d072b25d3d66c8d0018b2f78b20c2c7f85b83c1f462b38975f8c6d3cb3', 217288],
        'Xolonium-LICENSE.txt': [none,
            'ff0ce4c1d38b297d26fd24a4f27d1e650adec94c6b21ed1a981d967ce3c9c51e', 4447]
    },
    'Induction': {
        'Induction.otf': [none,
            'e745deeb0d9d9f49ef60df6a9b5e7723c109809e954a8d1fd120dd66443f75e8', 27164],
        'Typodermic-CC0-1.0.txt': cc0
    },
    'Neuropol': {
        'Neuropol.otf': [none,
            '5b6b7b0536019ebda9c73c48dd1f71ae079a11ae7e3590fd4017f5759f338fc5', 51656],
        'Typodermic-CC0-1.0.txt': cc0
    },
    'Johnny Fever': {
        'Johnny-Fever.otf': [none,
            '95754e0775367dd1415885f6450d4d11d6319497d591b958e2c3e43ca98d0e8a', 29556],
        'Typodermic-CC0-1.0.txt': cc0
    },
    'Zen Dots': {
        'ZenDots-Regular.ttf': ['google-fonts/zen-dots/ZenDots-Regular.ttf',
            '2f81a9f4c26f302d87a40792e048cd7193c886aa50fa6792a4b4fb6266c25609', 37112],
        'OFL.txt': ['google-fonts/zen-dots/OFL.txt',
            '31b461a9de7f5b4ceb988b01d6ce4d9318180394cb5dacff5bf08c557f3cb7a0', 4386]
    },
    'Orbitron': {
        'Orbitron-Variable.ttf': [none,
            'f42db2dd16e642258e35782916eceb1dcdbea06fb958d77ad71dc5963587e8fd', 38576],
        'OFL.txt': [none,
            'ab609b0e110d622435ff337cdf233288556e011bbf9bd0550be98846c0630819', 4426]
    },
    'Wallpoet': {
        'Wallpoet-Regular.ttf': [none,
            '0d8dc36abe195fa455a5a9f60a29f0aa29c7404bf880a67ec71f047dabefb02b', 39904],
        'OFL.txt': [none,
            'bddfe669338d0dbc24c15ccd31dbf5c101a213da38049c24baca9ccb7fde45a4', 4400]
    },
    'White Rabbit': {
        'whitrabt.ttf': ['white-rabbit/whitrabt.ttf',
            '3e845af724f2916d7db7a0565c52c0fcfb0d57ed9615d3640707c6eeb5b1caf7', 13040],
        'license.txt': ['white-rabbit/license.txt',
            '011d4331f5c26da39de77b794243892744f94bcb5fa67aaa273a845ac823e9fa', 1086],
        'whitrabt.txt': ['white-rabbit/whitrabt.txt',
            '8e2c07766aa552604fbd15688f424a318f7993318e3c41ad144d66d2cb7d2a21', 929]
    }
} %}
{# Exact prior selector hashes permit migration without retaining trial XML. #}
{% set selectors = {
    '7cf4f201f0886a835c866d4cdae4da069d22aaaec7f606c9ae5f00f2aaa8a27b': ['Xolonium'],
    '14f13f330c59e4c60c0372a57c0ecec4ac49692706b7251b5dbd535db7c0bbef': ['Xolonium', 'White Rabbit'],
    'd8c7fa52663c7cacca5bb663cc011984e49d7cd9d96992ecfe42a112e6a30f54': ['Induction'],
    'b876812b405c9a4dfb3496bd25e14b4c028377f4a36b854ad1841952cccc9a65': ['Induction', 'White Rabbit'],
    'f2a4507c94ece988988fa7f31f7959cca58b67bcf56bd6ae51e2319ba1170fd5': ['Neuropol'],
    'e869549db6765a6ed8625bb1779dfed74aa67e1f81c8ccbd32c27d068a2eeaed': ['Neuropol', 'White Rabbit'],
    '876fbfb07c6dd25a2c1575d60155f989962e5e087859de38b056b84b3e211df2': ['Johnny Fever'],
    'd3b2a3cb91ceab90503b67af84733c4937d156dff0a18a277cde5e220bc9c4c9': ['Johnny Fever', 'White Rabbit'],
    '0701d73823bdc6cb7a27d674e5b9044d0dedd3a79ddbbe6a1c1357077192c8e1': ['Zen Dots'],
    '9ea0efe661c24a72885284579e0f8f62cf2084b2b796c05bc4e8c8465bfec89a': ['Zen Dots', 'White Rabbit'],
    '2b1955ebba35d9605b2d3be8914401126c38177f6763804e19de4c005326240a': ['Orbitron'],
    '95c01768f001a6da7062f69c17ca324f67d56842ba0d7c59f36df537c4d1186f': ['Orbitron', 'White Rabbit'],
    '90e5d65d5da0b793e7f4986f49beb02729b449437575e79d39cc3a8ab065cd23': ['Wallpoet'],
    '9908288e19e7682bcaa0a71b67707b7fd1b5bf78b92c3b1a26e68322c9b9e473': ['Wallpoet', 'White Rabbit'],
    '08b773621f9713162581f839d67401d9397e870d9be8e88f35e67a42089a99f8': ['White Rabbit'],
    'a3e8ffcac66629337df0490f79d1a9bb5a3e2cf9712fb940fd0b1542b5486e0a': ['White Rabbit', 'White Rabbit']
} %}
{% set known = namespace(files={}, install={}, retired={}) %}
{% for name, files in fonts.items() %}
  {% for filename, asset in files.items() %}
    {% set path = directories[name] ~ '/' ~ filename %}
    {% do known.files.update({path: asset}) %}
    {% if asset[0] %}
      {% do known.install.update({path: asset}) %}
    {% else %}
      {% do known.retired.update({path: asset}) %}
    {% endif %}
  {% endfor %}
{% endfor %}

{% if config is not mapping or family is not string or monospace_family is not string
    or preview_qube is not string %}
qubes_gui_hud_font_invalid:
  test.fail_without_changes:
    - name: Font settings must be a mapping of strings; preview_qube is an optional exact AppVM name.
{% elif not rollback and (family != 'Zen Dots' or monospace_family != 'White Rabbit') %}
qubes_gui_hud_font_choice_retired:
  test.fail_without_changes:
    - name: HUD fonts are now Zen Dots and White Rabbit. Remove obsolete trial family settings.
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
{% set safe = namespace(value=true, files={}, directories={}) %}
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
    {% do safe.directories.update({directory: st}) %}
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
      {% set active_selector = salt['file.get_hash'](selector, 'sha256') %}
      {% if active_selector not in selectors %}{% set safe.value = false %}{% endif %}
      {% for name in selectors.get(active_selector, []) if not rollback %}
        {% for filename in fonts[name] %}
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
{% else %}
{% set cleanup = namespace(files=[], directories=[]) %}
{% for name in (known.files if rollback else known.retired) %}
  {% if safe.files.get(name) %}{% do cleanup.files.append(name) %}{% endif %}
{% endfor %}
{% for name, directory in directories.items() %}
  {% if (rollback or name not in ['Zen Dots', 'White Rabbit']) and safe.directories.get(directory) %}
    {% do cleanup.directories.append(directory) %}
  {% endif %}
{% endfor %}
{% if rollback %}
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
{% for family in ['Zen Dots', 'White Rabbit'] %}
qubes_gui_hud_font_directory_{{ directories[family] }}:
  file.directory:
    - name: {{ font_root }}/{{ directories[family] }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_hud_font_owner
{% endfor %}
{% for name, asset in known.install.items() %}
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
    - name: Apply will verify the staged font SHA-256 values before enabling the HUD pair.
{% else %}
  test.fail_without_changes:
    - name: Font assets must match their pinned SHA-256 before Fontconfig can load them.
{% endif %}
    - require:
{% for name in known.install %}
      - file: qubes_gui_hud_font_asset_{{ loop.index }}
{% endfor %}
{% if not opts.get('test', false) %}
    - unless: |
        /usr/bin/sha256sum --check --strict --status <<'QUBES_HUD_FONT_SHA256'
{% for name, asset in known.install.items() %}
        {{ asset[1] }}  {{ font_root }}/{{ name }}
{% endfor %}
        QUBES_HUD_FONT_SHA256
{% endif %}
qubes_gui_hud_font_selector:
  file.managed:
    - name: {{ selector }}
    - source: salt://qubes_gui/hud/files/fontconfig.conf
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
{% endif %}
{# Select the verified final pair before retiring any previously active files.
   rmdir is nonrecursive. Retain the owned root/marker on rollback so an
   interrupted cleanup never leaves an unmarked directory that blocks retry. #}
{% for name in cleanup.files %}
qubes_gui_hud_font_removed_{{ loop.index }}:
  file.absent:
    - name: {{ font_root }}/{{ name }}
    - require:
      - file: qubes_gui_hud_font_selector{{ '_removed' if rollback else '' }}
{% endfor %}
{% for directory in cleanup.directories %}
qubes_gui_hud_font_directory_removed_{{ directory }}:
  cmd.run:
    - name: /usr/bin/rmdir -- {{ font_root }}/{{ directory }}
    - onlyif: /usr/bin/test -d {{ font_root }}/{{ directory }}
    - require:
      - file: qubes_gui_hud_font_selector{{ '_removed' if rollback else '' }}
{% for name in cleanup.files %}
      - file: qubes_gui_hud_font_removed_{{ loop.index }}
{% endfor %}
{% endfor %}
qubes_gui_hud_font_cache:
  cmd.run:
    - name: /usr/bin/fc-cache --force
    - onchanges:
      - file: qubes_gui_hud_font_selector{{ '_removed' if rollback else '' }}
{% if not rollback %}
{% for name in known.install %}
      - file: qubes_gui_hud_font_asset_{{ loop.index }}
{% endfor %}
{% endif %}
{% for name in cleanup.files %}
      - file: qubes_gui_hud_font_removed_{{ loop.index }}
{% endfor %}
{% for directory in cleanup.directories %}
      - cmd: qubes_gui_hud_font_directory_removed_{{ directory }}
{% endfor %}
{% endif %}
{% endif %}
{% endif %}
