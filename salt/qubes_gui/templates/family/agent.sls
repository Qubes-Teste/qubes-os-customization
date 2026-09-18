{# Development tools from Debian's signed repositories.
   Upstream Codex/Hermes/OpenClaw/signal-cli are permitted but not yet implemented. #}
{% from 'qubes_gui/templates/family/scope.jinja' import scope with context %}
{% if not scope.valid or scope.role != 'agent' %}
qubes_gui_template_agent_scope_refused:
  test.fail_without_changes:
    - name: Agent packages require the owned Debian Agent TemplateVM.
{% else %}
include:
  - qubes_gui.templates.family.base

qubes_gui_template_agent_cli_packages:
  pkg.installed:
    - pkgs:
      - git-all
      - git-lfs
      - gh
      - ripgrep
      - fd-find
      - jq
      - tree
      - file
      - findutils
      - diffutils
      - patch
      - gawk
      - less
      - curl
      - wget
      - ca-certificates
      - openssh-client
      - rsync
      - tar
      - gzip
      - bzip2
      - xz-utils
      - zstd
      - zip
      - unzip
      - procps
      - psmisc
      - util-linux
      - lsof
      - strace
      - tmux
      - sqlite3
      - build-essential
      - pkg-config
      - shellcheck
    - install_recommends: false
    - require:
      - sls: qubes_gui.templates.family.base
{% endif %}
