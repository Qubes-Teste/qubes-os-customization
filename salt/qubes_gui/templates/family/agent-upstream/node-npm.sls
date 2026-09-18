{# Official Node LTS plus a complete npm integrity lock. No global npm prefix. #}
{% from 'qubes_gui/templates/family/agent-upstream/map.jinja' import upstream with context %}
{% import_json 'qubes_gui/templates/family/agent-upstream/files/package-lock.json' as lock %}
{% import_text 'qubes_gui/templates/family/agent-upstream/files/package-lock.json' as lock_text %}
{% set lock_hash = (lock_text ~ (upstream.versions.npm|tojson))|sha256 %}
{% set node = upstream.versions.node %}
{% set root = upstream.root %}
{% set node_dir = root ~ '/node-v' ~ node.version ~ '-linux-x64' %}
{% set npm_dir = root ~ '/npm-' ~ node.version ~ '-' ~ lock_hash[:16] %}
{% set archive = upstream.cache ~ '/node-' ~ node.version ~ '.tar.xz' %}
{% set safe = namespace(value=upstream.valid and lock.get('lockfileVersion') == 3
    and lock.get('packages', {}).get('', {}).get('dependencies') == upstream.versions.npm.dependencies) %}
{% if safe.value %}
{% for path in [node_dir, npm_dir, archive] %}
  {% set st = salt['file.lstat'](path) %}
  {% if st and (st.get('st_uid') != 0 or st.get('st_gid') != 0
      or (path != archive and st.get('st_mode') != 16877)
      or (path == archive and (st.get('st_mode') != 33188 or st.get('st_nlink') != 1))) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% for path, modes in [(node_dir ~ '/bin', [16877]), (node_dir ~ '/bin/node', [33261]),
    (npm_dir ~ '/package.json', [33188]), (npm_dir ~ '/package-lock.json', [33188]),
    (npm_dir ~ '/.salt-complete', [33188]), (npm_dir ~ '/node_modules', [16877])] %}
  {% set st = salt['file.lstat'](path) %}
  {% if st and (st.get('st_uid') != 0 or st.get('st_gid') != 0
      or st.get('st_mode') not in modes or (16877 not in modes and st.get('st_nlink') != 1)) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% for name, prefix in [('node', root ~ '/node-v'), ('npm', root ~ '/npm-')] %}
  {% set path = root ~ '/' ~ name %}
  {% set st = salt['file.lstat'](path) %}
  {% if st %}
    {% if st.get('st_mode') != 41471 or st.get('st_uid') != 0 or st.get('st_gid') != 0 %}
      {% set safe.value = false %}
    {% else %}
      {% set target = salt['file.readlink'](path) %}
      {% if not target.startswith(prefix) or '/' in target|replace(prefix, '', 1)
          or '..' in target|replace(prefix, '', 1) %}
        {% set safe.value = false %}
      {% endif %}
    {% endif %}
  {% endif %}
{% endfor %}
{% endif %}
{% if not safe.value %}
qubes_gui_agent_upstream_node_npm_refused:
  test.fail_without_changes:
    - name: Refusing upstream software outside Agent, unsafe paths or inconsistent npm pins/lock.
{% else %}
qubes_gui_agent_upstream_node_download:
  cmd.run:
    - name: >-
        /usr/bin/curl --fail --location --show-error --silent
        --proxy {{ upstream.proxy }} --connect-timeout 30 --max-time 300
        --output {{ archive }} {{ node.url }}
    - unless: >-
        /usr/bin/test -f {{ archive }} &&
        /usr/bin/printf '%s\n' '{{ node.sha256 }}  {{ archive }}' |
        /usr/bin/sha256sum --check --status
    - timeout: 310
    - require:
      - pkg: qubes_gui_agent_upstream_packages
      - file: qubes_gui_agent_upstream_cache

{# A fresh test run cannot inspect an archive whose download is only planned. #}
{% set extraction = 'test' if opts.get('test', false) and not salt['file.file_exists'](archive) else 'archive' %}
qubes_gui_agent_upstream_node_extract:
{% if extraction == 'test' %}
  test.nop:
    - name: Would verify and extract the pinned archive after its guest-only download.
    - require:
      - cmd: qubes_gui_agent_upstream_node_download
{% else %}
  archive.extracted:
    - name: {{ root }}
    - source: {{ archive }}
    - source_hash: sha256={{ node.sha256 }}
    - if_missing: {{ node_dir }}/bin/node
    - user: root
    - group: root
    - require:
      - file: qubes_gui_agent_upstream_root
      - cmd: qubes_gui_agent_upstream_node_download

{% endif %}

qubes_gui_agent_upstream_node_check:
  cmd.run:
    - name: /usr/bin/test "$({{ node_dir }}/bin/node --version)" = v{{ node.version }}
    - onchanges:
      - {{ extraction }}: qubes_gui_agent_upstream_node_extract

qubes_gui_agent_upstream_node_current:
  file.symlink:
    - name: {{ root }}/node
    - target: {{ node_dir }}
    - user: root
    - group: root
    - require:
      - cmd: qubes_gui_agent_upstream_node_check
      - {{ extraction }}: qubes_gui_agent_upstream_node_extract

qubes_gui_agent_upstream_npm_directory:
  file.directory:
    - name: {{ npm_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_agent_upstream_root

qubes_gui_agent_upstream_npm_manifest:
  file.managed:
    - name: {{ npm_dir }}/package.json
    - contents: {{ {'name': 'qubes-hud-agent-tools', 'version': '1.0.0', 'private': true, 'dependencies': upstream.versions.npm.dependencies, 'allowScripts': upstream.versions.npm.allowScripts}|tojson|tojson }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_agent_upstream_npm_directory

qubes_gui_agent_upstream_npm_lock:
  file.managed:
    - name: {{ npm_dir }}/package-lock.json
    - source: salt://qubes_gui/templates/family/agent-upstream/files/package-lock.json
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_agent_upstream_npm_directory

qubes_gui_agent_upstream_npm_install:
  cmd.run:
    - name: >-
        {{ node_dir }}/bin/npm ci --omit=dev --no-audit --no-fund &&
        {{ node_dir }}/bin/node node_modules/@openai/codex/bin/codex.js --version &&
        {{ node_dir }}/bin/node node_modules/openclaw/openclaw.mjs --version &&
        /usr/bin/touch .salt-complete
    - cwd: {{ npm_dir }}
    - env:
        PATH: {{ node_dir }}/bin:/usr/sbin:/usr/bin:/sbin:/bin
        HTTP_PROXY: {{ upstream.proxy }}
        HTTPS_PROXY: {{ upstream.proxy }}
        http_proxy: {{ upstream.proxy }}
        https_proxy: {{ upstream.proxy }}
        NODE_USE_ENV_PROXY: '1'
        npm_config_update_notifier: 'false'
    - timeout: 1200
    - creates: {{ npm_dir }}/.salt-complete
    - require:
      - file: qubes_gui_agent_upstream_npm_manifest
      - file: qubes_gui_agent_upstream_npm_lock
      - file: qubes_gui_agent_upstream_node_current

qubes_gui_agent_upstream_npm_current:
  file.symlink:
    - name: {{ root }}/npm
    - target: {{ npm_dir }}
    - user: root
    - group: root
    - require:
      - cmd: qubes_gui_agent_upstream_npm_install
{% endif %}
