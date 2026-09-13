{# Remove only the optional ordinary-Firefox preference file. #}
{% set firefox_rollback = true %}
{% include 'qubes_gui/guest_hud/firefox.sls' %}
