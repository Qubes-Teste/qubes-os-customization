{# Guest-only shared Hermes source/venv; user configuration stays in HOME. #}
{% from 'qubes_gui/templates/family/agent-upstream/map.jinja' import upstream with context %}
{% if not upstream.valid %}
qubes_gui_agent_upstream_hermes_refused:
  test.fail_without_changes:
    - name: Hermes requires the owned Agent template and safe upstream namespace.
{% else %}
{% set pins = upstream.versions %}
{% set hermes = pins.hermes %}
{% set recipe = hermes.version ~ ':' ~ hermes.commit ~ ':' ~ hermes.lock_sha256 ~ ':' ~ pins.uv.sha256 ~ ':' ~ pins.setuptools.sha256 ~ ':' ~ pins.wheel.sha256 %}
{% set recipe_hash = recipe|sha256 %}
{% set directory = upstream.root ~ '/hermes-' ~ hermes.commit[:12] ~ '-' ~ recipe_hash[:12] %}
{% set source = directory ~ '/source' %}
{% set owner = 'Qubes HUD Hermes v1 ' ~ hermes.commit ~ ' ' ~ recipe_hash %}
{% set safe = namespace(value=true) %}
{% for path in ['/usr', '/usr/bin'] %}
  {% set st = salt['file.lstat'](path) %}
  {% if not st or st.get('st_uid') != 0 or st.get('st_gid') != 0 or st.get('st_mode') != 16877 %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% for path in [directory, source, source ~ '/.git', directory ~ '/tools', directory ~ '/.venv', directory ~ '/.salt-owner', directory ~ '/.complete'] %}
  {% set st = salt['file.lstat'](path) %}
  {% set is_file = path in [directory ~ '/.salt-owner', directory ~ '/.complete'] %}
  {% if st and (st.get('st_uid') != 0 or st.get('st_gid') != 0
      or st.get('st_mode') != (33188 if is_file else 16877)
      or (is_file and st.get('st_nlink') != 1)) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% if safe.value and salt['file.directory_exists'](directory) %}
  {% if not salt['file.file_exists'](directory ~ '/.salt-owner')
      or salt['file.read'](directory ~ '/.salt-owner')|trim != owner %}
    {% set safe.value = false %}
  {% endif %}
  {% for name in salt['file.readdir'](directory) %}
    {% if name not in ['.', '..', '.salt-owner', '.complete', 'source', 'tools', '.venv'] %}
      {% set safe.value = false %}
    {% endif %}
  {% endfor %}
{% endif %}
{% if safe.value and salt['file.directory_exists'](directory ~ '/tools') %}
  {% for name in salt['file.readdir'](directory ~ '/tools') %}
    {% if name not in ['.', '..', 'uv', 'uvx'] %}
      {% set safe.value = false %}
    {% elif name in ['uv', 'uvx'] %}
      {% set st = salt['file.lstat'](directory ~ '/tools/' ~ name) %}
      {% if not st or st.get('st_uid') != 0 or st.get('st_gid') != 0
          or st.get('st_mode') != 33261 or st.get('st_nlink') != 1 %}
        {% set safe.value = false %}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endif %}
{% if safe.value and salt['file.directory_exists'](source) %}
  {% set head = salt['cmd.run_all'](['/usr/bin/git', '-C', source, 'rev-parse', 'HEAD'], python_shell=false) %}
  {% set status = salt['cmd.run_all'](['/usr/bin/git', '-C', source, 'status', '--porcelain', '--untracked-files=all'], python_shell=false) %}
  {% if head.retcode != 0 or head.stdout|trim != hermes.commit
      or status.retcode != 0 or status.stdout|trim
      or salt['file.get_hash'](source ~ '/uv.lock', 'sha256') != hermes.lock_sha256 %}
    {% set safe.value = false %}
  {% endif %}
{% endif %}
{% for tool in ['uv', 'setuptools', 'wheel'] %}
  {% set archive = upstream.cache ~ '/' ~ pins[tool].url.split('/')[-1] %}
  {% set st = salt['file.lstat'](archive) %}
  {% if st and (st.get('st_uid') != 0 or st.get('st_gid') != 0
      or st.get('st_mode') not in [33152, 33188] or st.get('st_nlink') != 1) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% set link = salt['file.lstat'](upstream.root ~ '/hermes') %}
{% if link %}
  {% if link.get('st_uid') != 0 or link.get('st_gid') != 0
      or link.get('st_mode') != 41471 or link.get('st_nlink') != 1 %}
    {% set safe.value = false %}
  {% else %}
    {% set previous = salt['file.readlink'](upstream.root ~ '/hermes') %}
    {% set suffix = previous|replace(upstream.root ~ '/hermes-', '', 1) %}
    {% if not previous.startswith(upstream.root ~ '/hermes-') or suffix|length != 25 or suffix[12:13] != '-' %}
      {% set safe.value = false %}
    {% endif %}
    {% for character in suffix|replace('-', '') %}
      {% if character not in '0123456789abcdef' %}{% set safe.value = false %}{% endif %}
    {% endfor %}
  {% endif %}
{% endif %}
{% set launcher = salt['file.lstat']('/usr/bin/hermes') %}
{% if launcher and (launcher.get('st_uid') != 0 or launcher.get('st_gid') != 0
    or launcher.get('st_mode') != 33261 or launcher.get('st_nlink') != 1) %}
  {% set safe.value = false %}
{% elif launcher and '# Qubes HUD shared Hermes launcher v1' not in salt['file.read']('/usr/bin/hermes').splitlines() %}
  {% set safe.value = false %}
{% endif %}
{% if not safe.value %}
qubes_gui_agent_upstream_hermes_paths_refused:
  test.fail_without_changes:
    - name: Refusing an unowned Hermes path, modified checkout or unexpected installation metadata.
{% else %}
qubes_gui_agent_upstream_hermes_directory:
  file.directory:
    - name: {{ directory }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_agent_upstream_root

qubes_gui_agent_upstream_hermes_owner:
  file.managed:
    - name: {{ directory }}/.salt-owner
    - contents: {{ owner }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_agent_upstream_hermes_directory

qubes_gui_agent_upstream_hermes_source:
  cmd.run:
    - name: >-
        /usr/bin/git clone --depth 1 --branch {{ hermes.tag }}
        https://github.com/NousResearch/hermes-agent.git {{ source }}
    - creates: {{ source }}
    - env:
        HTTP_PROXY: {{ upstream.proxy }}
        HTTPS_PROXY: {{ upstream.proxy }}
        GIT_TERMINAL_PROMPT: '0'
        GIT_LFS_SKIP_SMUDGE: '1'
    - timeout: 600
    - require:
      - file: qubes_gui_agent_upstream_hermes_owner
      - pkg: qubes_gui_agent_upstream_packages

{% for tool in ['uv', 'setuptools', 'wheel'] %}
{% set pin = pins[tool] %}
{% set archive = upstream.cache ~ '/' ~ pin.url.split('/')[-1] %}
qubes_gui_agent_upstream_hermes_download_{{ tool }}:
  cmd.run:
    - name: >-
        /usr/bin/curl --fail --location --show-error --silent
        --proxy {{ upstream.proxy }} --connect-timeout 30 --max-time 300
        --output {{ archive }} {{ pin.url }}
    - unless: >-
        /usr/bin/test -f {{ archive }} &&
        /usr/bin/printf '%s\n' '{{ pin.sha256 }}  {{ archive }}' |
        /usr/bin/sha256sum --check --status
    - timeout: 310
    - require:
      - pkg: qubes_gui_agent_upstream_packages
      - file: qubes_gui_agent_upstream_cache
{% endfor %}

{# Check all download/source identities before executing any upstream code. #}
qubes_gui_agent_upstream_hermes_install:
  cmd.run:
    - name: |
        set -eu
        test "$(/usr/bin/git -C {{ source }} rev-parse HEAD)" = '{{ hermes.commit }}'
        test -z "$(/usr/bin/git -C {{ source }} status --porcelain --untracked-files=all)"
        /usr/bin/printf '%s\n' '{{ hermes.lock_sha256 }}  {{ source }}/uv.lock' | /usr/bin/sha256sum --check --status
{% for tool in ['uv', 'setuptools', 'wheel'] %}
        /usr/bin/printf '%s\n' '{{ pins[tool].sha256 }}  {{ upstream.cache }}/{{ pins[tool].url.split('/')[-1] }}' | /usr/bin/sha256sum --check --status
{% endfor %}
        /usr/bin/mkdir -p {{ directory }}/tools
        /usr/bin/unzip -o -j {{ upstream.cache }}/{{ pins.uv.url.split('/')[-1] }} 'uv-{{ pins.uv.version }}.data/scripts/uv' 'uv-{{ pins.uv.version }}.data/scripts/uvx' -d {{ directory }}/tools
        /usr/bin/chmod 0755 {{ directory }}/tools/uv {{ directory }}/tools/uvx
        {{ directory }}/tools/uv sync --frozen --no-dev --extra all --no-install-project
        {{ directory }}/tools/uv pip install --python {{ directory }}/.venv/bin/python --no-deps {{ upstream.cache }}/{{ pins.setuptools.url.split('/')[-1] }} {{ upstream.cache }}/{{ pins.wheel.url.split('/')[-1] }}
        {{ directory }}/tools/uv pip install --python {{ directory }}/.venv/bin/python --no-deps --no-build-isolation -e {{ source }}
        {{ directory }}/tools/uv pip check --python {{ directory }}/.venv/bin/python
        {{ directory }}/.venv/bin/python -B -c 'from importlib.metadata import version; assert version("hermes-agent") == "{{ hermes.version }}"'
    - cwd: {{ source }}
    - cmd_opts_exclude:
      - cwd
    - env:
        HTTP_PROXY: {{ upstream.proxy }}
        HTTPS_PROXY: {{ upstream.proxy }}
        UV_PYTHON_DOWNLOADS: never
        UV_PYTHON: /usr/bin/python3.13
        UV_PROJECT_ENVIRONMENT: {{ directory }}/.venv
        UV_CACHE_DIR: {{ upstream.cache }}/uv
        PYTHONDONTWRITEBYTECODE: '1'
    - unless: >-
        /usr/bin/test -x {{ directory }}/.venv/bin/hermes &&
        /usr/bin/test -f {{ directory }}/.complete &&
        /usr/bin/test "$(/usr/bin/cat {{ directory }}/.complete)" = '{{ recipe }}'
    - timeout: 1800
    - require:
      - cmd: qubes_gui_agent_upstream_hermes_source
{% for tool in ['uv', 'setuptools', 'wheel'] %}
      - cmd: qubes_gui_agent_upstream_hermes_download_{{ tool }}
{% endfor %}

qubes_gui_agent_upstream_hermes_complete:
  file.managed:
    - name: {{ directory }}/.complete
    - contents: {{ recipe }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: qubes_gui_agent_upstream_hermes_install

qubes_gui_agent_upstream_hermes_current:
  file.symlink:
    - name: {{ upstream.root }}/hermes
    - target: {{ directory }}
    - user: root
    - group: root
    - require:
      - file: qubes_gui_agent_upstream_hermes_complete

qubes_gui_agent_upstream_hermes_launcher:
  file.managed:
    - name: /usr/bin/hermes
    - source: salt://qubes_gui/templates/family/agent-upstream/files/hermes
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_agent_upstream_hermes_current
{% endif %}
{% endif %}
