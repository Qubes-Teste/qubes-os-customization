{# Third-party software runs and downloads only inside the owned Agent guest. #}
{% from 'qubes_gui/templates/family/agent-upstream/map.jinja' import upstream with context %}
{% if not upstream.valid %}
qubes_gui_agent_upstream_scope_refused:
  test.fail_without_changes:
    - name: Upstream software requires the owned Debian Agent TemplateVM and safe paths.
{% else %}
include:
  - qubes_gui.templates.family.agent-upstream.environment
  - qubes_gui.templates.family.agent-upstream.node-npm
  - qubes_gui.templates.family.agent-upstream.hermes
  - qubes_gui.templates.family.agent-upstream.signal

qubes_gui_agent_upstream_packages:
  pkg.installed:
    - pkgs:
      - ca-certificates
      - curl
      - xz-utils
      - unzip
      - git
      - python3
      - python3-venv
      - build-essential
      - zlib1g
    - install_recommends: false

{% for key, path in [('root', upstream.root), ('cache', upstream.cache)] %}
qubes_gui_agent_upstream_{{ key }}:
  file.directory:
    - name: {{ path }}
    - user: root
    - group: root
    - mode: '0755'

qubes_gui_agent_upstream_{{ key }}_owner:
  file.managed:
    - name: {{ path }}/.salt-owner
    - contents: {{ upstream.owner|tojson }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_agent_upstream_{{ key }}
    - require_in:
      - sls: qubes_gui.templates.family.agent-upstream.node-npm
      - sls: qubes_gui.templates.family.agent-upstream.hermes
      - sls: qubes_gui.templates.family.agent-upstream.signal
{% endfor %}
{% endif %}
