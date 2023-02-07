#!/usr/bin/env bash

is_wsl() {
    [ -n "${WSL_DISTRO_NAME}" ]
}

is_windows_dir() {
    is_wsl && [[ "$(wslpath -w ".")" =~ [a-zA-Z]:\\ ]]
}

# delay=0.01 matches ext fs timestamp resolution
delay() {
    delay=${1:-0.01}; 
    sleep $delay; 
    echo "Moving the file delayed by: ${delay}s";
}

long_delay() {
    delay 1
}

delay_unless_win_fs() {
    ! is_windows_dir && delay
}

get_timestamp() {
    stat -c "%.Y" "$1"
}

compare_to_prev_timestamp() {
    echo "Before: $2"
    echo "After:  $(get_timestamp "$1")"

    [ "$2" != "$(get_timestamp "$1")" ] && echo "stat:  Timestamp different" || echo "stat:  Timestamp equal"
    echo
}

test_run() {
    cwd="$(pwd)"

    test_basedir="$(realpath -e "${1:-"$cwd"}")" || { echo "Test basedir does not exist." >&2; exit 1; }
    temp_dir_name="$test_basedir/timestamp_test_$(date +%s%N)"
    mkdir "$temp_dir_name" || { echo "Test subdir can't be created." >&2; exit 1; }

    cd "$temp_dir_name"

    fs_type="$(stat -f -c %T .)"

    echo "--- $(pwd) ---"
    echo 
    echo "Filesystem Type: $fs_type"
    echo

    echo "Test mv"
    echo "- WSL ext3: OK Timestamps are equal."
    echo "- WSL 9p:   OK Timestamps are equal."
    echo "test" > file1.txt
    long_delay
    original_timestamp="$(get_timestamp file1.txt)"
    mv file1.txt file2.txt
    compare_to_prev_timestamp file2.txt "$original_timestamp"

    echo "Test hardlink to identical file"
    echo "- WSL ext3: OK Timestamps are equal."
    echo "- WSL 9p:   OK Timestamps are equal."
    echo "test" > file3.txt
    long_delay
    original_timestamp="$(get_timestamp file3.txt)"
    cp -l file3.txt file4.txt
    rm file3.txt
    compare_to_prev_timestamp file4.txt "$original_timestamp"

    if is_wsl; then
        echo "WSL: Testing Windows utilities"
        echo ""

        echo "Test DOS move"
        if is_windows_dir; then
            echo "- WSL ext3: n/a DOS move only works on Windows drives, not for \\\\wsl$ paths."
            echo "- WSL 9p:   OK  Timestamps are equal."
            echo "test" > file5.txt
            long_delay
            original_timestamp="$(get_timestamp file5.txt)"
            cmd.exe /c move /Y file5.txt file6.txt
            compare_to_prev_timestamp file6.txt "$original_timestamp"
        else
            echo "Test skipped. DOS copy only works on Windows drives, not for \\\\wsl$ paths."
            echo 
        fi

        echo "Test Powershell Move-Item"
        echo "- WSL ext3: OK Timestamps are equal."
        echo "- WSL 9p:   OK Timestamps are equal."
        echo "test" > file7.txt
        long_delay
        original_timestamp="$(get_timestamp file7.txt)"
        Powershell.exe -command "Move-Item file7.txt -Destination file8.txt"
        compare_to_prev_timestamp file8.txt "$original_timestamp"
    fi

    cd "$cwd"
    rm -rf "$temp_dir_name"
}

test_run ~

if is_wsl; then
    USERPROFILE_PATH="$(cmd.exe /c "<nul set /p\"=%UserProfile%" 2>/dev/null)"
    test_run  "$(wslpath "$USERPROFILE_PATH")"
fi
