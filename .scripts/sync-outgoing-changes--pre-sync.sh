#!/usr/bin/env bash

# Must be executed after a local KDBX file is saved, but before the changes in the local file are
# synced to the cloud copy. Expects the name of the KDBX file (including extension) as argument.
#
# - Creates a duplicate of the local KDBX file in the support directory 'last-known-good', as a
#   pre-operation backup, in case the sync corrupts the local file.
# - Copies the local KDBX file to the cloud sync directory (e.g. the Dropbox directory) if it
#   doesn't exist there yet.
#   That matters when a new KDBX file has been created locally. The sync to the cloud is initiated
#   automatically then, and the most current version of the file is available to other machines.
#   However, remote machines do NOT scan the cloud directory for new files, so they don't pick up
#   the new file automatically. It needs to be copied from the cloud directory to the local Keepass
#   directory by hand.
# - Respects the EXCLUDE_FROM_SYNC config setting and skips KDBX files listed there.

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
(( $# == 0 )) && fatal_error "Missing argument. KDBX database filename not provided. Script aborted."
pwd_filename="$1"

# Verify local database path
local_master_file="$(get-keepass-db-dir)/$pwd_filename" || fatal_error "Failed to retrieve the path to the Keepass database directory."
[ ! -f "$local_master_file" ] && fatal_error "Cannot find the local KDBX database provided by the filename argument.\n    Filename argument: $pwd_filename\n    Expected location: $local_master_file\n    (in Windows notation: $(wsl-windows-path -e "$local_master_file"))"

# Check if the local KDBX file is excluded from cloud sync. Exit quietly if excluded, or log an
# error if one occurred (exit code of is-included-db > 1).
is-included-db "$pwd_filename" || { (($?==1)) && exit 0 || fatal_error "Failed to establish if the database is excluded from synchronization."; }

# Create backup of local database, in the last-known-good directory
last_known_good="$(get-support-dir last-known-good)/$pwd_filename" || fatal_error "Failed to retrieve the path to the 'last-known-good' directory."
safe-filecopy "$local_master_file" "$last_known_good" || fatal_error "Failed to copy the local KDBX database to a short-term backup location (\"last known good\").\n    Copy source: $(wsl-windows-path -e "$local_master_file")\n    Copy target: $(wsl-windows-path -e "$last_known_good")"

# Verify cloud database path. Create a copy of the local file there if it doesn't exist yet.
cloud_sync_file_win="$(get-cloud-sync-dir)\\$pwd_filename" || fatal_error "Can't establish the path to the password file in the cloud sync directory."
if ! safe-file-exists "$cloud_sync_file_win"; then
    safe-filecopy "$local_master_file" "$cloud_sync_file_win" || fatal_error "Failed to copy the local KDBX database to the cloud sync directory.\n    NB The local database, '$pwd_filename', has not yet been present in the cloud sync directory.\n    Copy source: $(wsl-windows-path -e "$local_master_file")\n    Copy target: ${cloud_sync_file_win//\\/\\\\}"
fi
