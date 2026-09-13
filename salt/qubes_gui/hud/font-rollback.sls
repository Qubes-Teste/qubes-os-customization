{# Remove the optional font trial while preserving unrelated fonts and choices. #}
{% set font_rollback = true %}
{% include 'qubes_gui/hud/font.sls' %}
