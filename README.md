# Steam Frame – Linux Setup Helper

An interactive, multilingual shell script that applies the known Linux tweaks for the
**Valve Steam Frame** and its Wi-Fi dongle: regulatory domain, iwd backend, Wi-Fi power
saving, roaming/scan behaviour, firewall rules, audio, the Steam PipeWire
launch option.

Every step shows what it is going to change (as a diff), asks before doing it, and backs
up every file it modifies. A `--dry-run` mode shows everything without touching the system.

---

## Please read this first

This is a small hobby project, not a product. It works on the machines it was built on, but
it is maintained by one person in their spare time.

**It needs `sudo`, and that deserves a moment's thought.** Most of the steps write to
`/etc`, install packages or restart services, so there is no way around root. At the same
time, the usual advice holds: do not hand root to a script you found on the internet
without looking at it. So please look at it. The code is deliberately split into small
files — one per menu entry under `steps/` — so each step can be read on its own in a minute
or two. Start the script with `--dry-run`: it prints every command and every file change as
a diff without touching anything.

**Use it at your own risk.** It changes network configuration, firewall rules and, on
Fedora, graphics drivers. Every step asks before it acts and backs up each file it
modifies, and menu entries **R**, **M** and **S** undo those changes again. Even so,
something can go wrong on a system that differs from the ones it was tested on. If your
machine matters to you, try it in a virtual machine first.

**On how it was written:** parts of this were written with AI assistance, if
you like. That is not an excuse for anything: every step was read through and tried out on
several machines here at home before it landed. But you should know, and it is one more
reason to read the code rather than trust it. Fixes and corrections are very welcome.

**No affiliation.** This project has nothing to do with Valve, and is not endorsed by Valve,
RPM Fusion or any of the other projects it touches. All trademarks belong to their owners.
The sources the steps are based on are credited under
[Credits and links](#credits-and-links).

**The code is free for anyone to use.** It is under the [MIT License](LICENSE), so use it,
change it, pass it on, build something else from it — keeping the copyright notice is the
only condition.

---

## Contents

- [Please read this first](#please-read-this-first)
- [Supported systems](#supported-systems)
- [Languages](#languages)
- [Quick start](#quick-start)
- [Command-line options](#command-line-options)
- [The steps in detail](#the-steps-in-detail)
- [Backups and undoing changes](#backups-and-undoing-changes)
- [Project layout](#project-layout)
- [Adding a language](#adding-a-language)
- [Troubleshooting](#troubleshooting)
- [Credits and links](#credits-and-links)
- [License](#license)

---

## Supported systems

| Family | Distributions | Package manager |
|---|---|---|
| Arch | Arch Linux, **CachyOS**, EndeavourOS, Manjaro | `pacman` |
| Fedora | **Fedora**, Nobara (Atomic variants such as Silverblue/Bazzite are detected and handled carefully) | `dnf` / `rpm-ostree` |
| Debian | **Debian**, **Ubuntu**, **Linux Mint**, Pop!_OS | `apt` |

The distribution is detected automatically from `/etc/os-release`.

**Requirements:** `bash`, `sudo` and **NetworkManager** (for the Wi-Fi steps). Missing tools
such as `iw`, `iwd` or `wget` are offered for installation when a step needs them.

## Languages

English · Deutsch · Español · Français · Português · 简体中文 · 日本語

The language is detected from `$LANG`. At startup you can confirm it with <kbd>Enter</kbd>
or pick a different one. You can also switch at any time with **L** in the main menu, or
start directly with `--lang <code>`.

---

## Quick start

1. **Get the files.** Download or clone this project and keep the folder structure intact.
   The main script loads `lib/`, `steps/` and `lang/` from its own folder.

2. **Make the script executable.** You only need to do this once:

   ```bash
   chmod +x steam-frame-setup.sh
   ```

3. **Try a dry run first.** It shows every command and file change without applying anything:

   ```bash
   ./steam-frame-setup.sh --dry-run
   ```

4. **Run it for real**, as your **normal user** (not with `sudo`). The script asks for
   your sudo password itself when it needs it:

   ```bash
   ./steam-frame-setup.sh
   ```

5. **Start with `1) System info / diagnostics`** to see the current state, then run the
   steps you need one by one. You will be asked before anything is changed.

6. **Reboot** when you are done. Several settings, such as the regulatory domain, kernel
   parameters and the iwd configuration, only take full effect after a reboot.

### Main menu

```
  ── Diagnostics
   1) System info / diagnostics

  ── Wi-Fi settings (old fixes)
   2) Set Wi-Fi regulatory domain
   3) NetworkManager → iwd backend
   4) Disable Wi-Fi power saving
   5) iwd: roaming threshold & scanning
   R) Undo Wi-Fi fixes

  ── System & multimedia
   6) Fedora: RPM Fusion / multimedia / Mesa freeworld
   7) Audio: PipeWire-Pulse
   M) Undo the Fedora multimedia changes

  ── Steam
   8) Start Steam with a PipeWire launch option
   S) Undo the Steam launch option

  ── Network & firewall
   9) Firewall rules (ufw / firewalld)
  10) Frame connection into zone 'trusted'

  ── Tools
  11) Dongle troubleshoot script (from Valve's GitHub repo)

   L) Language
   0) Quit
```

The headings are group labels only and cannot be selected. They come from the `MENU`
table in `steam-frame-setup.sh`: a `"#|key|"` row is a heading, `""` is a blank line.

## Command-line options

| Option | Description |
|---|---|
| `-n`, `--dry-run` | Only show what would be done; nothing is changed. |
| `-l`, `--lang <code>` | Interface language: `en`, `de`, `es`, `fr`, `pt`, `zh`, `ja`. |
| `-h`, `--help` | Show the help text. |

---

## The steps in detail

Each section explains **why** a step exists, **what the script does**, and **how to do it
by hand**, in case you prefer to apply it manually.

### 1) System info / diagnostics

Read-only. Shows distribution, kernel, bootloader, USB autosuspend value, Wi-Fi regulatory
domain, NetworkManager backend, iwd status and configuration, power-save state per Wi-Fi
interface, firewall, audio server, Steam Frame connection profiles and whether Steam has the
`-pipewire-dmabuf` option. Run this first and again after making changes.

### 2) Set Wi-Fi regulatory domain

**Why:** If the regulatory domain is `00` (world/minimal), many 5 GHz channels are restricted,
and the Frame's link suffers.

**You choose the country.** The script shows the current value (`iw reg get`) and then
offers:

| Entry | Meaning |
|---|---|
| `DE  (from your system language)` | The country your locale implies, e.g. `de_AT` → `AT`. Only offered when the locale implies one. |
| `FR  (currently active)` | The domain already in force, if it is set and differs from the first entry. |
| `Enter a country code` | Type any two-letter ISO code. |
| `Show all 181 known codes, then enter one` | Prints every code the local regulatory database knows, then asks. |

The entered code is checked against that database — `regdbdump` if installed, otherwise the
country list in `/etc/conf.d/wireless-regdom`. A code it does not know (a typo such as `GE`
for `DE`, say) is reported, because the kernel would silently ignore it; you can still
confirm it.

**What the script then does:**
- **Arch / CachyOS:** enables your country in `/etc/conf.d/wireless-regdom`
  (package `wireless-regdb`).
- **Fedora / Debian / Ubuntu / Mint:** writes
  `options cfg80211 ieee80211_regdom=XX` to `/etc/modprobe.d/cfg80211-regdom.conf`.
- Applies it immediately with `iw reg set XX`.

**By hand (Arch / CachyOS):**

```bash
iw reg get                                  # if it shows "country 00", continue
sudo nano /etc/conf.d/wireless-regdom       # remove the "#" in front of WIRELESS_REGDOM="DE"
sudo iw reg set DE
```

> Some cards, e.g. Intel cards marked "self-managed", ignore this setting and use their
> own country detection.

### 3) NetworkManager → iwd backend

**Why:** iwd was the most reliable Wi-Fi backend in the tests behind this script.

**What the script does:** installs `iwd` if needed, writes
`/etc/NetworkManager/conf.d/wifi_backend.conf`, enables `iwd.service` and, if you
confirm, restarts NetworkManager. This briefly drops your Wi-Fi connection. Saved
passwords are kept.

**By hand:**

```bash
sudo nano /etc/NetworkManager/conf.d/wifi_backend.conf
```

```ini
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=false
```

```bash
sudo systemctl enable iwd
sudo systemctl restart NetworkManager
```

To undo this, use **R) Revert iwd backend** in the menu.

### 4) Disable Wi-Fi power saving

**Why:** Power saving on the Wi-Fi adapter causes latency spikes and stutter while streaming.

**What the script does:**
- Lists your Wi-Fi interfaces with their driver, so you can pick the Frame dongle or all
  of them, and runs `iw dev <iface> set power_save off`. This lasts until reboot.
- Optionally makes it permanent:
  - `/etc/NetworkManager/conf.d/wifi-powersave-off.conf` → `[connection] wifi.powersave=2`
  - `/etc/iwd/main.conf` → `[DriverQuirks] PowerSaveDisable=*`

**By hand:**

```bash
iw dev                                       # find the interface name, e.g. wlan0
sudo iw dev wlan0 set power_save off
```

### 5) iwd: roaming threshold & scanning

**Why:** iwd regularly looks for "better" access points. Every scan interrupts the stream
for a moment.

**What the script does:** sets these keys in `/etc/iwd/main.conf`. Other existing
settings in the file are kept.

```ini
[General]
RoamThreshold=-100
RoamThreshold5G=-100

[Scan]
DisablePeriodicScan=true
```

**By hand:** `sudo nano /etc/iwd/main.conf`, add the lines above, then
`sudo systemctl restart iwd`.

### 6) Fedora: RPM Fusion / multimedia / Mesa freeworld

**Fedora only.** Other distributions already ship these codecs and drivers, or get them
another way.

**Why:** Stock Fedora ships Mesa without H.264/H.265 hardware encoding, which streaming needs.

**What the script does:**

```bash
# RPM Fusion
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Multimedia & full ffmpeg
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf group install -y multimedia
sudo dnf update -y @multimedia --setopt="install_weakdeps=False" --exclude=PackageKit-gstreamer-plugin

# Mesa freeworld – see the note below for which form applies
sudo dnf swap -y mesa-vulkan-drivers mesa-vulkan-drivers-freeworld
```

**The Mesa part adapts to the Fedora release**, because the package layout changed:

| | F42 / F43 | F44 / F45 |
|---|---|---|
| `mesa-va-drivers` | real package → `dnf swap` | only a virtual provide of `mesa-dri-drivers` → `dnf install …-freeworld` alongside |
| `mesa-vdpau-drivers` | real package → `dnf swap` | gone from Fedora entirely → skipped with a note |
| `mesa-vulkan-drivers` | real package → `dnf swap` | real package → `dnf swap` |

The script decides this per package from what is actually installed and available, so it
needs no release check. The `.i686` variants are only touched when the 32-bit stock driver
is already installed; they are never pulled in.

On Atomic Fedora (Silverblue, Kinoite, Bazzite, …) this step stops with a hint instead.
Bazzite already includes all of this.

### 7) Audio: PipeWire-Pulse

**Why:** Audio problems with the Frame are usually fixed by running PipeWire's PulseAudio
replacement.

**What the script does:** checks whether PipeWire already serves PulseAudio clients. If
not, it installs the right package, disables PulseAudio and enables PipeWire for your user.

| Distribution | Package |
|---|---|
| Arch / CachyOS | `pipewire-pulse` (pacman may ask to replace `pulseaudio` – answer `y`) |
| Fedora | `pipewire-pulseaudio` |
| Debian / Ubuntu / Mint | `pipewire-pulse` |

**By hand:**

```bash
sudo pacman -S pipewire-pulse          # Arch / CachyOS
sudo dnf install pipewire-pulseaudio   # Fedora
sudo apt install pipewire-pulse        # Debian / Ubuntu / Mint
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
```

### 8) Start Steam with a PipeWire launch option

**Why:** Desktop/screen sharing in VR (e.g. in VRChat in PCVR mode) needs Steam to be
started with a PipeWire capture option.

**You choose which one:**

| Option | When to use it |
|---|---|
| `-pipewire-dmabuf` | With DMA-BUF, zero-copy, usually the faster one. Start here. |
| `-pipewire` | Without DMA-BUF. Try this if the shared screen stays black or glitches. |

**What the script does:** creates or updates a user copy of Steam's desktop entry in
`~/.local/share/applications/`, and in `~/.config/autostart/` if Steam autostarts, so the
menu launcher passes the option. Native and Flatpak Steam are both supported. Only the
`Exec=` line of the `[Desktop Entry]` section is touched, not the right-click actions.
Both options are removed before the chosen one is inserted, so you can switch between them
at any time, and an entry missing the leading dash (`pipewire-dmabuf`) is repaired.

> **The change only takes effect after a restart.** Quit Steam completely (Steam → Exit,
> and check the tray icon is gone), then start it again from your menu.

**By hand:** quit Steam completely, then start it from a terminal:

```bash
steam -pipewire-dmabuf      # or: steam -pipewire
```

### 9) Firewall rules

**Why:** Steam Remote Play / Steam Link and SteamVR need these ports to be reachable on
your local network.

**What the script does:** detects ufw and/or firewalld and adds the rules. If ufw is
installed but inactive, it asks first.

**ufw (by hand):**

```bash
sudo ufw allow 27031:27036/udp comment 'Steam Remote Play'
sudo ufw allow 27036:27037/tcp comment 'Steam Remote Play'
sudo ufw allow 10401:10403/udp comment 'Steam VR'
sudo ufw reload
sudo ufw status verbose
```

**firewalld (by hand):**

```bash
sudo firewall-cmd --permanent --add-service=steam-streaming
sudo firewall-cmd --permanent --add-port=10401-10403/udp
sudo firewall-cmd --reload
```

### 10) Frame connection into zone `trusted`

**firewalld only.** With ufw this step is not needed.

**Why:** The Frame connects through a NetworkManager profile named `frame_…`. Putting that
profile into firewalld's `trusted` zone keeps the firewall from blocking the headset.

**What the script does:** finds `frame_…` profiles. If there are none, you can pick from
all profiles. Then it sets the zone and, if you confirm, reactivates the connection.

**By hand:**

```bash
nmcli connection show                                            # find the frame_... profile
sudo nmcli connection modify "<frame-profile>" connection.zone trusted
sudo nmcli connection up "<frame-profile>"
```

> The `frame_…` profile only exists after the Frame has been connected through the dongle
> at least once.

### 11) Valve dongle troubleshoot script

Downloads Valve's official
[`frame-dongle-troubleshoot.sh`](https://github.com/ValveSoftware/SteamVR-for-Linux/blob/f4d917f7d8e17ab72a81ab20c9d7d6b2173fab80/frame-dongle-troubleshoot.sh)
with `wget` from the **raw** GitHub URL into a temporary folder. It offers to show you the
script first, and runs it only after you confirm.

**The version is pinned.** The URL points at one commit (v0.5) and the download is checked
against the SHA256 in `steps/11-valve-script.sh`. Everyone therefore runs exactly the
reviewed version, and the step aborts if the checksum does not match. The flip side: Valve
revises this script, and newer versions do not reach users until the commit in
`steam-frame-setup.sh` and that hash are bumped together, after reviewing the new version:

```bash
wget --https-only -O new.sh https://raw.githubusercontent.com/ValveSoftware/SteamVR-for-Linux/master/frame-dongle-troubleshoot.sh
less new.sh            # review it
sha256sum new.sh       # put this hash into steps/11-valve-script.sh
```

The script is read-only diagnostics: it checks kernel and `rtw89` driver, rfkill, regulatory
domain, firewall and VPN interfaces, and prints `PROBLEM:` / `INFO:` lines. **It does not
need root**, so this step runs it as your normal user. The only check that needs root is
`ufw status`; the script notes that it skipped it, and you can re-run it with
`sudo bash <file>` to include it.

**By hand:**

```bash
wget --https-only https://raw.githubusercontent.com/ValveSoftware/SteamVR-for-Linux/master/frame-dongle-troubleshoot.sh
less frame-dongle-troubleshoot.sh      # read it first
bash frame-dongle-troubleshoot.sh      # sudo only needed for the ufw check
```

> Use the `raw.githubusercontent.com` URL. The normal GitHub link (`…/blob/…`) downloads
> an HTML page, not the script.

---

## Backups and undoing changes

- Before a system file is changed for the first time in a session, it is copied to
  `<file>.bak-YYYYMMDD-HHMMSS` next to the original. An existing backup is never
  overwritten; if a name is already taken, a counter is appended (`…-192516-1`), so the
  oldest state always survives.
- To restore a file, copy the backup back, for example:

  ```bash
  sudo cp /etc/iwd/main.conf.bak-20261009-101500 /etc/iwd/main.conf
  ```

- **R) Undo Wi-Fi fixes** undoes steps 2–5 using exactly those backups. It asks per item
  and, for each file, restores the **oldest** backup — the state before this script first
  changed it. A file that the script created, and that therefore has no backup, is removed
  instead. The backups themselves are kept.

  | Item | File |
  |---|---|
  | iwd backend | `/etc/NetworkManager/conf.d/wifi_backend.conf`, optionally disables `iwd.service` |
  | Power saving | `/etc/NetworkManager/conf.d/wifi-powersave-off.conf` |
  | iwd configuration | `/etc/iwd/main.conf` — holds both the power-save quirk (step 4) and roaming/scanning (step 5), so it is one item |
  | Regulatory domain | `/etc/modprobe.d/cfg80211-regdom.conf`, `/etc/conf.d/wireless-regdom`, `/etc/default/crda`, whichever exists |

  It offers to restart NetworkManager and iwd afterwards. Regulatory domain and power
  saving are only re-read after a reboot.

- **S) Undo the Steam launch option** does the same for step 8: it restores the backup of
  `~/.local/share/applications/steam.desktop` (and the `~/.config/autostart/` copy, if
  there is one), or removes a copy the script created, so Steam's own launcher applies
  again. The system-wide entry is never touched.

- **M) Undo the Fedora multimedia changes** has no backups to work from, because step 6
  changes packages rather than files. It runs the swaps the other way round instead, asking
  per item and only for packages that are actually installed:

  | Item | Command |
  |---|---|
  | Mesa drivers | `dnf swap mesa-*-freeworld mesa-*` for each of va/vdpau/vulkan, plus the `.i686` variants |
  | ffmpeg | `dnf swap ffmpeg ffmpeg-free --allowerasing` |
  | RPM Fusion | `dnf remove rpmfusion-free-release rpmfusion-nonfree-release`, after a second confirmation |

  The `multimedia` group is deliberately left alone: removing it would also take out codecs
  the desktop needs. Packages already installed from RPM Fusion stay installed and simply
  stop receiving updates, which the step says before removing the repositories.

  Mesa is undone the same way round as it was applied: swapped back where the stock package
  really exists, and simply removed where it does not, because from Fedora 44 on the stock
  VA support is part of `mesa-dri-drivers` and returns on its own.

  **Tested in containers on Fedora 42, 43, 44 and 45** with real `dnf` transactions: apply
  step 6, run the revert, and the Mesa and ffmpeg packages are back to their starting
  versions on every release. The full step 6 including the `multimedia` group was run end
  to end on Fedora 44. It has not been tested on a running desktop, though, so on Fedora
  please still try it in a virtual machine first — a Mesa swap that goes wrong can leave
  you without a graphical session.

---

## Project layout

```
steam-frame-setup.sh      entry point: options, menu, language selection
lib/
  ui.sh                   output, prompts, dry-run command runner
  files.sh                backups, diff preview, file and INI editing
  system.sh               distro / package / network / bootloader detection
  i18n.sh                 loads lang/*.lang, language detection
steps/
  01-diagnose.sh … 11-valve-script.sh                 one file per menu entry
  90-wifi-revert.sh                                   undo steps 2–5 from the backups
lang/
  en.lang de.lang es.lang fr.lang pt.lang zh.lang ja.lang
```

New menu entries are added to the `MENU=( … )` table in `steam-frame-setup.sh` together
with a script in `steps/`.

## Adding a language

1. Copy `lang/en.lang` to `lang/<code>.lang`, e.g. `lang/pl.lang`.
2. Translate the values to the right of the `=`. Keep every `%s` placeholder, and keep
   `\n` where it appears.
3. Set `lang_name`, `yes_words`, `no_words`, `hint_yes` and `hint_no` for the new language.

That's it. The language appears automatically in the selection menu and in `--help`.
Missing keys fall back to English.

---

## Troubleshooting

- **"Please run as a normal user"**: start the script without `sudo`.
- **"lib/, steps/ or lang/en.lang missing"**: the folders must stay next to
  `steam-frame-setup.sh`.
- **Wi-Fi gone after switching to iwd**: reconnect once via your network applet, or use
  **R** to go back to wpa_supplicant.
- **Firewall status shows "unknown" in dry-run**: in dry-run the script does not prompt
  for a password, so ufw status is only shown if sudo credentials are already cached.
- **Something else?** Ask in the Linux VR Adventures community (see below) and include the
  output of menu item **1**.

---

## Credits and links

| Who / what | Contribution | Link |
|---|---|---|
| **Linux VR Adventures (LVRA)** | Regulatory domain, iwd backend, audio fixes | Wiki: <https://vronlinux.org/> · Discord: <https://discord.gg/EHAYe3tTYa> · Matrix: <https://matrix.to/#/#linux-vr-adventures:matrix.org> |
| **DasChaos** | Fedora RPM Fusion / multimedia / Mesa freeworld setup | <!-- TODO: add DasChaos link --> <https://github.com/ThomasMarangoni>|
| **Nhitho** | Testing on CachyOS: iwd roaming/scan tuning, `-pipewire-dmabuf` for VRChat in PCVR mode | |
| **Valve / Steam** | Firewall ports, dongle troubleshoot script | [Required Ports for Steam](https://help.steampowered.com/en/faqs/view/2EA8-4D75-DA21-31EB) · [SteamVR-for-Linux on GitHub](https://github.com/ValveSoftware/SteamVR-for-Linux) |

Further reading:

- [RPM Fusion](https://rpmfusion.org/)
- [ArchWiki – NetworkManager: using iwd as the Wi-Fi backend](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend)
- [ArchWiki – iwd](https://wiki.archlinux.org/title/Iwd)

---

## License

This project is released under the [MIT License](LICENSE). You are free to use, copy,
modify, merge, publish, distribute, sublicense and sell it, as long as the copyright and
license notice are kept. Contributions such as new steps, translations and fixes are welcome.
