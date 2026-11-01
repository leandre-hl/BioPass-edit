# BioPass Edit

A Bash utility that locks the files [BioPass](https://github.com/TickLabVN/biopass) uses to recognize you, and unlocks them only when you run it (it asks for `sudo`).

> Unofficial helper, not affiliated with the BioPass project.

## Why

BioPass keeps its settings, models and enrolled faces in your home directory, so anyone at your unlocked session can edit them without a password, for example by enrolling **their own face** and then using it to get `sudo`. `biopass-edit` prevents this: changing anything requires your `sudo` password.

## Protected state

| Path | Protection |
| --- | --- |
| `~/.config/com.ticklab.biopass/config.yaml` | immutable (`chattr +i`) |
| `~/.config/com.ticklab.biopass/biopass.db` | immutable (`chattr +i`) |
| `~/.local/share/com.ticklab.biopass/faces/` | `root:root`, read-only, immutable |
| `~/.local/share/com.ticklab.biopass/models/` | `root:root`, read-only, immutable |

Face authentication keeps working in this state: the PAM module only reads these files.

## How it works

1. Refuses to run as root, and checks that all paths exist.
2. Asks for `sudo` and lifts the protection.
3. Launches BioPass **as your normal user**.
4. When BioPass closes (or on Ctrl+C or a crash), restores the protection and prints the attributes so you can check for the `i` flags.

It does not modify any PAM file.

## Requirements

- Linux with `bash`, `sudo`, `chattr`/`lsattr`, and BioPass using the paths above.
- A filesystem supporting the immutable attribute. Tested on Linux Mint (Cinnamon) with an eCryptfs home.

## Install as a command

`/usr/local/bin` is in your `PATH` (so the command works from any directory) and belongs to root (so nobody can alter the script without `sudo`, which matters because it runs `sudo` for you).

```bash
git clone https://github.com/<your-username>/biopass-edit.git
cd biopass-edit
sudo install -m 755 -o root -g root biopass-edit.sh /usr/local/bin/biopass-edit
hash -r
```

Check: `command -v biopass-edit` should print `/usr/local/bin/biopass-edit`.

## Usage

Run it as your normal user, **without sudo**:

```bash
biopass-edit
```

Change your settings or enroll a face in BioPass, then close it. The protection comes back by itself.

## Options

Variables at the top of the script (edit with `sudo nano /usr/local/bin/biopass-edit`):

| Variable | Default | Meaning |
| --- | --- | --- |
| `LOCK_DIRS_IMMUTABLE` | `1` | Also make `faces/` and `models/` immutable, so they cannot be renamed or replaced. Set to `0` if face recognition stops working. |
| `BIOPASS_CMD` | `biopass` | Command that launches BioPass. Per run: `BIOPASS_CMD=/path/to/biopass biopass-edit` |
| `CONF_DIR`, `DATA_DIR` | BioPass default paths | Change if BioPass uses other locations. |

The script hides two harmless BioPass messages (the GTK `dbind-WARNING` and `No fingerprint device found`). Everything else is still shown.

## Limitations

- It stops someone using your unlocked session **without your password**. It does not stop an attacker with root or your `sudo` password.
- It does not make face recognition itself stronger: without an infrared camera a face can be spoofed. Treat it as a convenience.
- PAM is configured separately in `/etc/pam.d/`. With an eCryptfs home, do not enable BioPass for the login screen, as eCryptfs needs your password.

## Troubleshooting

- **`Not found: <path>`**: nothing was changed; check `CONF_DIR` and `DATA_DIR`.
- **`Command 'biopass' not found`**: find it with `command -v biopass`, then set `BIOPASS_CMD`.
- **No `i` in the output**: your filesystem does not support the immutable attribute.
- **BioPass won't open outside the script**: expected, the GUI writes to `biopass.db`. Use `biopass-edit`.
- **Face recognition broke**: set `LOCK_DIRS_IMMUTABLE=0`, or run `sudo chattr -R -i ~/.local/share/com.ticklab.biopass/{faces,models}`.

## Uninstall

```bash
sudo chattr -i ~/.config/com.ticklab.biopass/config.yaml ~/.config/com.ticklab.biopass/biopass.db
sudo chattr -R -i ~/.local/share/com.ticklab.biopass/faces ~/.local/share/com.ticklab.biopass/models
sudo chown -R "$USER:$USER" ~/.local/share/com.ticklab.biopass/faces ~/.local/share/com.ticklab.biopass/models
sudo rm /usr/local/bin/biopass-edit
```
