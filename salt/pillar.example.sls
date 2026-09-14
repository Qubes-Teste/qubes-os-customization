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
    # Optional shared qubes_gui.hud.font state for dom0 and each TemplateVM.
    # A selected pair is retained across boots; no font downloads or packages.
    # font:
    #   family: Zen Dots
    #   monospace_family: White Rabbit
  # The guest state currently has safe fixed visual defaults. This section is
  # reserved for future toolkit-specific overrides.
  guest_hud: {}
  templates:
    hud:
      # Example machine policy for qubes_gui.templates.hud. Do not copy these
      # names blindly; select a halted local source TemplateVM and a new target
      # name. Source is used only when the target is first created.
      source: debian-13-xfce
      target: debian-13-hud
