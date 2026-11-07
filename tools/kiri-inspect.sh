#!/usr/bin/env bash
# Kiri Studio — Tahoe Edition: read-only compatibility inspector.
#
# WHAT IT DOES
#   Collects facts about this computer (distribution, MATE version, hardware,
#   graphics, storage, themes, panels, compositor, audio/network stack and
#   available packages) and writes them to ONE text file in your home folder.
#
# WHAT IT NEVER DOES
#   * No sudo, no root, no package installs, no settings changes.
#   * It does not change dconf/gsettings, themes, panels or any config file.
#   * The only file it writes is the report (path printed at the end).
#   * Privacy: MAC addresses, serial numbers, Wi-Fi network names, IP
#     addresses, your username and your hostname are left out or redacted.
#
# USAGE
#   bash kiri-inspect.sh            # writes ~/kiri-compat-report.txt
#   bash kiri-inspect.sh -o FILE    # writes FILE instead
#   bash kiri-inspect.sh --stdout   # prints only, writes nothing

set -u
export LC_ALL=C

OUT="${HOME}/kiri-compat-report.txt"
TO_STDOUT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift 2 ;;
    --stdout) TO_STDOUT=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ "$(id -u)" -eq 0 ]; then
  echo "Please run this as your normal user, not with sudo." >&2
  exit 1
fi

USER_NAME="$(id -un)"
HOST_NAME="$(hostname 2>/dev/null || echo host)"

have() { command -v "$1" >/dev/null 2>&1; }

# Strip identifying data from any text that passes through.
redact() {
  sed -E \
    -e 's/([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}/<mac>/g' \
    -e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/<ip>/g' \
    -e "s#/home/${USER_NAME}#~#g" \
    -e "s/\b${USER_NAME}\b/<user>/g" \
    -e "s/\b${HOST_NAME}\b/<host>/g"
}

section() { printf '\n==================== %s ====================\n' "$1"; }
kv() { printf '%-34s %s\n' "$1:" "$2"; }

# Run a command with a time limit; print its output or a note.
run() {
  local label="$1"; shift
  if ! have "$1"; then kv "$label" "(not installed: $1)"; return; fi
  local out
  out="$(timeout 10 "$@" 2>&1)" || true
  if [ -z "$out" ]; then kv "$label" "(no output)"; return; fi
  if [ "$(printf '%s\n' "$out" | wc -l)" -le 1 ]; then
    kv "$label" "$out"
  else
    printf '%s:\n' "$label"; printf '%s\n' "$out" | sed 's/^/    /'
  fi
}

gs() { # gsettings get, quietly
  have gsettings || { echo "(gsettings missing)"; return; }
  timeout 5 gsettings get "$1" "$2" 2>/dev/null || echo "(schema/key not present)"
}

pkgver() { # installed version or candidate from apt cache, no network
  local p="$1" inst cand
  inst="$(dpkg-query -W -f='${Status} ${Version}' "$p" 2>/dev/null | awk '/install ok installed/{print $4}')"
  cand="$(apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/{print $2}')"
  printf '%-34s installed=%-22s available=%s\n' "$p" "${inst:-no}" "${cand:-none}"
}

list_dir() { # list theme/icon dirs compactly
  local d="$1"
  if [ -d "$d" ]; then
    local items; items="$(find "$d" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -printf '%f\n' 2>/dev/null | sort | tr '\n' ' ')"
    kv "$d" "${items:-(empty)}"
  else
    kv "$d" "(does not exist)"
  fi
}

report() {
  echo "Kiri Studio — Tahoe Edition compatibility report"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)   inspector v1.0 (read-only)"

  section "1. DISTRIBUTION & SESSION"
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    kv "Distribution" "${PRETTY_NAME:-?}"
    kv "Version codename" "${VERSION_CODENAME:-?}"
  fi
  run "lsb_release" lsb_release -ds
  kv "Kernel" "$(uname -r) ($(uname -m))"
  kv "XDG_CURRENT_DESKTOP" "${XDG_CURRENT_DESKTOP:-unset}"
  kv "XDG_SESSION_TYPE" "${XDG_SESSION_TYPE:-unset}"
  kv "DESKTOP_SESSION" "${DESKTOP_SESSION:-unset}"
  kv "Display server DISPLAY" "${DISPLAY:-unset}"
  kv "WAYLAND_DISPLAY" "${WAYLAND_DISPLAY:-unset}"
  run "mate-session version" mate-session --version
  run "mate-panel version" mate-panel --version
  run "marco (window manager)" marco --version
  run "caja (file manager)" caja --version
  kv "Running WM / panels" "$(ps -eo comm= 2>/dev/null | grep -xE 'marco|compiz|metacity|xfwm4|openbox|picom|compton|xcompmgr|mate-panel|plank|docky|cairo-dock|latte-dock|tint2|vala-panel|ulauncher|albert|synapse|mate-hud|mate-notificati|notify-osd|dunst|xfce4-notifyd|caja|mate-screensave|light-locker|xscreensaver' | sort -u | tr '\n' ' ')"
  kv "Display manager" "$(cat /etc/X11/default-display-manager 2>/dev/null || echo unknown)"
  kv "LightDM greeter config files" "$(ls /etc/lightdm/ 2>/dev/null | tr '\n' ' ')"
  kv "Greeter processes/packages" "$(dpkg-query -W -f='${Package} ' slick-greeter arctica-greeter lightdm-gtk-greeter unity-greeter 2>/dev/null)"
  kv "Init" "$(ps -p 1 -o comm= 2>/dev/null)"
  run "systemd version" sh -c 'systemctl --version | head -1'

  section "2. HARDWARE"
  kv "Model" "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null) $(cat /sys/class/dmi/id/product_version 2>/dev/null)"
  kv "Board" "$(cat /sys/class/dmi/id/board_name 2>/dev/null)"
  kv "Firmware" "$(cat /sys/class/dmi/id/bios_version 2>/dev/null) $(cat /sys/class/dmi/id/bios_date 2>/dev/null)"
  kv "CPU" "$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
  kv "CPU threads" "$(nproc 2>/dev/null)"
  kv "CPU governor" "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
  run "Memory" free -h
  run "Swap devices" sh -c 'cat /proc/swaps'
  kv "zram" "$(find /sys/block -maxdepth 1 -name 'zram*' 2>/dev/null | wc -l) device(s)"
  kv "Load average" "$(cut -d' ' -f1-3 /proc/loadavg)"
  kv "Uptime" "$(uptime -p 2>/dev/null)"
  run "PCI graphics/network/audio" sh -c "lspci -nn 2>/dev/null | grep -iE 'vga|3d|display|network|wireless|ethernet|audio'"
  run "USB devices" sh -c "lsusb 2>/dev/null | cut -d' ' -f6-"
  kv "Wi-Fi kernel driver(s)" "$(for i in /sys/class/net/*; do [ -d "$i/wireless" ] && basename "$(readlink -f "$i/device/driver" 2>/dev/null)"; done | sort -u | tr '\n' ' ')"
  kv "Loaded wl/brcm modules" "$(lsmod 2>/dev/null | awk '{print $1}' | grep -E '^(wl|brcmfmac|brcmsmac|b43|bcma|applesmc|hid_apple|bcm5974|facetimehd|i915)$' | tr '\n' ' ')"
  run "Backlight devices" sh -c 'for b in /sys/class/backlight/*; do [ -e "$b" ] && echo "$(basename "$b") brightness=$(cat "$b/brightness")/$(cat "$b/max_brightness") writable_by_me=$([ -w "$b/brightness" ] && echo yes || echo no)"; done'
  run "Keyboard backlight (LEDs)" sh -c 'ls /sys/class/leds 2>/dev/null | grep -i kbd'
  if have upower; then
    run "Batteries/AC (UPower)" sh -c "upower -e | while read -r d; do upower -i \"\$d\" | grep -E 'native-path|power supply|state|percentage|capacity|energy-full:|energy-full-design|technology|time to' ; echo; done"
  else
    kv "UPower" "(not installed)"
  fi
  kv "Temperatures" "$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | awk '{printf "%.0fC ", $1/1000}')"
  run "Fan control daemon" sh -c 'systemctl is-active mbpfan 2>/dev/null; systemctl is-active thermald 2>/dev/null'

  section "3. GRAPHICS & DISPLAY"
  run "Monitors (xrandr)" sh -c "xrandr --query 2>/dev/null | grep -E ' connected|\\*'"
  run "Screen DPI" sh -c "xdpyinfo 2>/dev/null | grep -E 'dimensions|resolution'"
  kv "Xft.dpi" "$(xrdb -query 2>/dev/null | grep -i dpi | awk '{print $2}')"
  kv "MATE window-scaling-factor" "$(gs org.mate.interface window-scaling-factor)"
  if have glxinfo; then
    run "OpenGL" sh -c "glxinfo -B 2>/dev/null | grep -E 'direct rendering|OpenGL vendor|OpenGL renderer|OpenGL core profile version|OpenGL version|Video memory|Accelerated'"
  else
    kv "OpenGL (glxinfo)" "(mesa-utils not installed — fine, optional)"
  fi
  run "Mesa/Intel driver pkgs" sh -c "dpkg-query -W -f='\${Package} \${Version}\n' libgl1-mesa-dri mesa-va-drivers intel-media-va-driver i965-va-driver xserver-xorg-video-intel 2>/dev/null"
  kv "X11 composite extension" "$(xdpyinfo 2>/dev/null | grep -c Composite) (1 = available)"
  kv "Marco compositing enabled" "$(gs org.mate.Marco.general compositing-manager)"
  kv "Marco theme" "$(gs org.mate.Marco.general theme)"
  kv "Marco button layout" "$(gs org.mate.Marco.general button-layout)"
  kv "Marco reduced resources" "$(gs org.mate.Marco.general reduced-resources)"
  kv "Workspaces count" "$(gs org.mate.Marco.general num-workspaces)"
  run "picom version" picom --version
  run "compton version" compton --version
  run "compiz version" compiz --version

  section "4. STORAGE"
  run "Filesystems" df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay
  run "Block devices" lsblk -o NAME,SIZE,TYPE,FSTYPE,ROTA,MOUNTPOINTS -e7
  kv "Home folder size" "$(du -sh "$HOME" 2>/dev/null | cut -f1)"
  kv "Home .cache size" "$(du -sh "$HOME/.cache" 2>/dev/null | cut -f1)"
  kv "APT cache size" "$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)"
  kv "Snap usage" "$(du -sh /var/lib/snapd 2>/dev/null | cut -f1)"
  kv "Flatpak usage" "$(du -sh /var/lib/flatpak "$HOME/.local/share/flatpak" 2>/dev/null | cut -f1 | tr '\n' ' ')"
  kv "TRIM timer" "$(systemctl is-enabled fstrim.timer 2>/dev/null)"

  section "5. APPEARANCE (current, read-only)"
  kv "GTK theme" "$(gs org.mate.interface gtk-theme)"
  kv "Icon theme" "$(gs org.mate.interface icon-theme)"
  kv "Cursor theme" "$(gs org.mate.peripherals-mouse cursor-theme)"
  kv "Cursor size" "$(gs org.mate.peripherals-mouse cursor-size)"
  kv "UI font" "$(gs org.mate.interface font-name)"
  kv "Document font" "$(gs org.mate.interface document-font-name)"
  kv "Monospace font" "$(gs org.mate.interface monospace-font-name)"
  kv "Titlebar font" "$(gs org.mate.Marco.general titlebar-font)"
  kv "Font antialiasing/hinting" "$(gs org.mate.font-rendering antialiasing) / $(gs org.mate.font-rendering hinting)"
  kv "Wallpaper" "$(gs org.mate.background picture-filename | redact)"
  kv "Desktop icons (Caja)" "$(gs org.mate.background show-desktop-icons)"
  kv "GTK color scheme pref" "$(gs org.gnome.desktop.interface color-scheme)"
  kv "User gtk-3.0/gtk.css" "$([ -f "$HOME/.config/gtk-3.0/gtk.css" ] && echo "exists ($(wc -l < "$HOME/.config/gtk-3.0/gtk.css") lines)" || echo absent)"
  list_dir /usr/share/themes
  list_dir "$HOME/.themes"
  list_dir "$HOME/.local/share/themes"
  list_dir /usr/share/icons
  list_dir "$HOME/.icons"
  list_dir "$HOME/.local/share/icons"
  kv "Font families installed" "$(fc-list : family 2>/dev/null | cut -d, -f1 | sort -u | wc -l)"
  kv "Inter / SF / Noto / Cantarell" "$(fc-list : family 2>/dev/null | grep -ciE '^(inter|sf pro|noto sans|cantarell)') matching faces"
  kv "Inter or SF present" "$(fc-list : family 2>/dev/null | grep -iE '^(inter|sf pro|sf compact|new york)' | cut -d, -f1 | sort -u | tr '\n' ';')"

  section "6. PANELS, APPLETS & LAYOUT"
  kv "Panel layout name" "$(gs org.mate.panel default-layout)"
  kv "Panel IDs" "$(gs org.mate.panel toplevel-id-list)"
  kv "Panel object IDs" "$(gs org.mate.panel object-id-list)"
  if have gsettings && gs org.mate.panel toplevel-id-list | grep -q '^\['; then
    for p in $(gs org.mate.panel toplevel-id-list | tr -d "[]',"); do
      base="org.mate.panel.toplevel:/org/mate/panel/toplevels/$p/"
      kv "  toplevel $p" "orient=$(timeout 3 gsettings get "$base" orientation 2>/dev/null) size=$(timeout 3 gsettings get "$base" size 2>/dev/null) expand=$(timeout 3 gsettings get "$base" expand 2>/dev/null) autohide=$(timeout 3 gsettings get "$base" auto-hide 2>/dev/null)"
    done
    for o in $(gs org.mate.panel object-id-list | tr -d "[]',"); do
      base="org.mate.panel.object:/org/mate/panel/objects/$o/"
      kv "  object $o" "type=$(timeout 3 gsettings get "$base" object-type 2>/dev/null) applet=$(timeout 3 gsettings get "$base" applet-iid 2>/dev/null) toplevel=$(timeout 3 gsettings get "$base" toplevel-id 2>/dev/null)"
    done
  fi
  kv "Panel layouts available" "$(ls /usr/share/mate-panel/layouts/ 2>/dev/null | tr '\n' ' ')"
  kv "Panel applets available" "$(ls /usr/share/mate-panel/applets/ 2>/dev/null | sed 's/\.mate-panel-applet//' | tr '\n' ' ')"
  kv "Plank docklets / themes" "$(ls /usr/share/plank/themes 2>/dev/null | tr '\n' ' ')"
  kv "MATE HUD enabled" "$(gs org.mate.hud enabled)"
  kv "Global menu GTK module" "$(gs org.mate.interface gtk-modules 2>/dev/null) | GTK_MODULES=${GTK_MODULES:-unset}"
  kv "Autostart (user)" "$(ls "$HOME/.config/autostart" 2>/dev/null | tr '\n' ' ')"

  section "7. KEYBOARD & INPUT"
  kv "Keyboard layout(s)" "$(gs org.mate.peripherals-keyboard-xkb.kbd layouts) options=$(gs org.mate.peripherals-keyboard-xkb.kbd options)"
  kv "Run-dialog shortcut" "$(gs org.mate.desktop.keybindings run-command 2>/dev/null) / marco: $(gs org.mate.Marco.global-keybindings panel-run-dialog)"
  kv "Main-menu shortcut" "$(gs org.mate.Marco.global-keybindings panel-main-menu)"
  kv "Custom keybindings" "$(dconf list /org/mate/desktop/keybindings/ 2>/dev/null | tr '\n' ' ')"
  run "Touchpad (synclient/libinput)" sh -c "xinput list --name-only 2>/dev/null | grep -iE 'touchpad|bcm5974|apple|keyboard'"
  kv "Natural scrolling" "$(gs org.mate.peripherals-touchpad natural-scroll)"
  kv "Tap to click" "$(gs org.mate.peripherals-touchpad tap-to-click)"
  kv "Fn key mode (hid_apple)" "$(cat /sys/module/hid_apple/parameters/fnmode 2>/dev/null || echo n/a)"

  section "8. SYSTEM SERVICES USED BY CONTROL/NOTIFICATION CENTER"
  kv "NetworkManager" "$(systemctl is-active NetworkManager 2>/dev/null) $(nmcli -v 2>/dev/null | head -1)"
  kv "Wi-Fi radio" "$(nmcli radio wifi 2>/dev/null)"
  kv "Wi-Fi devices (no names)" "$(nmcli -t -f TYPE,STATE device 2>/dev/null | grep -E '^wifi' | tr '\n' ' ')"
  kv "Bluetooth service" "$(systemctl is-active bluetooth 2>/dev/null)"
  run "rfkill" rfkill -n -o TYPE,SOFT,HARD
  kv "Blueman / bluetoothctl" "$(have blueman-manager && echo blueman) $(have bluetoothctl && echo bluetoothctl)"
  kv "Audio server" "$(pactl info 2>/dev/null | grep -E 'Server Name' | cut -d: -f2- | sed 's/^ //')"
  kv "PipeWire running" "$(pgrep -x pipewire >/dev/null && echo yes || echo no) / wireplumber: $(pgrep -x wireplumber >/dev/null && echo yes || echo no) / pulseaudio: $(pgrep -x pulseaudio >/dev/null && echo yes || echo no)"
  kv "Notification daemon owner" "$(dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner string:org.freedesktop.Notifications 2>/dev/null | awk '/string/{print $2}') ($(ps -eo comm= | grep -E 'notif|dunst' | sort -u | tr '\n' ' '))"
  kv "logind SetBrightness (systemd>=243)" "$(busctl --system introspect org.freedesktop.login1 /org/freedesktop/login1/session/auto 2>/dev/null | grep -c SetBrightness) (1 = available)"
  kv "AppMenu registrar on bus" "$(busctl --user list 2>/dev/null | grep -c com.canonical.AppMenu.Registrar) (1 = running)"
  kv "StatusNotifier watcher on bus" "$(busctl --user list 2>/dev/null | grep -cE 'org.kde.StatusNotifierWatcher') (1 = running)"
  kv "Screensaver/lock" "$(gs org.mate.screensaver lock-enabled) theme=$(gs org.mate.screensaver themes)"
  kv "Night light tools" "$(have redshift && echo redshift) $(have redshift-gtk && echo redshift-gtk)"
  kv "plocate/mlocate (Spotlight files)" "$(have plocate && echo plocate) $(have locate && echo locate) db_age=$(stat -c %y /var/lib/plocate/plocate.db 2>/dev/null | cut -d. -f1)"
  kv "Tracker (file indexer)" "$(have tracker3 && echo tracker3 || echo none)"

  section "9. SOFTWARE STACK & DEPENDENCIES"
  run "Python" python3 --version
  kv "PyGObject" "$(python3 -c 'import gi; print(gi.__version__)' 2>/dev/null || echo missing)"
  kv "GTK 3 via gi" "$(python3 -c 'import gi; gi.require_version("Gtk","3.0"); from gi.repository import Gtk; print("%d.%d.%d"%(Gtk.get_major_version(),Gtk.get_minor_version(),Gtk.get_micro_version()))' 2>/dev/null || echo missing)"
  for mod in Wnck:3.0 NM:1.0 MatePanelApplet:4.0 GdkPixbuf:2.0 Notify:0.7 GtkLayerShell:0.1 AyatanaAppIndicator3:0.1 Dbusmenu:0.4 Rsvg:2.0 Gio:2.0 WebKit2:4.1 Polkit:1.0 UPowerGlib:1.0; do
    n="${mod%%:*}"; v="${mod##*:}"
    kv "  gi $n $v" "$(python3 -c "import gi; gi.require_version('$n','$v'); from gi.repository import $n; print('ok')" 2>/dev/null || echo missing)"
  done
  for m in PIL numpy cairo dbus requests yaml; do
    kv "  python module $m" "$(python3 -c "import $m; print(getattr($m,'__version__','ok'))" 2>/dev/null || echo missing)"
  done
  kv "pkexec / polkit agent" "$(have pkexec && echo pkexec) $(ps -eo comm= | grep -m1 -E 'polkit-mate|polkit-gnome' || echo 'no-agent-running')"
  kv "dconf / gsettings" "$(have dconf && echo dconf) $(have gsettings && echo gsettings)"
  kv "Flatpak" "$(flatpak --version 2>/dev/null || echo not-installed) remotes: $(flatpak remotes --columns=name 2>/dev/null | tr '\n' ' ')"
  kv "Snap" "$(snap version 2>/dev/null | head -1 || echo not-installed)"
  kv "Snaps installed" "$(snap list 2>/dev/null | awk 'NR>1{print $1}' | tr '\n' ' ')"
  kv "GDebi (graphical .deb install)" "$(have gdebi-gtk && echo yes || echo no)"
  kv "Software Boutique / Synaptic" "$(have software-boutique && echo boutique) $(have synaptic && echo synaptic) $(have gnome-software && echo gnome-software)"
  kv "MATE Tweak" "$(have mate-tweak && echo yes || echo no)"
  kv "APT sources" "$(grep -rhE '^(deb|Types|URIs|Suites|Components)' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | sort -u | tr '\n' ' ' | redact)"
  kv "Held packages" "$(apt-mark showhold 2>/dev/null | tr '\n' ' ')"
  kv "Upgradable (from cache)" "$(apt list --upgradable 2>/dev/null | grep -vc Listing)"
  kv "Broken packages (dpkg audit)" "$(dpkg --audit 2>/dev/null | wc -l) line(s)"
  echo
  echo "Package availability (installed / candidate in your APT cache):"
  for p in mate-desktop-environment-core mate-panel marco caja mate-tweak \
           plank picom compiz skippy-xd \
           vala-panel-appmenu mate-applet-appmenu appmenu-gtk3-module appmenu-gtk2-module appmenu-registrar gir1.2-dbusmenu-gtk3-0.4 python3-pulsectl mate-notification-daemon \
           mate-hud brisk-menu ayatana-indicator-application mate-indicator-applet \
           python3-gi gir1.2-gtk-3.0 gir1.2-wnck-3.0 gir1.2-nm-1.0 gir1.2-matepanelapplet-4.0 \
           gir1.2-notify-0.7 gir1.2-rsvg-2.0 gir1.2-webkit2-4.1 gir1.2-dbusmenu-glib-0.4 \
           python3-pil python3-numpy python3-cairo python3-dbus python3-requests python3-yaml \
           policykit-1 pkexec polkitd flatpak gdebi plocate redshift-gtk \
           slick-greeter arctica-greeter lightdm mate-screensaver \
           fonts-inter fonts-noto-color-emoji \
           bcmwl-kernel-source broadcom-sta-dkms; do
    pkgver "$p"
  done

  section "10. RESOURCE SNAPSHOT (current session)"
  run "Top 12 processes by memory (RSS MB)" sh -c "ps -eo rss=,comm= --sort=-rss | head -12 | awk '{printf \"%7.1f MB  %s\n\", \$1/1024, \$2}'"
  kv "Total desktop RSS (mate*,caja,marco,plank,picom)" "$(ps -eo rss=,comm= | awk '$2 ~ /^(mate|caja|marco|plank|picom|compiz)/{s+=$1} END{printf "%.1f MB", s/1024}')"

  section "END"
  echo "Nothing on this system was modified. Paste this file back into the Kiri Studio session."
}

if [ "$TO_STDOUT" -eq 1 ]; then
  report | redact
else
  report | redact > "$OUT"
  chmod 600 "$OUT" 2>/dev/null || true
  echo "Report written to: $OUT"
  echo "Size: $(wc -l < "$OUT") lines. Review it, then paste it back into the session."
fi
