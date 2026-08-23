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
