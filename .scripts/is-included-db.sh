#!/usr/bin/env bash

# Top-level wrapper script for lib/is-included-db.
#
# For exit codes, see there.

set -eu

# Absolute path to the script.
progdir="$([[ "$BASH_SOURCE" == /* ]] && dirname "$BASH_SOURCE" || { _dir="$( realpath -e "$BASH_SOURCE")"; [[ "$_dir" == /* ]] && dirname "$_dir" || pwd; })"

export PATH="$progdir/lib:$PATH"

# Set up error reporting
close_log() { exec 2>&-; wait $log_process_id; }
end_script_with_status() { close_log; exit "${1:-0}"; }

exec 2> >(log-errors)
log_process_id=$!

# Task
is-included-db "$@"

end_script_with_status $?