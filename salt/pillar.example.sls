qubes_gui:
  i3:
    # Safe default: dom0 stays offline and signed RPMs arrive through UpdateVM.
    # Optional overrides: auto or direct-dom0.
    package_transport: qubes-updatevm
    desktop_user: user
    desktop_group: user
    modifier: Mod4
    set_default_session: true
    force_replace_user_config: false
  hud:
    # Apply qubes_gui.i3 first so the exact audited Qubes i3 base is present.
    # Safe default: dom0 stays offline and signed RPMs arrive through UpdateVM.
    # Optional overrides: auto or direct-dom0.
    package_transport: qubes-updatevm
    desktop_user: user
    desktop_group: user
    # Optional, separate qubes_gui.hud.qube state; absent name is disabled.
    # Provision guest autostart before setting ready: true (see HUD README).
    # qube_workspace:
    #   name: hud-test
    #   template: debian-13-xfce
    #   ready: false
    # Zen Dots (interface) and White Rabbit (monospace) are included by default
    # in the HUD and guest HUD states. No font-selection pillar is needed.
  # The guest state currently has safe fixed visual defaults. This section is
  # reserved for future toolkit-specific overrides.
  guest_hud: {}
  templates:
    # Optional overrides for the separate qubes_gui.templates.family state.
    # The defaults work with an installed, halted Debian 13 Xfce TemplateVM.
    family:
      source: debian-13-xfce
      names:
        base: debian-13-hud-base
        agent: debian-13-hud-agent
        trader: debian-13-hud-trader
    hud:
      # Example machine policy for qubes_gui.templates.hud. Do not copy these
      # names blindly; select a halted local source TemplateVM and a new target
      # name. Source is used only when the target is first created.
      source: debian-13-xfce
      target: debian-13-hud
