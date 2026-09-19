{# qubesctl creates dom0 targets before resolving its guest target list. #}
{% from 'qubes_gui/templates/family/map.jinja' import family with context %}
{% set dom0 = grains.get('virtual') == 'Qubes'
    and grains.get('virtual_subtype') == 'Xen Dom0' %}
{% set supported_dom0 = dom0 and grains.get('kernel') == 'Linux'
    and grains.get('osrelease')|string == '4.3'
    and grains.get('cpuarch') == 'x86_64' %}

{% if not family.valid %}
qubes_gui_template_family_invalid_names:
  test.fail_without_changes:
    - name: >-
        Family source and three target names must be distinct Qubes names:
        1-31 letters, digits, dots, underscores or hyphens, starting with a
        letter; reserved names and the -dm suffix are refused.

{% elif supported_dom0 %}
{% set status = namespace(valid=true, present={}, features={}) %}
{% for role, name in family.names.items() %}
  {% set present = salt['cmd.retcode'](
      ['/usr/bin/qvm-check', '--quiet', name],
      python_shell=false, ignore_retcode=true) == 0 %}
  {% do status.present.update({role: present}) %}
  {% if present %}
    {% set vm_state = salt['cmd.run'](
        ['/usr/bin/qvm-ls', '--raw-data', '--fields', 'CLASS,STATE', name],
        python_shell=false, ignore_retcode=true)|trim %}
    {% set tags = salt['cmd.run'](
        ['/usr/bin/qvm-tags', name, 'list'],
        python_shell=false, ignore_retcode=true).splitlines() %}
    {% set features = {} %}
    {% for line in salt['cmd.run'](
        ['/usr/bin/qvm-features', name],
        python_shell=false, ignore_retcode=true).splitlines() %}
      {% set fields = line.split(None, 1) %}
      {% if fields %}{% do features.update({fields[0]: fields[1]|trim if fields|length == 2 else ''}) %}{% endif %}
    {% endfor %}
    {% do status.features.update({role: features}) %}
    {% if vm_state != 'TemplateVM|Halted' or family.tag not in tags
        or features.get(family.feature_prefix ~ 'name') != name
        or features.get(family.feature_prefix ~ 'role') != role
        or features.get(family.feature_prefix ~ 'source') != family.parents[role] %}
      {% set status.valid = false %}
    {% endif %}
  {% endif %}
{% endfor %}
{% if not status.present['base'] %}
  {% set source_state = salt['cmd.run'](
      ['/usr/bin/qvm-ls', '--raw-data', '--fields', 'CLASS,STATE', family.source],
      python_shell=false, ignore_retcode=true)|trim %}
  {% if source_state != 'TemplateVM|Halted' %}{% set status.valid = false %}{% endif %}
{% endif %}

{% if not status.valid %}
qubes_gui_template_family_identity_refused:
  test.fail_without_changes:
    - name: >-
        Refusing this template family: a required clone source is not a halted
        TemplateVM, or an existing target is running, has the wrong class,
        or lacks the exact family tag and bound name, role and source features.
        No target is adopted, stopped, removed or recloned.
{% else %}
{% for role, name in family.names.items() %}
{% if opts.get('test', false) or status.present[role] %}
qubes_gui_template_family_{{ role }}_owned:
  test.nop:
    - name: >-
{% if status.present[role] %}
        Existing {{ name }} is a verified, halted {{ role }} family TemplateVM.
{% else %}
        Would clone {{ name }} from {{ family.parents[role] }} and record its
        family identity. New guest targets do not exist during this dry run.
{% endif %}
{% else %}
qubes_gui_template_family_{{ role }}_clone:
  {# Unlike qvm.clone's state wrapper, the native command fails if a target
     appears concurrently, before any identity feature can be assigned. #}
  cmd.run:
    - name: /usr/bin/qvm-clone -- {{ family.parents[role] }} {{ name }}
{% if role != 'base' %}
    - require:
      - {{ 'test' if status.present['base'] else 'qvm' }}: qubes_gui_template_family_base_owned
{% endif %}

qubes_gui_template_family_{{ role }}_identity:
  qvm.features:
    - name: '{{ name }}'
    - set:
      - {{ family.feature_prefix }}name: '{{ name }}'
      - {{ family.feature_prefix }}role: '{{ role }}'
      - {{ family.feature_prefix }}source: '{{ family.parents[role] }}'
      - default-menu-items: 'xfce4-terminal.desktop thunar.desktop firefox-esr.desktop xfce-settings-manager.desktop org.xfce.mousepad.desktop{{ " electrum.desktop" if role == "trader" else " code.desktop" if role == "agent" else "" }}'
      - menu-items: 'xfce4-terminal.desktop thunar.desktop firefox-esr.desktop xfce-settings-manager.desktop org.xfce.mousepad.desktop{{ " electrum.desktop" if role == "trader" else " code.desktop" if role == "agent" else "" }}'
    - require:
      - cmd: qubes_gui_template_family_{{ role }}_clone

qubes_gui_template_family_{{ role }}_owned:
  qvm.tags:
    - name: '{{ name }}'
    - add:
      - {{ family.tag }}
    - require:
      - qvm: qubes_gui_template_family_{{ role }}_identity
{% endif %}
{% if role == 'agent' and status.present[role] %}
{# Preserve absent features: Qubes inheritance/fallback differs from an empty
   explicit selection. Append only to lists already owned by this template. #}
{% set menus = {} %}
{% for feature in ['menu-items', 'default-menu-items'] %}
  {% if feature in status.features[role] %}
    {% set selected = status.features[role][feature].split() %}
    {% if 'code.desktop' not in selected %}
      {% do menus.update({feature: (selected + ['code.desktop'])|join(' ')}) %}
    {% endif %}
  {% endif %}
{% endfor %}
{% if menus %}
qubes_gui_template_family_agent_code_menus:
  qvm.features:
    - name: '{{ name }}'
    - set:
{% for feature, selected in menus.items() %}
      - {{ feature }}: {{ selected|tojson }}
{% endfor %}
    - require:
      - test: qubes_gui_template_family_agent_owned
{% endif %}
{% endif %}
{% endfor %}
{% endif %}

{% else %}
{% from 'qubes_gui/templates/family/scope.jinja' import scope with context %}
{% if scope.valid %}
include:
  - qubes_gui.templates.family.{{ scope.role }}
{% else %}
qubes_gui_template_family_guest_refused:
  test.fail_without_changes:
    - name: >-
        This family supports Qubes 4.3 dom0 and its owned Debian 13 x86_64
        TemplateVMs only. Guest name, role, source and family ownership must
        match dom0's native Qubes pillar and the configured family names.
{% endif %}
{% endif %}
