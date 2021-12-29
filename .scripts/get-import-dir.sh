#!/usr/bin/env bash

# Returns the path of the import directory (which is the temp-import directory) in Windows format.
# Throws an error if the directory does not exist or is not accessible.

set -eu

# Script name
PROGNAME=$(basename "$0")

# Absolute path to the script.
progdir="$([[ "$BASH_SOURCE" == /* ]] && dirname "$BASH_SOURCE" || { _dir="$( realpath -e "$BASH_SOURCE")"; [[ "$_dir" == /* ]] && dirname "$_dir" || pwd; })"

export PATH="$progdir/lib:$PATH"

# Set up error reporting
exec 2> >(log-errors)

# Functions
fatal_error() { echo -e "$PROGNAME: $1" >&2; exit 1; }

get-support-dir --windows-format temp-import || fatal_error "Failed to determine the path to the import directory."
