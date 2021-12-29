#!/usr/bin/env bash
set -u

PROGNAME="$(basename "$BASH_SOURCE")"
progdir="$([[ "$BASH_SOURCE" == /* ]] && dirname "$BASH_SOURCE" || { _dir="$( realpath -e "$BASH_SOURCE")"; [[ "$_dir" == /* ]] && dirname "$_dir" || pwd; })"

export PATH="$progdir:$PATH"

LOG="$progdir/ERROR_LOG_TEST.log"

[ -f "$LOG" ] && rm "$LOG"

# Race #1:
# The exit of the main script (this one), as the last one on the call stack, competes against the
# asynchronous logging, which ends in (re-)directing the error messages to stderr, after which they
# will be written to the terminal. If the main script exits first, it returns control to the command
# prompt. Then, the substituted logging process resurfaces, printing error messages to the terminal
# and leaving it without a prompt, which must be regained with Ctrl-C (SIGINT).
#
# In order to demonstrate the outcome, it is no longer left to chance: an artificial `sleep`
# simulates a delay inside the substituted process. Without it, the race is tight (in WSL) and the
# result varies.
exec 2> >(sleep 0.1; tee -a "$LOG" >&2)

# Race #2: See sub1
_error-log-test-sub1
echo "This is an error message from $PROGNAME" >&2