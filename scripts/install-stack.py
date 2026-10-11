#!/usr/bin/env python3
"""Install the committed HUD stack with native Qubes tools; run in dom0."""

import argparse
import json
import os
from pathlib import Path
import platform
import pwd
import re
import shlex
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = "debian-13-xfce"
FAMILY = {role: "debian-13-hud-" + role for role in ("base", "agent", "trader")}
PRESET = "hud-test"
TOOLS = ("qvm-ls", "qvm-features", "qvm-tags", "qvm-prefs", "qubes-prefs",
         "qvm-template", "qubesctl")


def read(*command):
    """Bounded, read-only local Qubes queries; never start a qube."""
    return subprocess.run(command, check=True, text=True, capture_output=True,
                          timeout=30).stdout.strip()


def domains():
    result = {}
    for line in read("/usr/bin/qvm-ls", "--raw-data", "--fields",
                     "NAME,CLASS,STATE,TEMPLATE").splitlines():
        name, kind, state, template = line.split("|")
        result[name] = {"class": kind, "state": state, "template": template}
    return result


def features(name):
    return dict(line.split(None, 1) if len(line.split(None, 1)) == 2
                else (line, "") for line in
                read("/usr/bin/qvm-features", name).splitlines())


def valid_name(name):
    return (re.fullmatch(r"[A-Za-z][A-Za-z0-9_.-]{0,30}", name) is not None
            and name not in {"dom0", "Domain-0", "none", "default"}
            and not name.endswith("-dm"))


def check_platform():
    release = Path("/etc/os-release").read_text()
    version = re.search(r'^VERSION_ID=[\"\']?([0-9]+(?:\.[0-9]+)+)[\"\']?$',
                        release, re.M)
    if (not re.search(r'^ID=[\"\']?qubes[\"\']?$', release, re.M)
            or not version or tuple(map(int, version[1].split('.')[:2])) < (4, 3)
            or platform.machine() != "x86_64"):
        raise ValueError("This installer requires Qubes OS 4.3 or newer x86_64 dom0.")
    for tool in TOOLS:
        if not os.access("/usr/bin/" + tool, os.X_OK):
            raise ValueError("Required stock Qubes tool is missing: " + tool)


def inspect_machine(args):
    check_platform()
    username = args.desktop_user or (os.environ.get("SUDO_USER")
                                    if os.geteuid() == 0 else pwd.getpwuid(os.getuid()).pw_name)
    if not username or not re.fullmatch(r"[a-z_][a-z0-9_-]*\$?", username):
        raise ValueError("Select the normal dom0 account with --desktop-user USER.")
    account = pwd.getpwnam(username)
    if account.pw_uid == 0 or not Path(account.pw_dir).is_dir():
        raise ValueError("The desktop user must be a non-root account with an existing home.")
    for name in [args.source_template] + args.guest_template:
        if not valid_name(name):
            raise ValueError("Invalid template name: " + name)
    if args.source_template in set(FAMILY.values()) | {PRESET}:
        raise ValueError("The source must differ from the family and workspace names.")
    vms = domains()
    if vms.get("dom0", {}).get("class") != "AdminVM":
        raise ValueError("Run this installer in dom0.")
    errors = []
    updatevm = read("/usr/bin/qubes-prefs", "updatevm")
    if updatevm not in vms or updatevm == "dom0" or vms[updatevm]["state"] == "Paused":
        errors.append("Configure an available non-dom0 UpdateVM in Qubes Global Config.")
    missing = args.source_template not in vms
    if missing and args.source_template != SOURCE:
        errors.append("The custom source template does not exist: " + args.source_template)
    metadata = {name: features(name) for name, vm in vms.items()
                if vm["class"] == "TemplateVM" and name not in FAMILY.values()}
    graphical = []
    for name, saved in sorted(metadata.items()):
        distribution = saved.get("os-distribution")
        major = saved.get("os-version", "").split(".")[0]
        if saved.get("gui") == "1" and (distribution == "fedora"
                or (distribution, major) in {("debian", "13"), ("whonix", "18")}):
            graphical.append(name)
    guests = list(dict.fromkeys([args.source_template] + graphical + args.guest_template))
    for name in list(dict.fromkeys(guests + list(FAMILY.values()))):
        vm = vms.get(name)
        if vm is None:
            if name != args.source_template and name not in FAMILY.values():
                errors.append("Requested guest template does not exist: " + name)
            continue
        if vm["class"] != "TemplateVM" or vm["state"] != "Halted":
            errors.append(name + " must be a halted TemplateVM; it will not be stopped automatically.")
    if not missing and vms[args.source_template]["class"] == "TemplateVM":
        source_features = metadata[args.source_template]
        if (source_features.get("os-distribution") != "debian"
                or source_features.get("os-version", "").split(".")[0] != "13"):
            errors.append("The source must advertise Debian 13; guest Salt also verifies the actual OS.")
    for role, name in FAMILY.items():
        if name not in vms:
            continue
        expected_source = args.source_template if role == "base" else FAMILY["base"]
        saved = features(name)
        tags = read("/usr/bin/qvm-tags", name, "list").splitlines()
        if ("hud-template-family-managed" not in tags
                or any(saved.get("vm-config.qubes-hud-family-" + key) != value
                       for key, value in {"name": name, "role": role,
                                          "source": expected_source}.items())):
            errors.append("Refusing an existing family name without matching ownership: " + name)
    if not args.skip_workspace:
        if "sys-firewall" not in vms:
            errors.append("The workspace preset requires the existing sys-firewall qube.")
        if PRESET in vms:
            vm = vms[PRESET]
            if (vm["class"] != "AppVM" or vm["template"] != args.source_template
                    or "hud-workspace-managed" not in read(
                        "/usr/bin/qvm-tags", PRESET, "list").splitlines()):
                errors.append("Refusing an existing hud-test without the matching workspace identity.")
            if vm["state"] != "Halted":
                errors.append("hud-test must be halted. Close it normally or use --skip-workspace.")
    return {"vms": vms, "desktop": account, "updatevm": updatevm,
            "guests": guests, "missing_source": missing, "errors": errors}


def build_plan(args, machine):
    account = machine["desktop"]
    import grp
    desktop = {"desktop_user": account.pw_name,
               "desktop_group": grp.getgrgid(account.pw_gid).gr_name,
               "package_transport": "qubes-updatevm"}
    pillar = {"qubes_gui": {"i3": desktop.copy(), "hud": desktop.copy(),
                            "templates": {"family": {"source": args.source_template,
                                                        "names": FAMILY}}}}
    phases = []

    def add(title, command, targets=(), kind="TemplateVM"):
        phases.append({"title": title, "command": command,
                       "targets": tuple(targets), "kind": kind})

    def salt(title, state, targets=(), kind="TemplateVM", extra=None):
        data = json.loads(json.dumps(pillar))
        if extra is not None:
            data["qubes_gui"]["hud"]["qube_workspace"] = extra
        command = ["/usr/bin/qubesctl", "--show-output", "--max-concurrency=1"]
        if targets:
            command += ["--skip-dom0", "--targets=" + ",".join(targets)]
        command += ["state.sls", state, "saltenv=user",
                    "pillar=" + json.dumps(data, separators=(",", ":"))]
        add(title + " — preview", command + ["test=True"], targets, kind)
        add(title + " — apply", command, targets, kind)

    add("Synchronize committed Salt formula", ["/usr/bin/bash", str(ROOT / "scripts/sync-salt-formula.sh")])
    if machine["missing_source"]:
        add("Install signed Debian source through UpdateVM",
            ["/usr/bin/qvm-template", "--yes", "--updatevm", machine["updatevm"],
             "install", args.source_template])
    salt("Official i3 base", "qubes_gui.i3")
    salt("Dom0 HUD, fonts, dashboard and night light", "qubes_gui.hud")
    for name in machine["guests"]:
        state = "qubes_gui.guest_hud"
        if name == args.source_template:
            state += ",qubes_gui.guest_hud.firefox"
        salt("Guest HUD: " + name, state, [name])
    salt("Create or verify Debian template family", "qubes_gui.templates.family")
    salt("Configure Base, Agent and Trader", "qubes_gui.templates.family", list(FAMILY.values()))
    if not args.skip_workspace:
        workspace = {"name": PRESET, "template": args.source_template, "ready": False}
        salt("Create or verify workspace 2 qube", "qubes_gui.hud.qube", extra=workspace)
        salt("Configure workspace 2 application startup", "qubes_gui.hud.qube",
             [PRESET], "AppVM", workspace)
        salt("Enable workspace 2 preset at boot", "qubes_gui.hud.qube",
             extra=dict(workspace, ready=True))
    return phases


def verify_targets(phase):
    if not phase["targets"]:
        return
    current = domains()
    for name in phase["targets"]:
        vm = current.get(name, {})
        if vm.get("class") != phase["kind"] or vm.get("state") != "Halted":
            raise ValueError(name + " is missing, has the wrong class, or is not halted. "
                             "No automatic shutdown is attempted.")


def execute(phases):
    for index, phase in enumerate(phases, 1):
        print("\n[{}/{}] {}".format(index, len(phases), phase["title"]), flush=True)
        verify_targets(phase)
        command = phase["command"]
        if os.geteuid() != 0:
            command = ["/usr/bin/sudo", "--"] + command
        try:
            # Keep native installers in the foreground. Killing only the
            # qubesctl parent on a timer could leave its workers applying Salt.
            subprocess.run(command, check=True)
            verify_targets(phase)
        except (subprocess.SubprocessError, ValueError):
            print("Stopped at: " + phase["title"] + ". Inspect the native output and VM states; "
                  "close only installation-owned guests normally if left running, then rerun. "
                  "Completed Salt steps are repeatable; unknown partial clones require review.", file=sys.stderr)
            raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, epilog=(
        "The source and installed graphical Debian 13, Fedora and Whonix 18 templates "
        "receive the HUD automatically. Family templates have their own configuration phase."))
    parser.add_argument("--plan", action="store_true", help="Read-only plan; no sync, sudo, downloads or VM starts")
    parser.add_argument("--yes", action="store_true", help="Accept the initial installation plan")
    parser.add_argument("--desktop-user", help="Normal dom0 desktop account (defaults to invoking user)")
    parser.add_argument("--source-template", default=SOURCE, help="Installed Debian 13 graphical source")
    parser.add_argument("--guest-template", action="append", default=[], metavar="NAME",
                        help="Add an installed, halted graphical TemplateVM to automatic discovery; repeatable")
    parser.add_argument("--skip-workspace", action="store_true", help="Leave the optional hud-test preset untouched")
    args = parser.parse_args(argv)
    try:
        machine = inspect_machine(args)
        phases = build_plan(args, machine)
        print("Install Qubes HUD for {}. Dom0 stays offline; UpdateVM: {}.".format(
            machine["desktop"].pw_name, machine["updatevm"]))
        for index, phase in enumerate(phases, 1):
            print("{}. {}".format(index, phase["title"]))
            if args.plan:
                print("   " + shlex.join(phase["command"]))
        print("No active desktop or service qube is restarted. Native package downloads may take hours.")
        if machine["errors"]:
            for error in machine["errors"]:
                print("Preflight: " + error, file=sys.stderr)
            return 1
        if args.plan:
            return 0
        if not args.yes and input("Install this complete stack? [y/N] ").strip().lower() not in {"y", "yes"}:
            print("Installation cancelled.")
            return 0
        execute(phases)
        print("\nInstalled. Reboot when convenient, then select Qubes HUD (i3) at login. "
              "Existing qubes receive their new template files on their next start.")
        return 0
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, EOFError) as error:
        print("Installer stopped: " + str(error), file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nInterrupted. Inspect VM states before rerunning; no automatic shutdown was requested.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
