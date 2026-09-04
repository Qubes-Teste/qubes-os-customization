qubes_gui:
  i3:
    # auto, direct-dom0, or qubes-updatevm
    package_transport: auto
    desktop_user: user
    desktop_group: user
    modifier: Mod4
    set_default_session: true
    force_replace_user_config: false
  hud:
    # Apply qubes_gui.i3 first so the exact audited Qubes i3 base is present.
    # auto, direct-dom0, or qubes-updatevm
    package_transport: auto
    desktop_user: user
    desktop_group: user
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
