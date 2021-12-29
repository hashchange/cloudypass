#!/usr/bin/env bash

# Must be executed as soon as a local KDBX file is opened, but before changes in the cloud copy are
# synced to the local file. Expects the name of the KDBX file (including extension) as argument.
#
# - Creates a duplicate of the local KDBX file in the support directory 'last-known-good', as a
#   pre-operation backup, in case the sync corrupts the local file.
# - Copies the file from the cloud sync directory to a temp folder. This file will be used for the
#   import.
#   + As a local duplicate, the temp file is protected against any sudden changes initiated on
#     another machine while the import is in progress.
#   + The temp file is modified by the import (which is in fact a merge, altering both files even if
#     the content of the import source remains unchanged). The cloud file itself remains unaffected
#     by the import, as it should be.
#   + The temporary file can be discarded later on, in the post-sync script.
# - Creates a duplicate of the temp file (ie, a duplicate of the duplicate) before the import
#   begins.
#   + That file, too, remains unaffected by the import and is, at least for now, identical to the
#     cloud file.
#   + Eventually, when the import has been successful, the file will be moved to the last-synced
#     directory and kept there as the future reference, in order to detect changes made on another
#     machine (see has-cloud-copy-changed.sh). The file will be moved in the post-sync script.

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

# Verify local database path
local_master_file="$(get-keepass-db-dir)/$pwd_filename"
[ ! -f "$local_master_file" ] && fatal_error "Cannot find the local KDBX database provided by the filename argument.\n    Filename argument: $pwd_filename\n    Expected location: $local_master_file\n    (in Windows notation: $(wsl-windows-path -e "$local_master_file"))"

# Check if the local KDBX file is excluded from cloud sync. Exit quietly if excluded.
is-included-db "$pwd_filename" || exit 0

# Create backup of local database, in the last-known-good directory
last_known_good="$(get-support-dir last-known-good)/$pwd_filename"
safe-filecopy "$local_master_file" "$last_known_good" || fatal_error "Failed to copy the local KDBX database to a short-term backup location (\"last known good\").\n    Copy source: $(wsl-windows-path -e "$local_master_file")\n    Copy target: $(wsl-windows-path -e "$last_known_good")"

# File paths
temp_import_dir="$(get-support-dir temp-import)"
temp_import_file="$temp_import_dir/$pwd_filename"
temp_last_synced_file="$temp_import_dir/$pwd_filename--in-progress"

# Remove old files from the temp directory
[ -f "$temp_import_file" ] && rm "$temp_import_file"
[ -f "$temp_last_synced_file" ] && rm "$temp_last_synced_file"

# Verify cloud database path
cloud_sync_file_win="$(get-cloud-sync-dir)\\$pwd_filename" || fatal_error "Can't find the path to the password file in the cloud sync directory."
safe-file-exists "$cloud_sync_file_win" || fatal_error "The cloud-synced copy is missing or can't be accessed.\n    Path: ${cloud_sync_file_win//\\/\\\\}"

# Create local duplicate of cloud database, in the temp-import directory, and create yet another
# copy of that file (the future last-synced file).
safe-filecopy "$cloud_sync_file_win" "$temp_import_file" || fatal_error "Failed to copy the cloud-synced file to a temporary location.\n    Copy source: ${cloud_sync_file_win//\\/\\\\}\n    Copy target: $(wsl-windows-path -e "$temp_import_file")"
safe-filecopy "$temp_import_file" "$temp_last_synced_file" || fatal_error "Failed to duplicate the temporary file.\n    Copy source: $(wsl-windows-path -e "$temp_import_file")\n    Copy target: $(wsl-windows-path -e "$temp_last_synced_file")"
