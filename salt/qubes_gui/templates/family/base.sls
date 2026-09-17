{# Shared policy for explicitly owned Debian 13 Base/Agent/Trader TemplateVMs. #}
{% from 'qubes_gui/templates/family/scope.jinja' import scope with context %}
{% import_text 'qubes_gui/templates/family/files/user-dirs.conf' as dirs_conf %}
{% import_text 'qubes_gui/templates/family/files/user-dirs.dirs' as dirs_defaults %}
{% set base_packages = ['pass'] %}
{% set mail_launcher = '/usr/share/applications/xfce4-mail-reader.desktop' %}

{% if not scope.valid %}
qubes_gui_template_family_base_target_refused:
  test.fail_without_changes:
    - name: Base policy requires an explicitly owned Debian 13 family TemplateVM with matching native Qubes name, role, source and tag metadata.
{% else %}
{% set safe = namespace(value=true) %}
{% set optional_dirs = ['/etc/skel/.config'] %}
{% for path in ['/', '/etc', '/etc/xdg', '/etc/skel', '/usr', '/usr/share', '/usr/share/applications', '/home'] + optional_dirs %}
  {% set st = salt['file.lstat'](path) %}
  {% if (not st and path not in optional_dirs) or (st and (
      st.get('st_uid') != 0 or st.get('st_gid') != 0
      or st.get('st_mode') not in ([16749, 16877] if path == '/' else [16877]))) %}
    {% set safe.value = false %}
  {% endif %}
{% endfor %}
{% set defaults = {
    '/etc/xdg/user-dirs.conf': dirs_conf.rstrip('\n') ~ '\n',
    '/etc/skel/.config/user-dirs.dirs': dirs_defaults.rstrip('\n') ~ '\n'
} %}
{% for path, expected in defaults.items() if safe.value %}
  {% set st = salt['file.lstat'](path) %}
  {% if st %}
    {% if st.get('st_mode') != 33188 or st.get('st_uid') != 0
        or st.get('st_gid') != 0 or st.get('st_nlink') != 1 %}
      {% set safe.value = false %}
    {% elif salt['file.read'](path) != expected %}
      {# Adopt only the unmodified package conffile, or our exact managed
         content above; a customized system configuration is refused. #}
      {% set owner = salt['cmd.run_all'](
          ['/usr/bin/dpkg-query', '--search', path], python_shell=false,
          ignore_retcode=true, env={'LC_ALL': 'C'})
          if path == '/etc/xdg/user-dirs.conf' else {} %}
      {% if owner.get('retcode') != 0
          or owner.get('stdout', '').split(':', 1)[0] != 'xdg-user-dirs' %}
        {% set safe.value = false %}
      {% else %}
        {% set conffiles = salt['cmd.run_all'](
            ['/usr/bin/dpkg-query', '-W', '-f=${Conffiles}', 'xdg-user-dirs'],
            python_shell=false, ignore_retcode=true, env={'LC_ALL': 'C'}) %}
        {% set hashes = [] %}
        {% for line in conffiles.get('stdout', '').splitlines() %}
          {% set fields = line.split() %}
          {% if fields|length == 2 and fields[0] == path %}
            {% do hashes.append(fields[1]) %}
          {% endif %}
        {% endfor %}
        {% if conffiles.get('retcode') != 0 or hashes|length != 1
            or salt['file.get_hash'](path, 'md5') != hashes[0] %}
          {% set safe.value = false %}
        {% endif %}
      {% endif %}
    {% endif %}
  {% endif %}
{% endfor %}
{# /usr/share is inherited from the TemplateVM; /usr/local is AppVM-private.
   Edit only visibility in the stock launcher, retaining all localized entries. #}
{% set mail_stat = salt['file.lstat'](mail_launcher) if safe.value else {} %}
{% set mail_owner = salt['cmd.run_all'](
    ['/usr/bin/dpkg-query', '--search', mail_launcher], python_shell=false,
    ignore_retcode=true, env={'LC_ALL': 'C'}) if safe.value else {} %}
{% if not mail_stat or mail_stat.get('st_mode') != 33188
    or mail_stat.get('st_uid') != 0 or mail_stat.get('st_gid') != 0
    or mail_stat.get('st_nlink') != 1 or mail_owner.get('retcode') != 0
    or mail_owner.get('stdout', '').split(':', 1)[0] != 'xfce4-settings' %}
  {% set safe.value = false %}
{% endif %}

{# Qubes copies /etc/skel only for a fresh private home. Existing documents
   and profiles are preserved; rmdir cannot remove a nonempty directory. #}
{% set account = salt['user.info']('user') if safe.value else {} %}
{% set home_stat = salt['file.lstat']('/home/user') if safe.value else {} %}
{% if not account or account.get('uid', 0) == 0
    or account.get('home') != '/home/user' or not home_stat
    or home_stat.get('st_uid') != account.get('uid')
    or home_stat.get('st_gid') != account.get('gid')
    or home_stat.get('st_mode') not in [16832, 16877] %}
  {% set safe.value = false %}
{% endif %}
{% set empty_dirs = [] %}
{% set retained_dirs = [] %}
{% for root, uid, gid in [('/etc/skel', 0, 0), ('/home/user', account.get('uid'), account.get('gid'))] if safe.value %}
  {% for name in ['Desktop', 'Documents', 'Downloads', 'Music', 'Pictures', 'Public', 'Templates', 'Videos'] %}
    {% set path = root ~ '/' ~ name %}
    {% set st = salt['file.lstat'](path) %}
    {% if st %}
      {% if st.get('st_uid') != uid or st.get('st_gid') != gid
          or st.get('st_mode') not in [16832, 16877] %}
        {% set safe.value = false %}
      {% elif salt['file.readdir'](path)|sort != ['.', '..'] %}
        {% do retained_dirs.append(path) %}
      {% else %}
        {% do empty_dirs.append(path) %}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endfor %}

{# Source identity includes UNO and OpenSymbol; residual-config packages are
   selected too. Pre-existing orphan packages must remain untouched. #}
{% set inventory = salt['cmd.run_all'](
    ['/usr/bin/dpkg-query', '-W', '-f=${db:Status-Abbrev}\t${binary:Package}\t${source:Package}\n'],
    python_shell=false, ignore_retcode=true, env={'LC_ALL': 'C'}) if safe.value else {} %}
{% set purge = [] %}
{% set package_chars = 'abcdefghijklmnopqrstuvwxyz0123456789+.-:' %}
{% for line in inventory.get('stdout', '').splitlines() %}
  {% set fields = line.split('\t') %}
  {% if fields|length != 3 %}
    {% set safe.value = false %}
  {% else %}
    {% set package = fields[1][:-6] if fields[1].endswith(':amd64') else fields[1] %}
    {% set bare = package.split(':', 1)[0] %}
    {% if fields[2] in ['libreoffice', 'thunderbird']
        or bare in ['libreoffice', 'thunderbird', 'fonts-opensymbol', 'python3-uno', 'uno-libs-private', 'ure']
        or bare.startswith('libreoffice-') or bare.startswith('thunderbird-')
        or bare.startswith('libuno-') %}
      {% if not package %}{% set safe.value = false %}{% endif %}
      {% for character in package %}
        {% if character not in package_chars %}{% set safe.value = false %}{% endif %}
      {% endfor %}
      {% if fields[0][1:2] != 'n' %}{% do purge.append(package) %}{% endif %}
    {% endif %}
  {% endif %}
{% endfor %}
{% if inventory.get('retcode') != 0 %}{% set safe.value = false %}{% endif %}

{# Ask native APT which dependencies become unused because of this purge.
   Only the difference is added to the explicit pkg.purged list; the actual
   transaction never runs autoremove and later unrelated orphans are retained. #}
{% if safe.value and purge %}
  {% set removals = [[], []] %}
  {% set commands = [
      ['/usr/bin/apt-get', '--simulate', 'autoremove', '--purge'],
      ['/usr/bin/apt-get', '--simulate', '--autoremove', 'purge'] + purge
  ] %}
  {% for command in commands %}
    {% set index = loop.index0 %}
    {% set plan = salt['cmd.run_all'](command, python_shell=false,
        ignore_retcode=true, env={'LC_ALL': 'C'}, timeout=60) %}
    {% if plan.get('retcode') != 0 %}{% set safe.value = false %}{% endif %}
    {% for line in plan.get('stdout', '').splitlines() %}
      {% set fields = line.split() %}
      {% if fields and fields[0] in ['Inst', 'Conf'] %}
        {% set safe.value = false %}
      {% elif fields and fields[0] in ['Remv', 'Purg'] %}
        {% if fields|length < 2 or not fields[1]
            or fields[1][0] not in 'abcdefghijklmnopqrstuvwxyz0123456789' %}
          {% set safe.value = false %}
        {% else %}
          {% for character in fields[1] %}
            {% if character not in package_chars %}{% set safe.value = false %}{% endif %}
          {% endfor %}
          {% do removals[index].append(fields[1][:-6]
              if fields[1].endswith(':amd64') else fields[1]) %}
        {% endif %}
      {% endif %}
    {% endfor %}
  {% endfor %}
  {% for package in purge %}
    {% if package not in removals[1] %}
      {% set safe.value = false %}
    {% endif %}
  {% endfor %}
  {% for package in removals[1] %}
    {% if package not in removals[0] and package not in purge %}
      {% do purge.append(package) %}
    {% endif %}
  {% endfor %}
  {# A retained orphan may depend on a newly unused library. Refuse a final
     explicit purge that would nevertheless remove that orphan indirectly. #}
  {% if safe.value %}
    {% set final_plan = salt['cmd.run_all'](
        ['/usr/bin/apt-get', '--simulate', 'purge'] + purge,
        python_shell=false, ignore_retcode=true, env={'LC_ALL': 'C'}, timeout=60) %}
    {% set final_removals = [] %}
    {% if final_plan.get('retcode') != 0 %}{% set safe.value = false %}{% endif %}
    {% for line in final_plan.get('stdout', '').splitlines() %}
      {% set fields = line.split() %}
      {% if fields and fields[0] in ['Inst', 'Conf'] %}
        {% set safe.value = false %}
      {% elif fields and fields[0] in ['Remv', 'Purg'] %}
        {% if fields|length < 2 %}
          {% set safe.value = false %}
        {% else %}
          {% set package = fields[1][:-6] if fields[1].endswith(':amd64') else fields[1] %}
          {% if package not in purge %}{% set safe.value = false %}{% endif %}
          {% do final_removals.append(package) %}
        {% endif %}
      {% endif %}
    {% endfor %}
    {% if final_removals|sort != purge|sort %}{% set safe.value = false %}{% endif %}
  {% endif %}
{% endif %}

{% if not safe.value %}
qubes_gui_template_family_base_paths_refused:
  test.fail_without_changes:
    - name: Refusing unsafe or unowned family defaults, unexpected home-folder metadata, or a failed native package inventory.
{% else %}
{% set firefox = salt['pkg.version']('firefox-esr') %}
include:
  - qubes_gui.guest_hud
{% if firefox %}
  - qubes_gui.guest_hud.firefox
{% endif %}

qubes_gui_template_family_base_packages:
  pkg.installed:
    - pkgs: {{ base_packages|tojson }}
    - install_recommends: false

qubes_gui_template_family_base_purge:
{% if purge %}
  pkg.purged:
    - pkgs: {{ purge|sort|tojson }}
    - require_in:
      - pkg: qubes_gui_template_family_base_packages
      - pkg: qubes_gui_guest_hud_runtime_packages
{% else %}
  test.nop:
    - name: LibreOffice and Thunderbird packages and registered configuration residues are absent.
{% endif %}

qubes_gui_template_family_skel_config_directory:
  file.directory:
    - name: /etc/skel/.config
    - user: root
    - group: root
    - mode: '0755'

qubes_gui_template_family_user_dirs_disabled:
  file.managed:
    - name: /etc/xdg/user-dirs.conf
    - source: salt://qubes_gui/templates/family/files/user-dirs.conf
    - user: root
    - group: root
    - mode: '0644'

qubes_gui_template_family_user_dirs_defaults:
  file.managed:
    - name: /etc/skel/.config/user-dirs.dirs
    - source: salt://qubes_gui/templates/family/files/user-dirs.dirs
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: qubes_gui_template_family_skel_config_directory

qubes_gui_template_family_mail_reader_hidden:
  ini.options_present:
    - name: {{ mail_launcher }}
    - sections:
        Desktop Entry:
          Hidden: 'true'
          NoDisplay: 'true'
    - strict: false
    - no_spaces: true
    - encoding: UTF-8

qubes_gui_template_family_mail_menu_sync:
  cmd.run:
    - name: /usr/lib/qubes/qubes-trigger-sync-appmenus.sh
    - onchanges:
      - ini: qubes_gui_template_family_mail_reader_hidden

{% for path in empty_dirs %}
qubes_gui_template_family_empty_folder_{{ loop.index }}:
  cmd.run:
    - name: /usr/bin/rmdir -- {{ path }}
    - runas: {{ 'user' if path.startswith('/home/user/') else 'root' }}
    - require:
      - file: qubes_gui_template_family_user_dirs_disabled
      - file: qubes_gui_template_family_user_dirs_defaults
{% endfor %}

qubes_gui_template_family_base_complete:
  test.nop:
    - name: >-
        Base packages, application removals and HUD defaults are configured.
        Existing user profiles are preserved.
{% if retained_dirs %}
        Nonempty folders retained: {{ retained_dirs|join(', ') }}.
{% endif %}
    - require:
      - sls: qubes_gui.guest_hud
{% if firefox %}
      - sls: qubes_gui.guest_hud.firefox
{% endif %}
      - pkg: qubes_gui_template_family_base_packages
      - {{ 'pkg' if purge else 'test' }}: qubes_gui_template_family_base_purge
      - file: qubes_gui_template_family_user_dirs_disabled
      - file: qubes_gui_template_family_user_dirs_defaults
      - ini: qubes_gui_template_family_mail_reader_hidden
      - cmd: qubes_gui_template_family_mail_menu_sync
{% for path in empty_dirs %}
      - cmd: qubes_gui_template_family_empty_folder_{{ loop.index }}
{% endfor %}
{% endif %}
{% endif %}
