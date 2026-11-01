#!/bin/bash
# biopass-edit.sh
# Lifts the protection on the BioPass files, launches the app as YOUR user,
# then puts the protection back on exit (even after Ctrl+C or a crash).
#
# Usage: ./biopass-edit.sh        (do NOT run it with sudo)

set -u

# With sudo, $HOME becomes /root and BioPass would run as root on the wrong files.
# The script calls sudo itself only for the commands that need it.
if [ "$(id -u)" -eq 0 ]; then
  echo "Run this command as your normal user, without sudo: biopass-edit"
  exit 1
fi

USER_NAME="$(id -un)"
CONF_DIR="$HOME/.config/com.ticklab.biopass"
DATA_DIR="$HOME/.local/share/com.ticklab.biopass"
BIOPASS_CMD="${BIOPASS_CMD:-biopass}"   # change if the command has another name

FILES_IMMUTABLE=(
  "$CONF_DIR/config.yaml"
  "$CONF_DIR/biopass.db"
)
DIRS_ROOT=(
  "$DATA_DIR/faces"
  "$DATA_DIR/models"
)

# Set to 1 ONLY after testing (sudo -k && sudo true, then Super+L):
# also makes faces/ and models/ immutable (prevents renaming them or adding
# files to them).
LOCK_DIRS_IMMUTABLE=1

for p in "${FILES_IMMUTABLE[@]}" "${DIRS_ROOT[@]}"; do
  if [ ! -e "$p" ]; then
    echo "Not found: $p"
    echo "Nothing was changed. Check the paths at the top of the script."
    exit 1
  fi
done

if ! command -v "$BIOPASS_CMD" >/dev/null 2>&1; then
  echo "Command '$BIOPASS_CMD' not found."
  echo "Look for it with: command -v biopass  (or the Exec= line of Bureau/biopass.desktop)"
  echo "then run again with: BIOPASS_CMD=/path/to/biopass $0"
  exit 1
fi

relock() {
  echo
  echo "Restoring protection..."
  sudo chown -R root:root "${DIRS_ROOT[@]}"
  sudo chmod -R a+rX,go-w "${DIRS_ROOT[@]}"
  if [ "$LOCK_DIRS_IMMUTABLE" = "1" ]; then
    sudo chattr +i "${DIRS_ROOT[@]}"
  fi
  sudo chattr +i "${FILES_IMMUTABLE[@]}"
