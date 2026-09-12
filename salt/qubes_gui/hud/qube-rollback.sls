{# Remove only this optional preset's owned configuration, retaining the AppVM. #}
{% set qube_rollback = true %}
{% include 'qubes_gui/hud/qube.sls' %}
