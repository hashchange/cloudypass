#!/usr/bin/env bash

# Top-level wrapper script for lib/get-cloud-sync-dir.

set -eu

# Absolute path to the script.
progdir="$([[ "$BASH_SOURCE" == /* ]] && dirname "$BASH_SOURCE" || { _dir="$( realpath -e "$BASH_SOURCE")"; [[ "$_dir" == /* ]] && dirname "$_dir" || pwd; })"

export PATH="$progdir/lib:$PATH"

# Set up error reporting
exec 2> >(log-errors)

get-cloud-sync-dir
