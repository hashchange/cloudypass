#!/usr/bin/env bash

# Checks if the file in the cloud sync directory (e.g. the Dropbox directory) contains changes which
# have not been imported yet. Expects the name of the KDBX file (including extension) as argument.
# Must be executed as soon as a local KDBX file is opened, but before potential changes in the cloud
# copy are synced to the local file.
#
# Sets exit code 0 (truthy, import required) if
#
# - the cloud file has been changed externally, ie on another machine
# - the cloud file exists, but the last-synced copy does not.
#   Ie, the cloud file has not been imported previously, and the local database has not been synced
#   to the cloud copy on save, either.
#
# Sets exit code 1 (falsy = skip import) if
#
# - the cloud file has stayed the same and does not contain external changes
# - the file is excluded from cloud sync (listed in then EXCLUDE_FROM_SYNC config setting)
# - the cloud file does not exist
# - an error has occurred (exit code may be 1 or higher).
#   This behaviour prevents an import from going ahead in the presence of errors, ie in a situation
#   of uncertainty.
#
# For the check, the cloud file is compared against a local duplicate: the "last-synced" copy of the
# cloud file, which has been created at the time of the last import or sync. Absent external
# changes, the cloud file matches the local duplicate.

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
(($# == 0)) && fatal_error "Missing argument. KDBX database filename not provided."
pwd_filename="$1"

# Check if the local KDBX file is excluded from cloud sync. Exit quietly if excluded.
is-included-db "$pwd_filename" || exit 1

# Verify cloud database path. Exit quietly if the cloud database doesn't exist.
cloud_sync_file_win="$(get-cloud-sync-dir)\\$pwd_filename" || fatal_error "Can't find the path to the password file in the cloud sync directory."
safe-file-exists "$cloud_sync_file_win" || exit 1;

# Verify last-synced database path. Exit quietly, with truthy exit status, if the file doesn't exist.
last_synced_file="$(get-support-dir last-synced)/$pwd_filename"
[ -f "$last_synced_file" ] || exit 0;

# Compare the current cloud database file to the "last-synced" reference file
safe-is-binary-same "$cloud_sync_file_win" "$last_synced_file" && exit 1 || { (($?==1)) && exit 0 || fatal_error "Failed to compare the cloud-synced file to the reference file (the \"last-synced\" file).\n    Cloud-synced file: ${cloud_sync_file_win//\\/\\\\}\n    Reference file:    $(wsl-windows-path -e "$last_synced_file")"; }
