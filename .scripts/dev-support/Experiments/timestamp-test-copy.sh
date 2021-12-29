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
    echo "Creation of second file delayed by: ${delay}s";
}

long_delay() {
    delay 1
}

delay_unless_win_fs() {
    ! is_windows_dir && delay
}

test_comparison_methods() {
    echo "$1: $(stat -c "%.Y" "$1")"
    echo "$2: $(stat -c "%.Y" "$2")"

    [ "$(stat -c "%.Y" "$1")" != "$(stat -c "%.Y" "$2")" ] && echo "stat:  Timestamp different" || echo "stat:  Timestamp equal"
    [ "$1" -ot ""$2 -o "$1" -nt "$2" ] && echo "ot/nt: Timestamp different" || echo "ot/nt: Timestamp equal"

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

    echo "Test timestamps with minimal difference (files created independently)"
    # ext3/4 accuracy: see 
    # - https://stackoverflow.com/a/14393315/508355
    # - https://stackoverflow.com/a/60846117/508355
    echo "- WSL ext3: OK Timestamps are different if true difference > timestamp accuracy (Accuracy"
    echo "               is dependent on the system. Safe bet on modern systems: 10ms resolution."
    echo "               Super safe bet: 1s.)."
    echo "- WSL 9p:   OK Timestamps are different even without sleep (minimal difference)."
    echo "test" > file1.txt
    delay_unless_win_fs
    echo "test" > file2.txt

    test_comparison_methods file1.txt file2.txt

    echo "Test simple file copy"
    echo "- WSL ext3: OK cp **modifies the timestamps** as expected."
    echo "- WSL 9p:   OK cp **modifies the timestamps** as expected."
    echo "test" > file3.txt
    long_delay
    cp file3.txt file4.txt
    test_comparison_methods file3.txt file4.txt

    echo "Test file copy with --preserve=timestamps option"
    echo "- WSL ext3: OK   Timestamps are equal."
    echo "- WSL 9p:   FAIL Timestamps should be strictly equal, but they are not. Copied file loses"
    echo "                 sub-second precision (discarded, not rounded)."
    echo "test" > file5.txt
    long_delay
    cp --preserve=timestamps file5.txt file6.txt
    test_comparison_methods file5.txt file6.txt

    echo "Test hardlink to identical file"
    echo "- WSL ext3: OK Timestamps are equal."
    echo "- WSL 9p:   OK Timestamps are equal."
    echo "test" > file7.txt
    long_delay
    cp -l file7.txt file8.txt
    test_comparison_methods file7.txt file8.txt

    echo "Test scp copy (locally)"
    echo "- Behaviour identical to cp (without --preserve=timestamps option)."
    echo "- WSL ext3: OK scp **modifies the timestamps** as expected."
    echo "- WSL 9p:   OK scp **modifies the timestamps** as expected."
    echo "test" > file09.txt
    long_delay
    scp file09.txt file10.txt
    test_comparison_methods file09.txt file10.txt

    echo "Test rsync copy (locally)"
    echo "- Behaviour identical to cp (without --preserve=timestamps option)."
    echo "- WSL ext3: OK rsync **modifies the timestamps** as expected."
    echo "- WSL 9p:   OK rsync **modifies the timestamps** as expected."
    echo "test" > file11.txt
    long_delay
    rsync file11.txt file12.txt
    test_comparison_methods file11.txt file12.txt

    if is_wsl; then
        echo "WSL: Testing Windows utilities"
        echo ""

        echo "Test DOS copy"
        if is_windows_dir; then
            echo "- WSL ext3: n/a DOS copy only works on Windows drives, not for \\\\wsl$ paths."
            echo "- WSL 9p:   OK  Timestamps are equal."
            echo "test" > file13.txt
            long_delay
            cmd.exe /c copy /B file13.txt file14.txt
            test_comparison_methods file13.txt file14.txt
        else
            echo "Test skipped. DOS copy only works on Windows drives, not for \\\\wsl$ paths."
            echo 
        fi

        echo "Test Powershell Copy-Item"
        echo "- WSL ext3: OK Timestamps are equal."
        echo "- WSL 9p:   OK Timestamps are equal."
        echo "test" > file15.txt
        long_delay
        Powershell.exe -command "Copy-Item file15.txt -Destination file16.txt"
        test_comparison_methods file15.txt file16.txt
    fi

    cd "$cwd"
    rm -rf "$temp_dir_name"
}

test_run ~

if is_wsl; then 
    test_run  "$(wslpath "$(wslvar USERPROFILE)")"
fi
