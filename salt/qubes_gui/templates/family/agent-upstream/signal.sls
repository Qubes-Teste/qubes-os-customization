{# Guest-only pinned native signal-cli; no JVM, account or service setup. #}
{% from 'qubes_gui/templates/family/agent-upstream/map.jinja' import upstream with context %}
{% if not upstream.valid %}
qubes_gui_agent_upstream_signal_refused:
  test.fail_without_changes:
    - name: signal-cli requires the owned Agent template and safe upstream namespace.
{% else %}
{% set signal = upstream.versions.signal %}
{% set directory = upstream.root ~ '/signal-' ~ signal.version %}
{% set archive = '/var/cache/qubes-hud-agent/signal-' ~ signal.version ~ '.tar.gz' %}
{% set safe = namespace(value=true) %}
{% for path in [directory, archive, directory ~ '/signal-cli'] %}
  {% set st = salt['file.lstat'](path) %}
  {% if st and (st.get('st_uid') != 0 or st.get('st_gid') != 0
      or (path == directory and st.get('st_mode') != 16877)
      or (path != directory and (st.get('st_mode') not in
          ([33152, 33188] if path == archive else [33261])
          or st.get('st_nlink') != 1))) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% if safe.value and salt['file.directory_exists'](directory) %}
  {% for name in salt['file.readdir'](directory) %}
    {% if name not in ['.', '..', 'signal-cli'] %}
      {% set safe.value = false %}
    {% endif %}
  {% endfor %}
{% endif %}
{% if safe.value and salt['file.file_exists'](directory ~ '/signal-cli')
    and salt['file.get_hash'](directory ~ '/signal-cli', 'sha256') != signal.binary_sha256 %}
  {% set safe.value = false %}
{% endif %}
{% set link = salt['file.lstat'](upstream.root ~ '/signal') %}
{% if link %}
  {% if link.get('st_mode') != 41471 or link.get('st_uid') != 0
      or link.get('st_gid') != 0 or link.get('st_nlink') != 1 %}
    {% set safe.value = false %}
  {% elif safe.value %}
    {% set target = salt['file.readlink'](upstream.root ~ '/signal') %}
    {% set previous = target|replace(upstream.root ~ '/signal-', '', 1) %}
    {% if not target.startswith(upstream.root ~ '/signal-')
        or previous.split('.')|length not in [2, 3, 4] %}
      {% set safe.value = false %}
    {% endif %}
    {% for part in previous.split('.') %}
      {% if not part.isdigit() %}{% set safe.value = false %}{% endif %}
    {% endfor %}
  {% endif %}
{% endif %}
{% if not safe.value %}
qubes_gui_agent_upstream_signal_paths_refused:
  test.fail_without_changes:
    - name: Refusing unexpected signal-cli archive or installation metadata/content.
{% else %}
qubes_gui_agent_upstream_signal_directory:
  file.directory:
    - name: {{ directory }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: qubes_gui_agent_upstream_root

qubes_gui_agent_upstream_signal_download:
  cmd.run:
    - name: >-
        /usr/bin/curl --fail --location --show-error --silent
        --proxy {{ upstream.proxy }} --connect-timeout 30 --max-time 300
        --output {{ archive }} {{ signal.url }}
    - unless: >-
        /usr/bin/test -f {{ archive }} &&
        /usr/bin/printf '%s\n' '{{ signal.sha256 }}  {{ archive }}' |
        /usr/bin/sha256sum --check --status
    - timeout: 310
    - require:
      - pkg: qubes_gui_agent_upstream_packages
      - file: qubes_gui_agent_upstream_cache

{# A fresh test run cannot inspect an archive whose download is only planned. #}
{% set extraction = 'test' if opts.get('test', false) and not salt['file.file_exists'](archive) else 'archive' %}
qubes_gui_agent_upstream_signal_extract:
{% if extraction == 'test' %}
  test.nop:
    - name: Would verify and extract the pinned archive after its guest-only download.
    - require:
      - cmd: qubes_gui_agent_upstream_signal_download
{% else %}
  archive.extracted:
    - name: {{ directory }}
    - source: {{ archive }}
    - source_hash: sha256={{ signal.sha256 }}
    - enforce_toplevel: false
    - if_missing: {{ directory }}/signal-cli
    - user: root
    - group: root
    - require:
      - file: qubes_gui_agent_upstream_signal_directory
      - cmd: qubes_gui_agent_upstream_signal_download

{% endif %}

qubes_gui_agent_upstream_signal_check:
  cmd.run:
    - name: {{ directory }}/signal-cli --version
    - timeout: 30
    - onchanges:
      - {{ extraction }}: qubes_gui_agent_upstream_signal_extract

qubes_gui_agent_upstream_signal_current:
  file.symlink:
    - name: {{ upstream.root }}/signal
    - target: {{ directory }}
    - user: root
    - group: root
    - require:
      - {{ extraction }}: qubes_gui_agent_upstream_signal_extract
      - cmd: qubes_gui_agent_upstream_signal_check
{% endif %}
{% endif %}
