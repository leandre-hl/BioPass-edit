# BioPass edit

A small Bash utility that **locks down the files [BioPass](https://github.com/TickLabVN/biopass) uses to recognize you**, and lets you unlock them only when you actually want to change something.

> Unofficial helper. It is not affiliated with or endorsed by the BioPass project.

## Why

BioPass stores its settings, models and enrolled faces inside your home directory, so any program running as your user (or anyone sitting at your unlocked session) can edit them without a password. In particular, someone could open the BioPass GUI, enroll **their own face**, and then use it to get `sudo`.

`biopass-edit` closes that gap. In its protected state:

| Path | Protection |
| --- | --- |
| `~/.config/com.ticklab.biopass/config.yaml` | owned by you, **immutable** (`chattr +i`) |
| `~/.config/com.ticklab.biopass/biopass.db` | owned by you, **immutable** (`chattr +i`) |
| `~/.local/share/com.ticklab.biopass/faces/` | `root:root`, read-only for everyone (`755`) |
| `~/.local/share/com.ticklab.biopass/models/` | `root:root`, read-only for everyone (`755`) |

Face authentication keeps working in this state (the PAM module only needs to read these files). To change a setting or enroll a face, you run `biopass-edit`, which asks for `sudo`, so an intruder without your password cannot do it.

## What it does

1. Refuses to run as root (with `sudo`, `$HOME` would be `/root` and BioPass would run on the wrong files).
2. Checks that all the expected paths exist before touching anything.
3. Asks for `sudo`, then lifts the protection: removes the immutable attribute and gives `faces/` and `models/` back to your user.
4. Launches BioPass **as your normal user**.
5. When BioPass closes (or on Ctrl+C, or if it crashes), restores the protected state and prints the resulting attributes and owners so you can check that the `i` flags are back.

It does not modify any PAM file.

## Requirements

- Linux with `bash`, `sudo`, `chattr` / `lsattr` (package `e2fsprogs`) and `coreutils`.
- BioPass installed, using the layout above (`config.yaml` and `biopass.db` in `~/.config/com.ticklab.biopass`, data in `~/.local/share/com.ticklab.biopass`).
- A filesystem that supports the immutable attribute. Tested on Linux Mint (Cinnamon) with an eCryptfs-encrypted home, where it works.

## Install as a command

The best place for the script is `/usr/local/bin`: it is already in your `PATH`, so you can run the command from any directory, and it belongs to root, so nobody can alter it without `sudo`. This matters because the script runs `sudo` on your behalf. Keeping it in your home directory would let any program running as your user modify it.

```bash
git clone https://github.com/<your-username>/biopass-edit.git
cd biopass-edit

sudo install -m 755 -o root -g root biopass-edit.sh /usr/local/bin/biopass-edit
hash -r
```

Check the installation:

```bash
command -v biopass-edit            # should print /usr/local/bin/biopass-edit
ls -l /usr/local/bin/biopass-edit  # should show -rwxr-xr-x root root
```

If the command is not found, open a new terminal or run `hash -r`.

## Usage

Run it as your normal user, **without sudo**, from any directory:

```bash
biopass-edit
```

Make your changes in BioPass (thresholds, enrolling a face, models...), then close the window. The protection is restored automatically.

Expected output at the end:

```
Restoring protection...
Attributes (an 'i' = protected):
----i---------e------- /home/you/.config/com.ticklab.biopass/config.yaml
----i---------e------- /home/you/.config/com.ticklab.biopass/biopass.db
--------------e------- /home/you/.local/share/com.ticklab.biopass/faces
--------------e------- /home/you/.local/share/com.ticklab.biopass/models
```

`faces` and `models` have no `i` by design: they are protected by their `root:root` ownership. See the options below to make them immutable too.

## Configuration

Settings are variables at the top of the script.

| Variable | Default | Meaning |
| --- | --- | --- |
| `BIOPASS_CMD` | `biopass` | Command used to launch BioPass. Override per run: `BIOPASS_CMD=/path/to/biopass biopass-edit` |
| `LOCK_DIRS_IMMUTABLE` | `0` | Set to `1` to also make `faces/` and `models/` immutable |
| `CONF_DIR`, `DATA_DIR` | BioPass default paths | Change them if your BioPass uses other locations |

### Why `faces/` and `models/` are not immutable by default

With `root:root` ownership alone, nobody can add or modify files inside these directories, but their parent directory belongs to you, so a user with a terminal could still rename `faces/` and create a new one in its place. The immutable attribute closes that hole. It is off by default because it needs to be tested on your system first:

```bash
sudo chattr +i ~/.local/share/com.ticklab.biopass/faces ~/.local/share/com.ticklab.biopass/models
sudo -k && sudo true      # then lock the screen and unlock it with your face
```

If recognition still works, set `LOCK_DIRS_IMMUTABLE=1` in the script (`sudo nano /usr/local/bin/biopass-edit`). If it breaks, undo it with `sudo chattr -i` on the same two directories. The script removes this attribute at startup in any case.

## Output filtering

The script hides two harmless messages BioPass prints on many machines: the GTK accessibility bridge warning (`dbind-WARNING`) and the `No fingerprint device found` error on PCs without a fingerprint reader. Everything else from BioPass is still displayed.

## Limitations

- This protects against someone using your unlocked session **without knowing your password**. It does not protect against an attacker who already has root or your `sudo` password.
- It only guards the files BioPass reads. It does not make face recognition itself more secure: without an infrared camera, a face can potentially be spoofed. Treat face unlock as a convenience.
- It does not manage PAM. Whether BioPass is used for `sudo`, the lock screen, or the login screen is configured separately in `/etc/pam.d/`. If your home directory is encrypted with eCryptfs, do not enable BioPass for the login screen: eCryptfs needs your password to mount your home.
- Package updates or `pam-auth-update` can rewrite PAM files, but never the files protected by this script.

## Troubleshooting

- **`Not found: <path>`**: a protected path does not exist. Nothing was changed. Check `CONF_DIR` and `DATA_DIR` at the top of the script.
- **`Command 'biopass' not found`**: find the real command with `command -v biopass` or the `Exec=` line of the `.desktop` file, then run `BIOPASS_CMD=/path/to/biopass biopass-edit`.
- **No `i` in the `lsattr` output after restoring**: your filesystem does not support the immutable attribute, so this method cannot protect the files there.
- **`Operation not permitted` on `chown` or `chmod` as root**: the file has the immutable attribute. Run `sudo chattr -i <file>` first (the script does this for you).
- **BioPass fails to start when files are protected**: that is expected for the GUI, which writes to `biopass.db`. Use `biopass-edit` to open it.

## Uninstall

```bash
# 1. Remove the protection from the BioPass files
sudo chattr -i ~/.config/com.ticklab.biopass/config.yaml ~/.config/com.ticklab.biopass/biopass.db
sudo chattr -R -i ~/.local/share/com.ticklab.biopass/faces ~/.local/share/com.ticklab.biopass/models
sudo chown -R "$USER:$USER" ~/.local/share/com.ticklab.biopass/faces ~/.local/share/com.ticklab.biopass/models

# 2. Remove the command
sudo rm /usr/local/bin/biopass-edit
```

The first block gives BioPass its files back exactly as they were before the script protected them.
