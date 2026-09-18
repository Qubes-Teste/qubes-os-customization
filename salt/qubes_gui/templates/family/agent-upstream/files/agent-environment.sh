# Qubes HUD Agent upstream software v1
# Template-owned programs precede private/local copies; accounts stay in HOME.
for qubes_hud_bin in /opt/qubes-hud-agent/signal /opt/qubes-hud-agent/npm/node_modules/.bin /opt/qubes-hud-agent/node/bin; do
    case ":$PATH:" in
        *":$qubes_hud_bin:"*) ;;
        *) PATH="$qubes_hud_bin:$PATH" ;;
    esac
done
unset qubes_hud_bin
export PATH
