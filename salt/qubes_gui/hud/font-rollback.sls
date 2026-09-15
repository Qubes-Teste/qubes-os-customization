{# Remove only verified HUD fonts and selector; preserve distribution fonts. #}
{% set font_rollback = true %}
{% include 'qubes_gui/hud/font.sls' %}
