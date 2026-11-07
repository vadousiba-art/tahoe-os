# Kiri Studio — Tahoe Edition
## Phase 1: Compatibility Report & Implementation Plan

Status: **waiting for your approval and your machine's inspection report.** Nothing has been built or changed yet.

---

## 0. Read this first: what I could and couldn't inspect

You asked me to inspect your Linux distribution, desktop, hardware, storage, themes, panels and dependencies first. This session runs in a **cloud container, not on your MacBook Air.** No computer of yours is connected to it, so I can't read your system directly.

Here's what I did instead:

1. **Wrote a read-only inspector**, `tools/kiri-inspect.sh`, for you to run on the MacBook. It collects everything this plan depends on and changes nothing (details in §1).
2. **Checked the real package versions** in the Ubuntu 24.04 "noble" archive, the base of Ubuntu MATE 24.04 LTS, so the plan rests on facts rather than guesses (§2.2).
3. **Wrote the rest of this plan against a stated baseline.** Every assumption is marked ⚠ and will be confirmed or corrected from your report before I build anything.

---

## 1. Run the inspector on your MacBook (2 minutes)

```bash
wget https://raw.githubusercontent.com/vadousiba-art/tahoe-os/claude/stoic-volta-f5wdqd/tools/kiri-inspect.sh
```

```bash
bash kiri-inspect.sh
```

If the repository is private, `wget` won't work. Open `tools/kiri-inspect.sh` on GitHub, choose **Raw**, save the file, and run the second command.

What the inspector does:
- **Uses no sudo** and refuses to run as root.
- **Changes no settings, themes or packages.** It only reads.
- **Writes one file**, `~/kiri-compat-report.txt`, with permissions 600 (only you can read it).
- **Takes about 3 seconds.** Every command has a time limit.
- **Redacts identifying data:** usernames, hostnames, MAC addresses, IP addresses and the path to your home folder. It never collects Wi-Fi network names or serial numbers.
- **Was tested before release:** ShellCheck-clean, and test-run as a non-root user.

When it finishes, paste the contents of `~/kiri-compat-report.txt` back into this session.

What it collects, grouped by what each group decides:

| Section | Why it matters |
|---|---|
| Distribution, MATE, panel, Marco and Caja versions; X11 or Wayland | Which APIs, compositor features and theme formats I can target |
| Model, CPU, RAM, swap/zram, temperatures, fan daemon | Performance budgets; whether "Visual" mode is realistic |
| GPU, OpenGL, resolution, DPI, scaling | Blur cost, HiDPI, correct sizes for the dock and menu bar |
| Wi-Fi driver (Broadcom `wl`?), rfkill, NetworkManager, BlueZ, audio server | Whether the Control Center controls can be real |
| Backlight, keyboard backlight, UPower battery data, logind brightness support | Brightness without root; battery-health display |
| Disk layout and free space; snap and flatpak usage | Space budget for the installer, assets and Flatpak apps |
| Current GTK, icon, cursor, font and wallpaper settings; installed themes | What to back up; conflicts with existing themes |
| Panel toplevels, applets, layouts, autostart entries | Exact panel state to back up and restore |
| Keyboard layout, shortcuts, touchpad settings | Free shortcuts for Spotlight and the Mac-style keyboard mapping |
| Notification daemon, AppMenu registrar, StatusNotifier watcher | Global menu and Notification Center feasibility |
| Python, PyGObject, GTK, all needed GI typelibs and Python modules | What the installer must pull in |
| APT sources, held or broken packages, availability of ~45 packages | Whether the .deb's dependencies are satisfiable |
| Memory used by each desktop process right now | Baseline for the RAM budget |

---

## 2. Compatibility report (provisional)

### 2.1 Assumed baseline ⚠ (your report will confirm or correct it)

| Item | Assumed | Implication |
|---|---|---|
| Distribution | Ubuntu MATE 24.04 LTS (noble). 26.04 LTS is also possible. | Both are supported; the version table in §2.2 differs slightly for 26.04 |
| Session | MATE on **X11** with the Marco window manager | Everything below is X11-based. MATE on Wayland is experimental, and I won't target it. |
| Model | MacBookAir6,1 (11") or MacBookAir6,2 (13"), 2014 | 1366×768 or 1440×900 panel, no HiDPI. Sizes are tuned for these. |
| CPU / GPU | Intel Core i5-4260U, Intel HD Graphics 5000 (Haswell), Mesa i915/crocus | GLX compositing with moderate blur is fine. Full-screen blur on every window costs about 5–10 % GPU and battery. |
| RAM | 4 GB, no zram ⚠ | Strict memory budget (§5). Kiri will *recommend* zram and won't force it. |
| Wi-Fi | Broadcom BCM4360, `wl` driver from `bcmwl-kernel-source` | Kiri won't touch the driver. If Wi-Fi works now, the Control Center's Wi-Fi control works too. |
| Camera | FaceTime HD, no in-kernel driver | Not used. No camera controls are planned. |
| Storage | 128 GB SSD | Installer target is under 60 MB. Optional downloads show their size, and storage limits are enforced. |

### 2.2 Verified package availability (Ubuntu 24.04 archive, checked today)

| Component | Package version | Verdict |
|---|---|---|
| Panel / menu bar host | `mate-panel` 1.27.1 | ✅ |
| Window manager | `marco` 1.26.2 | ✅ Metacity-format window themes, with buttons on the left |
| File manager (current) | `caja` 1.26.3 | ✅ Kept installed as the fallback |
| Global application menu | `mate-applet-appmenu` / `vala-panel-appmenu` 0.7.6, `appmenu-gtk3-module` | ✅ Works for GTK2/GTK3/Qt5 apps, LibreOffice and most others. ⚠ Snap Firefox, most Electron apps and GTK4 apps don't export menus; those show the app name only, as in macOS. |
| Dock | `plank` 0.11.89 | ✅ Magnification (zoom), running indicators, favorites, auto-hide/intellihide, all four screen edges, custom themes. About 25–35 MB of RAM. |
| Compositor | `picom` **10.2** | ✅ Rounded corners, shadows, dual-kawase blur, fades, per-window rules. ⚠ No open/close/minimize animations; those need picom 12 or newer, which noble doesn't have. See §3.3. |
| Window overview | `skippy-xd` | ❌ Not in the archive. Mission Control will be built in Kiri (§3.5). |
| Python + GTK | `python3-gi` 3.48.2 with GTK 3.24 | ✅ |
| Window tracking | `gir1.2-wnck-3.0` 43.0 | ✅ |
| Wi-Fi | `gir1.2-nm-1.0` 1.46 (libnm) | ✅ Real scan, connect and disconnect |
| Sound | `python3-pulsectl` 23.5 | ✅ Works with PulseAudio and with PipeWire's PulseAudio layer |
| Panel applets in Python | `gir1.2-matepanelapplet-4.0` | ✅ |
| Image handling | `python3-pil` 10.2, `python3-numpy` 1.26 | ✅ Image sanitizing and screenshot comparison |
| UI font | `fonts-inter` 4.0 (SIL Open Font License) | ✅ The closest freely licensed match to SF Pro |
| Login screen | `slick-greeter` 2.0.1 / `arctica-greeter` | ✅ Background, theme, icons, font and clock are configurable |
| File search | `plocate` 1.1.19 | ✅ Fast file search for Spotlight without a new indexing service |
| Night Shift | `redshift-gtk` 1.12 | ✅ Optional |
| Flatpak | `flatpak` 1.14.6 | ✅ Per-user installs from Flathub, no root needed |
| Graphical .deb install | `gdebi` 0.9.5 | ✅ Optional; `apt install ./file.deb` also works |
| Notifications (current) | `mate-notification-daemon` 1.26.1 | Kiri takes over the notification service while it's active and hands it back on restore |

### 2.3 What's possible, honestly

| Requested | Achievable on MATE/X11 | Notes |
|---|---|---|
| Transparent menu bar: app menus, clock, indicators | ✅ High fidelity | Hosted in mate-panel with Kiri applets and the appmenu applet; see the global-menu caveat above |
| Liquid Glass dock: magnification, indicators, favorites, auto-hide | ✅ Mostly | Translucent tint, edge highlight and blur behind the dock. Real optical refraction isn't possible with an X11 compositor; the effect is approximated with blur plus layered gradients. |
| Control Center: Wi-Fi, Bluetooth, sound, brightness, battery, appearance | ✅ All real | Pairing a *new* Bluetooth device opens Blueman, just as macOS sends you to Settings |
| Notification Center: grouping, history, Do Not Disturb | ✅ | Kiri implements the freedesktop notification spec 1.2: actions, urgency, grouping, Do Not Disturb with a schedule |
| Finder-like file manager: tabs, previews, search, sidebar, multiple views | ✅ | Decision A (§8) |
| Spotlight with a keyboard shortcut | ✅ | Super+Space |
| System Settings | ✅ | "Kiri Settings". System areas Kiri doesn't own (printers, users, displays) open the matching MATE tool and say so. |
| Rounded windows, shadows, dialogs, transitions | ✅ / ◐ | Corners, shadows and fades work. Window open/close/minimize animation is limited by picom 10.2. |
| Workspace management / Mission Control | ◐ | Built in Kiri: workspaces strip, window grid, hot corners. Window thumbnails come from the compositor where possible, with an icon fallback. |
| Lock screen | ◐ | GTK-themed unlock dialog plus a Kiri backdrop (blurred wallpaper and large clock). mate-screensaver's layout can't be fully redesigned. |
| Login screen | ✅ (system change, confirmation required) | slick-greeter configuration; the original is backed up |
| Boot splash, GRUB, Plymouth | ❌ Not touched | Out of scope by your own safety rules |
| Real Apple wallpapers, icons and SF fonts bundled | ❌ Not allowed | Apple's license limits them to Apple systems. Kiri ships open-licensed look-alikes and lets **you** import assets you're authorized to use (§3.7). |

---

## 3. Architecture

### 3.1 Design principles
- **One resident Kiri process.** `kiri-shell` hosts the menu-bar applets, Control Center, Notification Center, Spotlight, Launchpad, Mission Control, hot corners and widgets. One Python runtime instead of six keeps RAM down. Kiri Settings, Kiri Finder, the Asset Library and the App Library run only while open.
- **No polling.** Everything is event-driven (D-Bus signals, Wnck, GIO file monitors, X events). Hot corners use invisible 1-pixel windows rather than tracking the mouse.
- **No new background services.** No indexer daemon and no updater daemon. Online features are off until you turn them on.
- **Reuse what MATE already runs.** mate-panel becomes the menu bar, Marco stays the window manager, Caja stays installed. The original desktop environment is never removed.

### 3.2 Components

```
/usr/bin/kiri-studio            Kiri Settings (also the setup assistant on first run)
/usr/bin/kiri-shell             resident shell process (autostart; one process)
/usr/bin/kiri-finder            file manager
/usr/bin/kiri-restore           standalone restore tool (also works from a text console)
/usr/lib/kiri-studio/kiri/      Python package
    core/      config, profiles, backup journal, restore, policy-gated helper client
    theme/     GTK3/GTK4/Marco/Plank/picom theme generator (presets, accent, alpha)
    shell/     menubar applets, control center, notifications, spotlight,
               launchpad, mission control, hot corners, widgets
    finder/    file manager
    assets/    online search, import, sanitizer, collections, icon matcher, compare
    apps/      app catalogue, APT/Flatpak backends
/usr/libexec/kiri-studio/kiri-helper   root helper (allow-listed actions only; PolicyKit)
/usr/share/polkit-1/actions/org.kiri.studio.policy
/usr/share/kiri-studio/         themes, icons, cursors, wallpapers (open-licensed), catalogue
/usr/share/themes/Kiri-Tahoe-*  GTK + Marco themes
/usr/share/icons/Kiri-Tahoe*    icon and cursor themes
/etc/xdg/autostart/kiri-shell.desktop   (does nothing until setup has completed for that user)
```

### 3.3 Themes and the window system
- **GTK3 theme "Kiri-Tahoe"**: written for Kiri, drawing on MIT-licensed WhiteSur where useful, with attribution. Presets are generated, not hand-copied: **Light, Dark, Clear** (more translucent), **Tinted** (wallpaper-derived accent) and **Custom**. The generator writes a per-user copy to `~/.local/share/themes/Kiri-Tahoe-Custom` with your accent, transparency, corner radius and fonts. This is fast, needs no root, and is fully removable.
- **GTK4/libadwaita apps** get matching colors through `~/.config/gtk-4.0/gtk.css`. That covers colors only; the shapes can't be restyled.
- **Marco window theme**: Tahoe-style title bars with traffic-light buttons on the left (`close,minimize,maximize:`), hover glyphs, and a separate style for unfocused windows.
- **picom profile** generated per performance mode: corner radius, shadows, blur rules (menu bar, dock, popovers, Control Center, optionally terminals) and fades. Marco's own compositor is switched off only while picom runs, and restored afterwards.
- **Animations**: picom 10.2 handles fades. Kiri's own surfaces (Control Center, Spotlight, Launchpad, Mission Control, notification banners) get real GTK animations with spring-like easing. Window open/close/minimize "genie" animations aren't possible with the stock picom. **Optional (Decision D):** build picom 12 from source into the .deb to get them. It works, but it's a native binary I would then maintain.
- **Fonts**: Inter as the UI font, with sizes tuned to match the SF Pro metrics macOS uses. If you own SF Pro under a license that permits it, you can import it in Settings → Fonts. Kiri never downloads it.
- **Cursors and icons**: open-licensed macOS-style themes, with pinned versions, license files included and checked before packaging. Kiri-drawn folder icons come in every accent color.

### 3.4 Menu bar and shell
- **Menu bar**: the top mate-panel, about 24 px tall, translucent with blur behind. Left to right: Kiri "system menu" applet (About This Computer, System Settings, App Library, Force Quit, Sleep, Restart, Shut Down, Lock Screen, Log Out — every item works), bold app name, global app menu, then on the right the system tray (Ayatana indicators), Wi-Fi, battery, Control Center, Spotlight, and a date/time applet that opens the Notification Center. Kiri Settings controls which indicators appear and how the clock is formatted. The previous panel layout is backed up exactly.
- **Control Center**: a glass popover with modules for Wi-Fi (scan, connect, password prompt, disconnect), Bluetooth (power, paired devices, connect/disconnect), Do Not Disturb (with timers), Display brightness (via logind, no root), Keyboard brightness (UPower), Sound (volume, mute, output device), Battery (percentage, time remaining, health), Appearance (Light/Dark/Auto) and an optional Night Shift. Modules can be reordered and hidden. **A module is never shown unless its hardware or service exists.**
- **Notification Center**: owns the system notification service while active. Banners appear top-right; history is grouped by app with clear-one and clear-all; Do Not Disturb supports a schedule. Each app can be set to banners, list-only or off. History is capped and stored per user.
- **Spotlight** (Super+Space): searches apps, Kiri Settings panes, recent files, files via plocate (limited to your home folder), the calculator (a safe parser — Kiri never `eval`s input) and unit conversion, and offers "search the web" in your default browser. Keyboard-first and instant on open.
- **Launchpad** (F4, or a dock icon): a paged app grid with search and folders.
- **Mission Control** (Ctrl+Up, or a hot corner): a workspace strip plus a window grid, with drag-and-drop of windows between workspaces. Ctrl+Left/Right switches workspaces.
- **Desktop widgets**: Clock, Calendar, Battery, Notes, and Weather (Open-Meteo, no account needed, online opt-in). All off in Low Resource mode.

### 3.5 Dock (Plank, Kiri-themed)
- Liquid Glass theme family: tint, edge highlight, inner glow, running dots, separator, and magnification amount (zoom 100–200 %).
- Position, size, auto-hide/intellihide, favorites, "show recent apps", and an optional Trash/Downloads stack (built in Kiri).
- Fully reversible: Kiri uses its own named Plank dock profile and never edits the default one.

### 3.6 Kiri Finder (see Decision A)
GTK3 + GIO, so all file operations go through GLib's well-tested copy/move/trash code.
- Tabs, sidebar (Favorites, Locations, Tags, Trash, connected drives, network), toolbar with back/forward, view switcher and search.
- Four views: **Icon, List (sortable columns), Column (Miller columns), Gallery.**
- **Quick Look** with the space bar: images, text and code, PDF thumbnails, audio and video via GStreamer if installed.
- Search: by name live in the current folder, or across your home folder via plocate.
- Deleting moves items to the Trash. Permanent deletion always asks first. Copy and move progress has a cancel button. Undo works for rename, move and trash.
- Caja stays installed and keeps drawing the desktop icons, unless you choose Kiri's desktop instead.

### 3.7 Asset and reference library

**Sources Kiri can legitimately search:**
- **Openverse API** and **Wikimedia Commons API**: both return per-file license and author metadata.
- **Apple's official pages** (apple.com/macos, Newsroom, the Human Interface Guidelines, Apple Design Resources) as **reference links**. They open in your browser and are never scraped.
- **Import from a URL or local file**, for anything you're authorized to use.
- Optionally, an image-search API that takes your own key (for example Brave Search). Scraping Google or Bing images is against their terms, so Kiri won't do it.

**License handling:** every item stores its source URL, author, license and download date. Apple-owned material is labelled "Apple — proprietary, personal reference only". Kiri never re-uploads, shares or bundles it.

**Safe import pipeline:**
- Every download lands in a quarantine folder, capped at 25 MB.
- The real file type is identified from its content (magic bytes), not its extension.
- Images (PNG, JPG, WebP, ICO) are decoded and then **re-encoded** to PNG or JPEG. This strips metadata and any hidden embedded data.
- SVGs are cleaned against a whitelist: scripts, `foreignObject`, external references and event attributes are removed, and the file is test-rendered before it's accepted.
- Files are stored without execute permission. **Downloaded files are never run or opened by a handler chosen from the file itself.**

**Organizing:** Wallpapers, Icons and References collections plus your own; tags; download history; per-collection storage use; a quota and a cleanup tool.

**Applying icons:** to apps, dock items and launchers through a per-user "Kiri-Custom" icon theme that inherits the base theme, plus reversible `.desktop` overrides. Auto-matching uses app ID, `StartupWMClass` and fuzzy name matching, and you confirm each match before it's applied.

**Comparison tool:** captures a Kiri screenshot and compares it with a Tahoe reference screenshot you provide. It produces:
- a structural-similarity (SSIM) score per region (menu bar, dock, windows, Control Center),
- color and contrast differences,
- an edge-difference heat map,
- a defect list with hints such as "menu bar 2 px taller" or "dock tint too dark".

It's a measurement aid, not pixel-perfect proof.

### 3.8 App library
- A bundled catalogue of about 60 apps, each with a description, category, size and source: productivity (LibreOffice, Thunderbird, Joplin), creative (GIMP, Inkscape, Krita, Darktable, Kdenlive, Audacity), development (VS Code from Microsoft's Flathub listing, Geany, Git tools), media (VLC, mpv, Rhythmbox) and utilities.
- Screenshots load on demand from Flathub's and Debian's screenshot services.
- **APT** installs go through the root helper, which only accepts package names from the catalogue's allow-list. It never runs arbitrary commands.
- **Flatpak** installs are per-user from Flathub. Kiri warns that the first Flatpak app downloads a shared runtime of roughly 600 MB to 1 GB.
- Install and remove only happen when you press the button, with a confirmation and a progress bar. Nothing is ever installed automatically.

---

## 4. Safety and recovery

1. **A snapshot before every change.** Kiri takes a full `dconf dump /` plus copies of every file it will touch (GTK config, autostart entries, Plank, picom, `.desktop` overrides). The snapshot goes in `~/.local/share/kiri-studio/backups/<timestamp>/`, and a journal records each individual change.
2. **A standalone restore tool**, `restore.sh`, is copied into each backup. It needs only bash and dconf, so it works even if Kiri is broken or uninstalled. It also runs from a text console (Ctrl+Alt+F3).
3. **Restoration after a plain `apt remove`.** A small per-user login item notices that Kiri is gone, asks you once, and restores the snapshot.
4. **Crash protection.** If `kiri-shell` crashes three times within a minute, it stops itself and puts back the original notification service and panel.
5. **System-level changes** are only: installing or removing packages, the login screen configuration, and optional system-wide themes. Each one shows exactly what will change, asks for confirmation, uses PolicyKit, and backs up the original under `/var/backups/kiri-studio/`.
6. **Never touched:** partitions, bootloader/GRUB, Plymouth, initramfs, kernel, drivers, APT sources, your files outside Kiri's own folders, and the MATE packages themselves.
7. **Profiles:** save, load, export and import as validated JSON. "Reset to Tahoe defaults" and "Restore my original desktop" are two separate buttons.

---

## 5. Performance modes and budget (4 GB RAM target)

| | Low Resource | Balanced (default) | Visual |
|---|---|---|---|
| Compositor | Marco built-in | picom: GLX backend, shadows, corners, blur on menu bar and dock only | picom: blur on all Kiri surfaces and chosen windows, fades |
| Dock | Plank, no zoom | Plank with zoom | Plank, zoom plus glass highlight |
| Shell animations | Off | Short | Full |
| Widgets | Off | Up to 2 | Any |
| Added RAM target | ≤ 90 MB | ≤ 150 MB | ≤ 190 MB |
| Idle CPU target | ~0 % | < 1 % | < 2 % |

Kiri measures and shows its own memory use in Settings → Performance. Every number above will be verified on your MacBook during QA. Your report tells me the baseline.

---

## 6. Installer and packaging

- **The download:** `KiriStudio-Tahoe-Installer.deb` (architecture `all`, pure Python plus data, target under 60 MB). It's built reproducibly by GitHub Actions and published as a GitHub Release.
- **Installing:**
  - Double-click it to open in GDebi or the Software app, or
  - run `sudo apt install ./KiriStudio-Tahoe-Installer.deb`.
  - Either way APT resolves every dependency from the official Ubuntu archive. Nothing comes from PPAs.
- **Graphical setup:** on first launch, the **Kiri Setup Assistant** checks dependencies and hardware, takes the backup, shows a preview, offers Low/Balanced/Visual and the optional extras, asks for confirmation, then applies the changes with a progress display and offers to log you out and back in.
- **Uninstalling:** Kiri Settings → *Restore & Uninstall* restores your original desktop first, then removes the package. `sudo apt remove kiri-studio` is also safe (see §4.3).

---

## 7. Development milestones and QA

| # | Milestone | Done when |
|---|---|---|
| M0 | Core: config, profiles, backup journal, `restore.sh`, root helper, PolicyKit policy | A backup→apply→restore round trip gives a byte-identical `dconf dump`, tested automatically |
| M1 | Themes: GTK3/GTK4/Marco/Plank/picom generator and the 5 presets | Screenshots of every widget-gallery state in light and dark at 1× and 1.25× scaling |
| M2 | Shell: menu bar, Control Center, Notification Center, Spotlight, Launchpad, Mission Control, hot corners, widgets | Every control is driven by an automated accessibility-tree (AT-SPI) test |
| M3 | Kiri Settings: all panes, performance modes, profiles | Every setting changes something real (tested); reset and import/export work |
| M4 | Kiri Finder | File-operation tests on a scratch tree, including trash, undo, cancel and permissions |
| M5 | Asset library and comparison | A malicious-file corpus (SVG scripts, polyglots, oversized images) is rejected or neutralized |
| M6 | App library | APT/Flatpak install and remove in a disposable test container |
| M7 | Setup Assistant, .deb, uninstall | Clean-container install, purge and restore tests; lintian clean |
| M8 | Full QA pass on your hardware, defect list, fixes, release | The checklist below passes; the defect list is closed or documented |

**QA I can run in the cloud.** A disposable Ubuntu MATE environment under a virtual display (Xvfb) with real Marco, mate-panel, Plank and picom. In it:
- screenshots of every screen and state;
- AT-SPI checks that every button, menu item and switch has a working handler (**no dead controls**);
- keyboard-shortcut tests;
- alignment and spacing measurements;
- memory-use measurements;
- install/remove/restore tests.

**QA only you can run.** Real Wi-Fi, Bluetooth, brightness and battery hardware; GPU smoothness on the HD 5000; login, logout and reboot. For these I'll ship `kiri-studio --self-test` and a guided checklist that produce a report to paste back, the same way as the inspector.

**Reference screenshots.** I won't commit Apple screenshots to the repository. Comparisons against real Tahoe use references you keep locally. In CI, Kiri is checked against a measurement table of the Tahoe layout: menu bar height, dock geometry, corner radii, spacing, type sizes.

**Effort, honestly.** This is a large project, several sessions of work. I'll deliver it milestone by milestone on this branch, each one tested and working. Anything that can't be made to work for real won't be shown in the interface; it will be listed here instead.

---

## 8. Decisions I need from you

**A. File manager**
- **Recommended:** a new *Kiri Finder* (column view, gallery, Quick Look, Finder-style layout), with Caja kept as the fallback and for desktop icons.
- Alternative: restyle Caja and add a Quick Look add-on. That's lower risk, but there's no column view or gallery view and it looks less like Finder.

**B. Menu bar host**
- **Recommended:** mate-panel (it's already running, so no extra RAM, and it's the most reliable).
- Alternative: a custom Kiri bar. That gives more visual freedom but costs extra RAM and means re-implementing the system tray.

**C. Bundled open-source macOS-style icon, cursor and theme components (GPL/MIT, credited)**
- **Recommended:** yes, with pinned versions plus Kiri-drawn pieces. You get a complete icon set from day one.
- Alternative: Kiri-drawn icons only. Smaller and legally simplest, but many apps would keep generic icons until you import your own.

**D. picom 12 built from source and bundled** (adds open/close/minimize window animations)
- **Recommended:** no. Stay with the archive's picom 10.2 for reliability.
- Alternative: yes, at the cost of a native binary I'd have to maintain.

**E. Online features (asset search, weather, app screenshots)**
- **Recommended:** off until you turn them on.

**F. Release channel**
- **Recommended:** a GitHub Release on `vadousiba-art/tahoe-os`. If the repository is private, the download link only works for people with access.

**To approve,** paste your `kiri-compat-report.txt` and either reply "approved" (all the recommended options) or list your choices, for example "A: Caja, D: yes".
