{# Optional ordinary-Firefox defaults. No policies, profiles or packages changed. #}
{% import_text 'qubes_gui/guest_hud/files/firefox-prefs.js' as firefox_preferences %}
{% set expected = firefox_preferences.rstrip('\n') ~ '\n' %}
{% set rollback = firefox_rollback|default(false) %}
{% set config = salt['pillar.get']('qubes_gui:guest_hud:firefox', {}) %}
{% set cfg = config if config is mapping else {} %}
{% set preview_qube = cfg.get('preview_qube', '') %}
{% set qubesdb = '/usr/bin/qubesdb-read' %}
{% set vm_type = salt['cmd.run'](qubesdb ~ ' /qubes-vm-type',
    python_shell=false, ignore_retcode=true)|trim
    if salt['file.file_exists'](qubesdb) else '' %}
{% set vm_name = salt['cmd.run'](qubesdb ~ ' /name',
    python_shell=false, ignore_retcode=true)|trim
    if preview_qube and salt['file.file_exists'](qubesdb) else '' %}
{% set debian = grains.get('os_family') == 'Debian' %}
{% set fedora = grains.get('os') == 'Fedora' %}
{% set package = 'firefox-esr' if debian else 'firefox' %}
{% set libdir = '/usr/lib' if debian else '/usr/lib64' %}
{% set browser_root = libdir ~ '/' ~ package %}
{% set pref_dir = browser_root ~ '/defaults/pref' %}
{% set target = pref_dir ~ '/qubes-hud.js' %}
{% set scope_ok = config is mapping and preview_qube is string
    and grains.get('kernel') == 'Linux'
    and grains.get('virtual', '')|lower == 'xen' and (debian or fedora)
    and ((not preview_qube and vm_type == 'TemplateVM')
         or (preview_qube and vm_type == 'AppVM' and preview_qube == vm_name)) %}

{% if not scope_ok %}
qubes_gui_guest_hud_firefox_target_refused:
  test.fail_without_changes:
    - name: >-
        Firefox defaults require a Debian-family or Fedora Qubes Linux
        TemplateVM. An ephemeral AppVM preview requires its exact QubesDB
        name under qubes_gui:guest_hud:firefox:preview_qube.
{% else %}
{% set safe = namespace(value=true) %}
{% for path in ['/', '/usr', libdir, browser_root, browser_root ~ '/defaults', pref_dir] %}
  {% set st = salt['file.lstat'](path) %}
  {% if (not st and not rollback) or (st and (
      not salt['file.directory_exists'](path) or salt['file.is_link'](path)
      or st.get('st_uid') != 0 or st.get('st_gid') != 0
      or salt['file.get_mode'](path) != '0755')) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% set st = salt['file.lstat'](target) if safe.value else {} %}
{% if st and (not salt['file.file_exists'](target) or salt['file.is_link'](target)
    or st.get('st_uid') != 0 or st.get('st_gid') != 0
    or st.get('st_nlink') != 1 or salt['file.get_mode'](target) != '0644'
    or st.get('st_size') != expected|length
    or salt['file.read'](target) != expected) %}
  {% set safe.value = false %}
{% endif %}
{% if not safe.value %}
qubes_gui_guest_hud_firefox_path_refused:
  test.fail_without_changes:
    - name: Refusing unsafe Firefox directories or an unowned or modified qubes-hud.js preference file.
{% else %}
{# pkg.owner leaves a nonzero Salt return code for an unowned path, which
   Qubes' Salt SSH wrapper treats as a failed render. Inspect native query
   results explicitly; ignore_retcode affects Salt's status, not this result. #}
{% set query = ['/usr/bin/dpkg-query', '--search'] if debian
    else ['/usr/bin/rpm', '--query', '--whatprovides', '--queryformat', '%{NAME}'] %}
{% set owner = salt['cmd.run_all'](query + [target],
    python_shell=false, ignore_retcode=true, env={'LC_ALL': 'C'}) %}
{% set channel_owner = salt['cmd.run_all'](query + [pref_dir ~ '/channel-prefs.js'],
    python_shell=false, ignore_retcode=true, env={'LC_ALL': 'C'})
    if not rollback else {} %}
{% if owner.get('retcode') != 1 %}
qubes_gui_guest_hud_firefox_package_file_refused:
  test.fail_without_changes:
    - name: Refusing a package-owned Firefox preference file or a failed package ownership query.
{% elif not rollback and (not salt['pkg.version'](package)
    or channel_owner.get('retcode') != 0
    or channel_owner.get('stdout', '').split(':', 1)[0]|trim != package) %}
qubes_gui_guest_hud_firefox_package_required:
  test.fail_without_changes:
    - name: Install ordinary Firefox from the supported distribution repositories before selecting its optional HUD defaults.
{% elif rollback %}
qubes_gui_guest_hud_firefox_preferences_removed:
  file.absent:
    - name: {{ target }}
{% else %}
qubes_gui_guest_hud_firefox_preferences:
  file.managed:
    - name: {{ target }}
    - source: salt://qubes_gui/guest_hud/files/firefox-prefs.js
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: false
{% endif %}
{% endif %}
{% endif %}
