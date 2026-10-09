# Steam Frame – Linux Setup Helper

An interactive, multilingual shell script that applies the known Linux tweaks for the
**Valve Steam Frame** and its Wi-Fi dongle: regulatory domain, iwd backend, Wi-Fi power
saving, roaming/scan behaviour, firewall rules, audio, the Steam `-pipewire-dmabuf`
launch option and USB autosuspend.

Every step shows what it is going to change (as a diff), asks before doing it, and backs
up every file it modifies. A `--dry-run` mode shows everything without touching the system.

> **Disclaimer:** This is a community project and is not affiliated with or endorsed by Valve.
> Use it at your own risk and read what each step does before confirming it.

---

## Contents

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
such as `iw` or `iwd` are offered for installation when a step needs them.

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

5. **Start with `1) System info / diagnostics`** to see the current state. Then either run
   the steps one by one, or choose **`A`** to go through all recommended steps in order.
   You will be asked before every step.

6. **Reboot** when you are done. Several settings, such as the regulatory domain, kernel
   parameters and the iwd configuration, only take full effect after a reboot.

### Main menu

```
   1) System info / diagnostics
   2) Set Wi-Fi regulatory domain
   3) NetworkManager → iwd backend
   4) Disable Wi-Fi power saving
   5) iwd: roaming threshold & scanning
   6) Fedora: RPM Fusion / multimedia / Mesa freeworld
   7) Audio: PipeWire-Pulse
   8) Start Steam with -pipewire-dmabuf
   9) Firewall rules (ufw / firewalld)
  10) Frame connection into zone 'trusted'
  11) Valve dongle troubleshoot script
  12) USB autosuspend off (GRUB kernel parameter)

   A) Run all recommended steps
   R) Revert iwd backend
   L) Language
   0) Quit
```

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

**What the script does:**
- Shows the current value (`iw reg get`) and suggests your country from the locale, e.g. `DE`.
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

# Mesa freeworld (the .i686 variants are only swapped if they are installed)
sudo dnf swap -y mesa-va-drivers     mesa-va-drivers-freeworld
sudo dnf swap -y mesa-vdpau-drivers  mesa-vdpau-drivers-freeworld
sudo dnf swap -y mesa-vulkan-drivers mesa-vulkan-drivers-freeworld
```

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

### 8) Start Steam with `-pipewire-dmabuf`

**Why:** Desktop/screen sharing in VR (e.g. in VRChat in PCVR mode) needs Steam to be
started with `-pipewire-dmabuf`.

**What the script does:** creates or updates a user copy of Steam's desktop entry in
`~/.local/share/applications/`, and in `~/.config/autostart/` if Steam autostarts, so the
menu launcher passes the option. Native and Flatpak Steam are both supported. A wrong
entry without the leading dash (`pipewire-dmabuf`) is corrected.

**By hand:** quit Steam completely, then start it from a terminal:

```bash
steam -pipewire-dmabuf
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
[`frame-dongle-troubleshoot.sh`](https://github.com/ValveSoftware/SteamVR-for-Linux/blob/master/frame-dongle-troubleshoot.sh)
from the **raw** GitHub URL into a temporary folder. It shows the line count and SHA256,
offers to show the script, and runs it with `sudo` only after you confirm.

**By hand:**

```bash
wget --https-only https://raw.githubusercontent.com/ValveSoftware/SteamVR-for-Linux/master/frame-dongle-troubleshoot.sh
less frame-dongle-troubleshoot.sh      # read it first
chmod +x frame-dongle-troubleshoot.sh
sudo ./frame-dongle-troubleshoot.sh
```

> Use the `raw.githubusercontent.com` URL. The normal GitHub link (`…/blob/…`) downloads
> an HTML page, not the script.

### 12) USB autosuspend off

**Why:** If the kernel suspends the USB dongle to save power, the connection can drop.
The kernel parameter `usbcore.autosuspend=-1` turns this off.

**What the script does:**
- **GRUB:** adds the parameter to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub` and
  regenerates the config:
  - Debian / Ubuntu / Mint: `update-grub`
  - Arch / CachyOS: `grub-mkconfig -o /boot/grub/grub.cfg`
  - Fedora: `grubby --update-kernel=ALL --args=usbcore.autosuspend=-1`
  - If the parameter is already there, the script offers to remove it again.
- **Other bootloaders** (Limine – the CachyOS default, systemd-boot, sdboot-manage): shows
  exactly where to add it by hand.
- Optionally disables autosuspend right away until the next reboot. This only applies to
  newly plugged-in devices, so replug the dongle once.

**By hand (GRUB):**

```bash
sudo nano /etc/default/grub
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash usbcore.autosuspend=-1"
sudo update-grub                                  # Debian / Ubuntu / Mint
sudo grub-mkconfig -o /boot/grub/grub.cfg         # Arch / CachyOS
```

**By hand (Limine on CachyOS):** add `usbcore.autosuspend=-1` to the
`KERNEL_CMDLINE[default]` line in `/etc/default/limine`, then run `sudo limine-update`.

### A) Run all recommended steps

Goes through steps 2–5, 6 (Fedora only), 7–10 and 12 in order and asks before each one.
If a step fails, the script continues with the next one.

---

## Backups and undoing changes

- Before a system file is changed for the first time in a session, it is copied to
  `<file>.bak-YYYYMMDD-HHMMSS` next to the original.
- To restore a file, copy the backup back, for example:

  ```bash
  sudo cp /etc/iwd/main.conf.bak-20261009-101500 /etc/iwd/main.conf
  ```

- **R) Revert iwd backend** removes `wifi_backend.conf` after making a backup, can disable
  `iwd.service`, and restarts NetworkManager.
- Step 12 offers to remove `usbcore.autosuspend=-1` from GRUB again when it is already set.

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
  01-diagnose.sh … 12-usb-autosuspend.sh, 99-all.sh   one file per menu entry
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
- [Linux kernel docs – USB power management](https://www.kernel.org/doc/html/latest/driver-api/usb/power-management.html)

---

## License

This project is released under the [MIT License](LICENSE). You are free to use, copy,
modify, merge, publish, distribute, sublicense and sell it, as long as the copyright and
license notice are kept. Contributions such as new steps, translations and fixes are welcome.
