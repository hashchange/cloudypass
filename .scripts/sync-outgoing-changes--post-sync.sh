#!/usr/bin/env bash

# Must be executed after a local KDBX file is saved and the changes in the local file have already
# been synced to the cloud copy. Expects the name of the KDBX file (including extension) as
# argument.
#
# - Creates a duplicate of the cloud copy in the support directory 'last-synced', for future
#   reference. (The duplicate is used to check if the cloud copy has been changed externally, ie on
#   another machine.)
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
(( $# == 0 )) && fatal_error "Missing argument. KDBX database filename not provided."
pwd_filename="$1"

# Check if the local KDBX file is excluded from cloud sync. Exit quietly if excluded.
is-included-db "$pwd_filename" || exit 0

# Verify cloud database path
cloud_sync_file_win="$(get-cloud-sync-dir)\\$pwd_filename" || fatal_error "Can't find the path to the password file in the cloud sync directory."
safe-file-exists "$cloud_sync_file_win" || fatal_error "The cloud-synced copy is missing or can't be accessed.\n    Path: ${cloud_sync_file_win//\\/\\\\}"

# Create local duplicate of cloud database, in the last-synced directory
last_synced_file="$(get-support-dir last-synced)/$pwd_filename"
safe-filecopy "$cloud_sync_file_win" "$last_synced_file" || fatal_error "Failed to copy the cloud-synced file to a reference location (\"last synced\").\n    Copy source: ${cloud_sync_file_win//\\/\\\\}\n    Copy target: $(wsl-windows-path -e "$last_synced_file")"
