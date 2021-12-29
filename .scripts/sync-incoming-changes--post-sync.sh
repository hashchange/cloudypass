#!/usr/bin/env bash

# Must be executed after a local KDBX file is opened and changes in the cloud copy are synced to the
# local file. Expects the name of the KDBX file (including extension) as argument.
#
# - Moves the last-synced file from its temporary location to the last-synced directory (and renames
#   the file).
#   This file is the new reference for checking if the database in the cloud directory has changed
#   (indicating modifications on another machine).
# - Deletes the temporary database copy which was used for the import.

set -eu

# Script name
PROGNAME=$(basename "$0")

# Absolute path to the script.
progdir=$([[ $0 == /* ]] && dirname "$0" || { _dir="$( realpath -e "$0")"; [[ "$_dir" == /* ]] && dirname "$_dir" || pwd; })

export PATH="$progdir/lib:$PATH"

# Set up error reporting
exec 2> >(log-errors)

# Functions
fatal_error() { echo -e "$PROGNAME: $1" >&2; exit 1; }

# Argument
(( $# == 0 )) && fatal_error "Missing argument. KDBX database filename not provided."
pwd_filename="$1"

# Check if the local KDBX file is excluded from cloud sync. Exit quietly if excluded.
is-included-db "$pwd_filename" || exit 0

# File paths
temp_import_dir="$(get-support-dir temp-import)"
temp_import_file="$temp_import_dir/$pwd_filename"
temp_last_synced_file="$temp_import_dir/$pwd_filename--in-progress"
last_synced_file="$(get-support-dir last-synced)/$pwd_filename"

# Move the last-synced file to its final destination (and rename it).
# NB mv is safe to use. It preserves the timestamp even on mounted Windows drives.
[ -f "$temp_last_synced_file" ] || fatal_error "The temporary local copy of the cloud file (the future \"last-synced\" file) is missing or can't be accessed.\n    File path: $(wsl-windows-path -e "$temp_last_synced_file")"
mv -f "$temp_last_synced_file" "$last_synced_file" || fatal_error "Failed to move the local copy of the cloud file (the \"last-synced\" file) to its final location.\n    Source: $(wsl-windows-path -e "$temp_last_synced_file")\n    Destination: $(wsl-windows-path -e "$last_synced_file")"

# Delete the temporary import file.
rm "$temp_import_file"
