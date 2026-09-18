{# Native login/session environment; no private AppVM software copies. #}
{% from 'qubes_gui/templates/family/agent-upstream/map.jinja' import upstream with context %}
{% set profile = '/etc/profile.d/qubes-hud-agent.sh' %}
{% set xsession = '/etc/X11/Xsession.d/40qubes_hud_agent' %}
{% set config = '/etc/skel/.openclaw/openclaw.json' %}
{% set safe = namespace(value=upstream.valid) %}
{% if safe.value %}
{% for path in ['/etc', '/etc/profile.d', '/etc/X11', '/etc/X11/Xsession.d', '/etc/skel', '/etc/skel/.openclaw'] %}
  {% set st = salt['file.lstat'](path) %}
  {% if (not st and path != '/etc/skel/.openclaw') or (st and (
      st.get('st_mode') not in [16877, 16832] or st.get('st_uid') != 0 or st.get('st_gid') != 0)) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% for path in [profile, xsession, config] %}
  {% set st = salt['file.lstat'](path) %}
  {% if st %}
    {% if st.get('st_uid') != 0 or st.get('st_gid') != 0 or st.get('st_nlink') != 1
        or st.get('st_mode') not in [33188, 33152] %}
      {% set safe.value = false %}
    {% elif path == config %}
      {% if salt['file.get_hash'](path, 'sha256') != 'e28d453421257b53f2d0d7453af4062a153186ed58dea5012ab8d3fade93677c' %}
        {% set safe.value = false %}
      {% endif %}
    {% elif upstream.owner not in salt['file.read'](path) %}
      {% set safe.value = false %}
    {% endif %}
  {% endif %}
{% endfor %}
{% endif %}
{% if not safe.value %}
qubes_gui_agent_upstream_environment_refused:
  test.fail_without_changes:
    - name: Refusing unsafe or locally owned Agent environment/default configuration.
{% else %}
qubes_gui_agent_upstream_profile:
  file.managed:
    - name: {{ profile }}
    - source: salt://qubes_gui/templates/family/agent-upstream/files/agent-environment.sh
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - sls: qubes_gui.templates.family.agent-upstream.node-npm
      - sls: qubes_gui.templates.family.agent-upstream.hermes
      - sls: qubes_gui.templates.family.agent-upstream.signal

qubes_gui_agent_upstream_xsession:
  file.managed:
    - name: {{ xsession }}
    - contents: |
        # Qubes HUD Agent upstream software v1
        . /etc/profile.d/qubes-hud-agent.sh
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_agent_upstream_profile

qubes_gui_agent_upstream_openclaw_skel:
  file.directory:
    - name: /etc/skel/.openclaw
    - user: root
    - group: root
    - mode: '0700'

qubes_gui_agent_upstream_openclaw_default:
  file.managed:
    - name: {{ config }}
    - source: salt://qubes_gui/templates/family/agent-upstream/files/openclaw.json
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: qubes_gui_agent_upstream_openclaw_skel
      - sls: qubes_gui.templates.family.agent-upstream.node-npm
{% endif %}
