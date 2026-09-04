{# Clone a local TemplateVM for HUD use. Styling is the required second phase. #}
{% set settings = salt['pillar.get']('qubes_gui:templates:hud', {}) %}
{% set source = settings.get('source', '')|string %}
{% set target = settings.get('target', '')|string %}
{% set managed_tag = 'hud-theme-managed' %}
{% set valid_name_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-' %}
{% set valid_first_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ' %}
{% set reserved_names = ['Domain-0', 'none', 'default'] %}
{% set names_valid = namespace(value=true) %}
{% for name in [source, target] %}
  {% if not name or name|length > 31 or name[0] not in valid_first_chars
      or name in reserved_names or name[-3:] == '-dm' %}
    {% set names_valid.value = false %}
  {% endif %}
  {% for character in name %}
    {% if character not in valid_name_chars %}
      {% set names_valid.value = false %}
    {% endif %}
  {% endfor %}
{% endfor %}
{% set names_usable = names_valid.value and source != target %}
{% set target_exists = salt['cmd.retcode'](
    '/usr/bin/qvm-check --quiet ' ~ target, python_shell=false,
    ignore_retcode=true) == 0 if names_usable else false %}
{% set target_tags = salt['cmd.run'](
    '/usr/bin/qvm-tags ' ~ target ~ ' list', python_shell=false,
    ignore_retcode=true).splitlines() if target_exists else [] %}
{% set target_managed = managed_tag in target_tags %}

{% if not names_usable %}
qubes_gui_templates_hud_invalid_configuration:
  test.fail_without_changes:
    - name: >-
        Set distinct source and target Qube names under
        qubes_gui:templates:hud. Names must begin with a letter and contain
        at most 31 letters, digits, dots, underscores, or hyphens. Qubes'
        reserved names and the -dm suffix are not accepted.

{% elif target_exists and not target_managed %}
qubes_gui_templates_hud_unmanaged_target_refused:
  test.fail_without_changes:
    - name: >-
        Refusing to adopt the existing target '{{ target }}' because it lacks
        the {{ managed_tag }} ownership tag.

{% else %}

qubes_gui_templates_hud_source_is_template:
  qvm.exists:
    - name: '{{ source }}'
    - flags:
      - template

qubes_gui_templates_hud_source_is_halted:
  qvm.halted:
    - name: '{{ source }}'
    - require:
      - qvm: qubes_gui_templates_hud_source_is_template

qubes_gui_templates_hud_clone:
  qvm.clone:
    - name: '{{ target }}'
    - source: '{{ source }}'
    - require:
      - qvm: qubes_gui_templates_hud_source_is_halted

qubes_gui_templates_hud_target_is_template:
  qvm.exists:
    - name: '{{ target }}'
    - flags:
      - template
    - require:
      - qvm: qubes_gui_templates_hud_clone

qubes_gui_templates_hud_target_is_halted:
  qvm.halted:
    - name: '{{ target }}'
    - require:
      - qvm: qubes_gui_templates_hud_target_is_template

qubes_gui_templates_hud_ownership_tag:
  qvm.tags:
    - name: '{{ target }}'
    - add:
      - {{ managed_tag }}
    - require:
      - qvm: qubes_gui_templates_hud_target_is_halted

qubes_gui_templates_hud_next_phase:
  test.nop:
    - name: >-
        Template '{{ target }}' is provisioned and halted. Apply
        qubes_gui.guest_hud to that TemplateVM before using it as an AppVM
        base.
    - require:
      - qvm: qubes_gui_templates_hud_ownership_tag

{% endif %}
