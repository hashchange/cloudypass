#!/usr/bin/env bash

set -eu

# Script name
PROGNAME="$(basename "$BASH_SOURCE")"

# Absolute path to the script.
progdir="$([[ "$BASH_SOURCE" == /* ]] && dirname "$BASH_SOURCE" || { _dir="$( realpath -e "$BASH_SOURCE")"; [[ "$_dir" == /* ]] && dirname "$_dir" || pwd; })"

export PATH="$(realpath "$progdir/../../lib"):$PATH"

fatal_error() {
    echo -e "$PROGNAME: $1" >&2;
    exit 1;
}

is_wsl() {
    [ -n "${WSL_DISTRO_NAME}" ]
}

# Argument is a path in Linux format.
get_wsl_drive_letter() {
    sed -rn 's_^/mnt/([a-zA-Z])($|/.*)_\1_p' <<<"$1"
}

# Argument is the drive letter. Case-insensitive.
is_mounted_in_wsl() {
    [[ "$(findmnt -lfno TARGET -T "/mnt/${1,}")" =~ ^/mnt/${1,}$ ]]
}

is_windows_dir() {
    is_wsl && [[ "$(wslpath -w ".")" =~ [a-zA-Z]:\\ ]]
}

# Converts a Windows path to Linux format. Does the same as `wslpath`, but `wslpath` throws an error
# if the drive is not mounted in WSL. Ie, `wslpath` doesn't work for the Boxcryptor drive.
#
# The path does not have to exist. If the path does not conform to an absolute Windows path pattern,
# any backslashes are converted to forward slashes, but otherwise the path is returned as it was
# passed in. Ie, a Linux path is returned unchanged.
to_linux_path() {
    local path="${1:-$(</dev/stdin)}"
    <<<"$path" sed -r -e 's_^([a-zA-Z]):(.+)$_/mnt/\L\1\E\2_' -e 's_\\_/_g'
}

get_last_modified() {
    Powershell.exe -command "(Get-Item '"$1"').LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff')" | tr -d '\r';
}

get_hash() {
    Powershell.exe -command "(Get-FileHash -Algorithm MD5 -LiteralPath '"$1"').Hash" | tr -d '\r';
}

get_ps_lib_path_win() {
    echo "$(wslpath -aw "$progdir")\\boxcryptor-timestamp-test-lib.ps1"
}

can-execute-powershell-scripts() {
    [[ $(Powershell.exe -command '$policy = Get-ExecutionPolicy; Write-Host (($policy -eq "Restricted") -or ($policy -eq "AllSigned"))' | tr -d '\r') == False ]]
}

create_test_fixture() {
    Powershell.exe -command ". '$(get_ps_lib_path_win)'; echo (Create-TestFixture '"$1"' '"$2"')" | tr -d '\r';
}

get_first_timestamp() {
    Powershell.exe -command ". '$(get_ps_lib_path_win)'; echo (Get-FirstTimestamp '"$1"' '"$2"' '"${3:-""}"')" | tr -d '\r';
}

get_followup_timestamp() {
    Powershell.exe -command ". '$(get_ps_lib_path_win)'; echo (Get-FollowUpTimestamp '"$1"' '"$2"')" | tr -d '\r';
}

# Only creates the file if it doesn't exist, or if the file size doesn't match the requested size.
# Expects the file name as first argument, and an optional file size as second argument.
#
# The file size can be specified as a number, in bytes, or in human-readable format (e.g. "5K",
# "12M", "1G" - Gigabyte!). Default size is 1 MB.
#
# Returns the full path to the file.
create_local_test_file() {
    local required_size="${2:-"1M"}"
    local path="$progdir/$1"

    # Exit if the file exists and the size matches.
    # - Normalizing the required size to bytes: see https://stackoverflow.com/a/37016129/508355
    # - Getting the actual size in bytes: see https://unix.stackexchange.com/a/16644/297737
    if [ -f "$1" ] && [[ "$(numfmt --from=iec "$required_size")" == "$(stat -c%s "$1")" ]]; then
        echo "$path"
        exit 0;
    fi

    # Create the file. See https://unix.stackexchange.com/a/33634/297737
    head -c "$required_size" </dev/urandom >"$path"
    echo "$path"
}

test_run() {
    # Check if .ps1 files are allowed to execute
    can-execute-powershell-scripts || fatal_error "Powershell script execution is not permitted. Enable it in order to run this test.\n\nScript execution can be allowed for the current user with the following command:\n\n    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned\n"

    local encrypted_parent_dir='J:\Dropbox\Encryption Tests\Encrypted dir with name encryption'

    local test_dir_name="timestamp_test_$(date +%s%N)"
    local test_file_name="testfile.dat"

    local test_fixture_path="$(create_test_fixture "$encrypted_parent_dir" "$test_dir_name")"
    echo "Test dir path: $test_fixture_path"

    local test_data_path="$(create_local_test_file "test_data.dat" "10M")"

    # For generating a new file in place, rather than copying one from another location, leave out
    # the source file path (3rd arg):
    # local original_timestamp="$(get_first_timestamp "$test_file_name" "$test_fixture_path")"
    local original_timestamp="$(get_first_timestamp "$test_file_name" "$test_fixture_path" "$(wsl-windows-path -f "$test_data_path")")"
    echo "Timestamp #1: $original_timestamp    (original timestamp)"

    local timestamp
    for i in {2..5}; do
        sleep 2
        timestamp="$(get_followup_timestamp "$test_file_name" "$test_fixture_path")"
        echo "Timestamp #$i: $timestamp    $([[ "$timestamp" == "$original_timestamp" ]] && echo OK || echo CHANGED)"
    done
}

test_run
