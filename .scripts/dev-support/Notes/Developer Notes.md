# Developer Notes

## Contents

1. [Missing drives in WSL (e.g. Boxcryptor)](#missing-drives-in-wsl-eg-boxcryptor)
2. [Last Modified timestamp anomalies in Boxcryptor](#last-modified-timestamp-anomalies-in-boxcryptor)
3. [Preserving timestamps when copying files on Windows drives with WSL](#preserving-timestamps-when-copying-files-on-windows-drives-with-wsl)
4. [Writing errors to stderr and a log file](#writing-errors-to-stderr-and-a-log-file)
   - [Using `exec`](#using-exec)
   - [Using a code block](#using-a-code-block)
   - [Where to place it](#where-to-place-it)
   - [Explanation of the logging code](#explanation-of-the-logging-code)
   - [Preventing log entry duplication (or multiplication)](#preventing-log-entry-duplication-or-multiplication)
   - [Process substitution leads to race conditions](#process-substitution-leads-to-race-conditions)
   - [Race conditions while logging #1: Messed-up log entry order](#race-conditions-while-logging-1-messed-up-log-entry-order)
   - [Race conditions while logging #2: Still writing errors after the prompt is back](#race-conditions-while-logging-2-still-writing-errors-after-the-prompt-is-back)
   - [Race conditions while logging #3: Lost log entries when the shell is closed quickly](#race-conditions-while-logging-3-lost-log-entries-when-the-shell-is-closed-quickly)
   - [A simpler solution: writing to the log file only](#a-simpler-solution-writing-to-the-log-file-only)
5. [Useful functions, tested but not used in the project](#useful-functions-tested-but-not-used-in-the-project)
   - [Extracting the drive letter from a WSL path](#extracting-the-drive-letter-from-a-wsl-path)
   - [Checking if a Windows drive has been mounted in WSL](#checking-if-a-windows-drive-has-been-mounted-in-wsl)
   - [Mounting a drive in WSL](#mounting-a-drive-in-wsl)
   - [Calculating a file hash if the drive is not mounted in WSL](#calculating-a-file-hash-if-the-drive-is-not-mounted-in-wsl)
   - [Reading the Last Modified timestamp of a file if the drive is not mounted in WSL](#reading-the-last-modified-timestamp-of-a-file-if-the-drive-is-not-mounted-in-wsl)
   - [Converting a Windows path to Linux format even if the drive is not mounted in WSL](#converting-a-windows-path-to-linux-format-even-if-the-drive-is-not-mounted-in-wsl)
   - [Testing if Powershell scripts can execute](#testing-if-powershell-scripts-can-execute)


## Missing drives in WSL (e.g. Boxcryptor)

If a drive is not available in WSL, the drive might still exist. Network drives and folders mounted as a drive – like Boxcryptor does it – are not mounted automatically in WSL. 

- See https://github.com/Microsoft/WSL/issues/2788#issuecomment-355105691
- Checking if a drive is mounted: See function `is_mounted_in_wsl`, below.

This could be fixed by explicitly mounting the missing drive.

See 
- https://boxcryptor.community/d/14709-windows-linux-subsystem-and-mounting-a-boxryptor-drive
- https://unix.stackexchange.com/a/390658/297737
- Mounting the drive: See function `mount_in_wsl`, below.

But mounting the drive requires `sudo` priviliges and therefore isn't a viable solution in a script which is supposed to run without user intervention.

Instead, the drive can be accessed indirecty via Windows, using DOS or (preferably) Powershell commands. They "see" the drive even if it is not mounted in WSL.


## Last Modified timestamp anomalies in Boxcryptor

For files encrypted with Boxcryptor, the "Last modified" timestamp is prone to a race condition and not stable.

The observations:

- When an encrypted file is modified, the modification time is set. If the file is copied then, to a location outside of Boxcryptor, the copy will retain that modification time forever. Business as usual, so far.
- When reading the modification time of the encrypted file for the first time, it always matches that of the copy (as it should). 
- But when reading the modification time of the encrypted file for a second time, it often – but not always – returns a different value. Compared to the copied file, approximately 0.15-0.25 s have been added to the modification time.
- Sometimes, that shift becomes apparent only after a terminal has been closed and a new one has been opened, suggesting that some kind of intermediate timestamp caching is at play here, too. I.e., the timestamp in the first terminal returns the initial value more than just once, but in the second terminal, the timestamp has changed.
- On other occasions, the initial timestamp does not change, ever. It is as stable as one would expect. That suggests that a race condition plays a crucial role.
- On a positive note, the file content is unaffected by all this. Even if the file is copied immediately after creation, i.e. before the source file is modified again after > 0.15 s, the contents of both files are identical (binary comparison). So the second modification only relates to file metadata, not file content.


What _might_ be going on with Boxcryptor:

- Whenever the timestamp stays the same, perhaps the encryption is completed quickly enough. The post-encryption modification time falls into the same timeframe as the pre-encryption timestamp, given the 100 ns resolution of the NTFS filesystem. On the other hand, if the timestamp shifts, encryption has been delayed significantly for some reason (0.25 s = 2'500'000 timeframes à 100 ns). Timestamp caching might then mask that shift for a while, explaining the unaltered first readout.
- A somewhat related, but more conspicuous Boxcryptor bug [has long been fixed](https://boxcryptor.community/d/11758-bc-14-does-not-use-timestamp-from-original-file). Long encryption delays, to the tune of more than 30 seconds, have again [been observed](https://boxcryptor.community/d/12627-file-modification-time-confusion-for-emacs) a while later. However, sub-second delays are much less likely to be noticed. Indeed, there isn't any public discussion or documentation about this phenomenon.

Why Keepass seems to play a role, too:

- The weird behaviour was impossible to reproduce with a generic test (boxcryptor-timestamp-test.sh, in Experiments). 
- It did, however, happen when the file in Boxcryptor was a Keepass DB, and it was one of the two files involved in a sync (the external DB being synced to).
- So the Keepass sync or save process is somehow relevant, too. Yet it can't be the only ingredient. Tests in a Dropbox directory, without Boxcryptor involvement, did not show the odd behaviour. (Caveat: The tests have not been very extensive. Maybe it has just been down to luck.)
- Most likely neither Boxcryptor nor Keepass Sync is the sole culprit, but the combination of the two.

In theory, when a file has been copied, the "last modified" timestamp could be used to check if the file and its copy are identical, or if the original file has been modified since. That kind of comparison is fast, and it is also reliable: timestamps are quite precise on NTFS drives, with a filetime resolution of 100 ns. In Boxcryptor, though, it doesn't work.

The timestamp of the original may or may not have changed sometime after the encryption, and identical files which have been modified at the exact same time may nonetheless have different timestamps. And even worse, as the first timestamp read-out usually returns identical timestamps, the condition can't be detected immediately after creating the copy.

So file identity has to be checked with a binary file comparison, or by comparing checksums. It is slower, but timestamps can't be relied upon even as a shortcut.


## Preserving timestamps when copying files on Windows drives with WSL

The task: Copying a file while preserving its "last modified" timestamp.

If the file is located in the WSL (Linux) filesystem, not on a mounted Windows drive:

- `cp --preserve=timestamps ...` or `cp -p ...` both work, as expected.
- Without these options, `cp` changes the "last modified" timestamp of the copy to the time it is created. This is documented behaviour.

So no surprises here. 

If the file is located on a mounted Windows drive:

- Use Windows utilities only, NOT `cp`.
- `Powershell.exe -command "Copy-Item ..."` works.
- `cmd.exe /c copy /B ...` works.
- `cp --preserve=timestamps ...` or `cp -p ...` both kill sub-second precision. The timestamp of the copied file is set to a time in full seconds. Fractional seconds are simply discarded, not even rounded.

Powershell `Copy-Item` works with `\\wsl$` UNC paths, too, so it can deal with all locations, on Windows drives as well as inside the WSL filesystem. The DOS `copy` command only works for Windows paths. So Powershell is the safer option.

In summary: If the timestamp matters, use Powershell `Copy-Item` on Windows drives. If the timestamp of the copy doesn't have to be precise or doesn't matter at all, use `cp`. A native command is much faster than a executing a Powershell command from inside WSL.


## Writing errors to stderr and a log file

There are two ways of achieving this – with an `exec` call for the remainder of the script, or with a code block (`{ ... }`) for a limited part of it. Apart from the scope, both methods are equivalent.

### Using `exec`

The most common method is the initial `exec` statement:

```bash
    exec 2> >(tee -a "$ERROR_LOG" >&2)
```
The `exec` call, when not followed by the name of another command, [sets up redirections for the current script](https://askubuntu.com/a/525788/1027405). More precisely, it creates the redirections for the current shell (the one created as context for the script), which is then also applied to child processes, e.g. commands called from the script, subshells etc. 

For the logging construct as a whole, see 
- https://askubuntu.com/a/1027519/1027405
- http://mywiki.wooledge.org/BashFAQ/106

### Using a code block

Alternatively, the relevant parts of the code can be wrapped in a code block (`{ ... }`), redirecting the errors which happen within it:

```bash
{
    # Code here
    # ...
} 2> >(tee -a "$ERROR_LOG" >&2)
```

The `{ ... }` code block acts as an anonymous function. Error redirection is set up at its end. See https://stackoverflow.com/a/315113/508355

### Where to place it

Either logging solution **must only appear in a top-level script**, not in the utility scripts called by it. Never allow a script with logging code to call another script which does the same. If that is unavoidable, 

- move all the actual work from the top-level scripts into utility scripts
- turn the top-level scripts into dumb wrappers which take care of the logging and then call the appropriate utility script
- use the top-level scripts as exclusive entry points which never call one another.

### Explanation of the logging code

- `2>`: stderr is directed ...
- `>( )`: ... to a subshell (using process substitution), which runs asynchonously. 
- `tee -a "$ERROR_LOG"`: There the input is split with `tee`, with one stream being written to the log file. The other stream is directed to stdout, as `tee` always does it.
- ` >&2`: stout is then redirected to stderr (`>&2`).
  
See https://stackoverflow.com/a/692407/508355

### Preventing log entry duplication (or multiplication)

Writing stderr to the log can't be done in multiple scripts which are calling each other – it **must be restricted to the top-level script**. All other scripts must write to stderr only. Otherwise, two, three or even more entries of the same error would clutter the log, depending on the depth of the call stack when an error occurs.
  
Suppose the main script, A, calls script B, which then calls script C where an error occurs, with an error message written to stderr. Script C captures the stderr output, initiates the logging and also writes the error message back to stderr (`tee ... >&2`). Then it exits. Script B also captures stderr output, writes it to the log and back to stderr. Script A does the same thing. After that, no more capturing takes place, and stderr is written to the terminal. So on the terminal, just a single error message is displayed, but it has been written to the log three times.

There are just two ways out of it. Either the error message is logged _only_, and not written back to stderr. Then it can be logged when it occurs (script C), but it won't appear in the terminal. The other option is to capture and process stderr only in the top-level script, as required above.

Run the `error-log-test.sh` experiment as an practical example.

### Process substitution leads to race conditions

Process substitution (`>(...)`) creates a child process (subshell) which runs in the background. In other words, the commands in it are executed asynchronously. As a result, process substitution it might (and in fact does) lead to race conditions. 

See 
- https://www.gnu.org/software/bash/manual/html_node/Process-Substitution.html
- http://mywiki.wooledge.org/ProcessSubstitution

Race conditions are more likely to be observed when the command inside the process substitution takes a long time to finish. In WSL, file access is exceedingly slow on mounted Windows drives (accessed via the a 9P protocol file server, i.e. as a filesystem on a network). So `tee` takes a long time to finish when the log file resides on a Windows drive, and it shows.

### Race conditions while logging #1: Messed-up log entry order

If every script sets up its own logging with process substitution (i.e., asynchronously), the following sequence of events has indeed been observed:
  
- Script A calls script B, which writes an error message to stderr, and the whole stderr capture/tee/redirect dance unfolds. The latter part happens asynchronously and takes a while. Meanwhile, script B exits with an error status, reverting control to script A.

- Script A detects the error exit code and writes an error message of its own to stderr. Again, the capture/process substitution/`tee`/redirect sequence is initiated. Now we have two `tee` commands trying to write to the log in independent, asynchronous processes, both competing which gets to the log first.

- And indeed, for whatever reason, tests on WSL have shown that script A, which generates its error message last, gets it into the log first – before script B has logged the error preceding it.

So if logging is not restricted to the top-level script, the ordering of the log entries [does not necessarily reflect the order in which the errors have occurred](http://mywiki.wooledge.org/BashFAQ/106).

Again, run the `error-log-test.sh` experiment as an practical example. Both the error messages on the screen and the log content demonstrate the confused order (with a little help from `sleep` to show it consistently, see script comments).

### Race conditions while logging #2: Still writing errors after the prompt is back

If every script sets up its own logging with process substitution (i.e., asynchronously), the terminal regains the command prompt before the logging is done. Some or all of the log output is written to the terminal after the prompt. 

Visually, the terminal seems to "hang" with an unterminated process. In fact it does not, and the terminal is ready for input. Given that the cursor ends up in a new line, a command line which is typed there will be executed normally. However, the command prompt symbol (at the beginning of the line) can be regained when Ctrl-C (SIGINT) is pressed.

Again, this mostly happens in WSL on a Windows file system. But it can be demonstrated with the following one-liner in any Bash terminal, where slow filesystem access is simply simulated with `sleep`:

```bash
(exec 2> >(sleep 1; tee -a "EXAMPLE_ERROR.log" >&2); echo "Oops" >&2; exit 1)
```

The sequence of events is the same as in [race condition #1](#race-conditions-while-logging-1-messed-up-log-entry-order). But here, the competitors are different:

- The logging processes do their thing asynchronously. While they are at it, control reverts to the scripts in the call stack, until finally the top-level script exits.

- If the logging is done by then, it is business as usual. The top-level script exits, and the command prompt reappears in the terminal. The error messages have already been printed above it.

- However, if the script exit comes first, a command prompt appears, but then the logging processes resurface. They print their output after the prompt now, leaving the terminal seemingly "hanging" without a prompt (but in fact ready for input). The prompt can be regained with Ctrl-C (SIGINT).

The root cause of the problem is async execution of the substituted process, which returns so late that the original process has already exited. The substituted process then writes stderr to the terminal. The async nature of the setup is the same everywhere, but it manifests only if there is a significant delay for the stuff done in the substituted process, like writing to a file in a slow 9p-driven network filesystem (WSL).

This issue is **not remedied** by restricting the logging to the top-level script. It can even occur in a single-script setup. Even then, the process substitution is pitted against the main script in a race to exit first. But it mostly seems to happen (even in WSL) if the error occurs very soon after the logging is set up. Further down the line, logging is usually faster than the exit from the script (although this is just a casual observation and cannot be not guaranteed).

However, there is a way to prevent the problem entirely. It is covered next.

### Race conditions while logging #3: Lost log entries when the shell is closed quickly

Log entries [may still appear](#race-conditions-while-logging-2-still-writing-errors-after-the-prompt-is-back) after the prompt is back. But if the terminal is closed quickly, there is no prompt any more. The messages which are directed to the terminal can't be printed and are lost. But what about the log entries directed to a file?

In a Bash terminal, after the terminal exits, the entries still make it to the file. The following command sequence is the same as above (in [race condition #2](#race-conditions-while-logging-2-still-writing-errors-after-the-prompt-is-back)), but the final `exit` command closes the terminal itself. The log file gets created nonetheless.

```bash
(exec 2> >(sleep 1; tee -a "EXAMPLE_ERROR.log" >&2); echo "Oops" >&2; exit 1); exit
```

But things change when the call is made from a Windows command prompt, using WSL. When the parent process – the `wsl` command – exits, it takes all child processes with it _immediately_, including any asynchronous subshells. And `wsl` dies as soon as the top-level script returns. 

At that moment the log entries are still waiting to be written. But WSL is gone, and so is the log process. The entries don't make it to the log file and are lost.

In the following example, the latency of writing to the file system is simulated with `sleep`. In real-world use, long delays are the norm because writing to the Windows file system is so excruciatingly slow. (NB: `^` escapes the following character for the cmd command line.)

```bat
wsl (exec 2^> ^>(sleep 1; tee -a "EXAMPLE_ERROR.log" ^>^&2); echo "Oops" ^>^&2; exit 1)
```

The file won't be created in the example above. 

However, if the `wsl` process is forced to hang around long enough (e.g. with `sleep`), the log will show up in both the terminal and the file:

```bat
wsl (exec 2^> ^>(sleep 1; tee -a "EXAMPLE_ERROR.log" ^>^&2); echo "Oops" ^>^&2; exit 1); sleep 3
```

That works. It is not a proper solution, though. The problem should be fixed in the script which sets up the logging, not by a hack bolted onto the command line. The task is to keep the script itself from exiting before the logging is done.

To that end, the script must `wait` for the logger subshell to complete (the [process ID of the logger subshell](http://mywiki.wooledge.org/BashFAQ/106#:~:text=In%20bash%204.4%2C%20a%20ProcessSubstitution%20sets%20the%20%24!%20parameter) is needed for that). 

But there is a catch. Because the logger subshell is waiting for input from stderr, it is never "done". It will keep running unless it is disconnected from stderr. So one more step is needed: When it is certain that no more error logging will be initiated, the file descriptor for stderr has to be closed. Then the subshell will close shop. Once all the data queued for logging (in the output buffer, waiting to be written to the log file) has been processed, the process substitution subshell exits. The `wait` is over and the top-level script is allowed to exit, too.

That two-step procedure – closing stderr and waiting for the subshell to finish its tasks – has to be placed at every conceivable exit point of the top-level script. Usually, there are just two of them:

- at the end of the script
- when a fatal error is handled (it is logged first, then the script exits).

This is what the solution looks like:

```bash
close_log() { exec 2>&-; wait $log_process_id; }

# Close the log after a fatal error is logged. Only in the top-level script!
fatal_error() { echo -e "$1" >&2; close_log; exit 1; }    

exec 2> >(tee -a "$ERROR_LOG" >&2)
log_process_id=$!

# ... do stuff, e.g.
# some_command || fatal_error "some_command has failed"

# Close the log when the script has reached its end
close_log
```

Important: `close_log` has to be called in `fatal_error`, but _only in the top-level script_.

The second `close_log` invocation has to be the last command in the script. But there is one exception: in scripts where the result of the script is conveyed by its exit code (e.g. boolean tests). Normally, the exit code would be set by the last command in the script. Now that status has to be captured and transferred to the end:

```bash
# ... do stuff ...

# The exit code of the command below should be returned, but we still have to
# close the log at the very end
final_command 
result=$?

close_log
exit $result
```

Ending the top-level script like that is good houskeeping in most situations, not just for boolean tests. E.g., the last call in the script might exit with an error status. Unless it is handled with `... || fatal_error`, the exit status should be captured and passed on.

The final implementation can be found in the top-level scripts of Cloudypass. It is a bit cleaner but functionally identical.

See
- http://mywiki.wooledge.org/BashFAQ/106
- http://mywiki.wooledge.org/ProcessSubstitution
- https://unix.stackexchange.com/questions/131801/closing-a-file-descriptor-vs

### A simpler solution: writing to the log file only

All of these issues don't matter if errors are just logged to a file and not written to stderr as well. 

```bash
exec 2>"$ERROR_LOG"
```

Logging to a file ONLY, without redirection to stderr, eliminates the need for `tee` and hence for process substitution, so no race condition. Things are simpler then:

- We no longer end up [without a command prompt](#race-conditions-while-logging-2-still-writing-errors-after-the-prompt-is-back). The issue was caused by asynchronous delays in the substituted process.
- Proper [ordering of log entries](#race-conditions-while-logging-1-messed-up-log-entry-order) is guaranteeed because it's not async.
- No [duplicate entries](#preventing-log-entry-duplication-or-multiplication). The error message is not fed back into stderr once logged, so it isn't recaptured by stderr logging in higher-level scripts. 

However, if error messages are supposed to appear in the terminal, too, then logging must be limited to the top-level script. And the top-level script must wait for the logging to complete.


## Useful functions, tested but not used in the project

#### Extracting the drive letter from a WSL path

Extracts the drive letter from a WSL path string. The path and the drive don't need to exist. Returns the drive letter as it is found in the path, i.e. usually in lower case.

Usage:

    get_wsl_drive_letter "/mnt/x/foo/bar"

Code:

```bash
get_wsl_drive_letter() { sed -rn 's_^/mnt/([a-zA-Z])($|/.*)_\1_p' <<<"$1"; }
```

Example:
```bash
some_wsl_path_on_mnt="/mnt/x/foo/bar"
drive_letter="$(get_wsl_drive_letter "$some_wsl_path_on_mnt")"
[ $? -ne 0 -o -z "$drive_letter" ] && fatal_error "The path does not refer to a Windows drive, or is malformed. The drive letter could not be identified."
```

#### Checking if a Windows drive has been mounted in WSL

This is useful for drives other than physical volumes, e.g. the Boxcryptor drive, which are NOT mounted in WSL by default. To be used in `if` statements etc.

Usage: 

    is_mounted_in_wsl "x" || fatal_error "Drive not mounted"
    if is_mounted_in_wsl "X"; then ...

Argument: The drive letter. Is not case-sensitive.

```bash
is_mounted_in_wsl() { [[ "$(findmnt -lfno TARGET -T "/mnt/${1,}")" =~ ^/mnt/${1,}$ ]]; }
```

Notes: 
- `${1,}` = argument #1, with first letter converted to lower case 
- findmnt options in long, readable form:
  `findmnt --list --first-only --noheadings --output TARGET --target "/mnt/$drive_letter_lc"`
- If matching, findmnt returns: `/mnt/$drive_letter_lc`, e.g. `/mnt/c`
- If not matching, findmnt returns nothing or `/`


#### Mounting a drive in WSL

This could be useful for mounting missing, but existing drives (see above). BUT mounting a drive almost always requires sudo priviliges!

Usage: 

    sudo mount_in_wsl "x"

Argument: The drive letter. Is not case-sensitive.

```bash
mount_in_wsl() { mount -t drvfs "${1^^}:\\" "/mnt/${1,,}"; }
```

Notes: 
- `${1,,}` = argument #1, converted to lower case 
- `${1^^}` = argument #1, converted to upper case 


#### Calculating a file hash if the drive is not mounted in WSL

Again, this is useful for unmounted, but existing drives like the Boxcryptor drive (see above). The operation needs to be delegated to Powershell, as it can "see" the drive while Linux commands can't.

Usage: 

    get_hash filepath

Argument: The file path. The path, in the stand-alone version below, must be provided in Windows format.

```bash
get_hash() { Powershell.exe -command "(Get-FileHash -Algorithm MD5 -LiteralPath '"$1"').Hash" | tr -d '\r'; }
```

In the alternative version, the path can be passed either in Windows format or as a WSL/Linux path (`/mnt/[drive]/...`). BUT it requires the `wsl-windows-path` utility.

```bash
get_hash() { Powershell.exe -command "(Get-FileHash -Algorithm MD5 -LiteralPath '"$(wsl-windows-path -f "$1")"').Hash" | tr -d '\r'; }
```

Notes: 
- The `wsl-windows-path` utility is available in the .scripts/lib directory, or [as a gist on Github](https://gist.github.com/hashchange/f4cd619def08def6e90704e9905ce3d0).
- `tr -d '\r'`: Windows newlines (\\r\\n) in Powershell output must be fixed by removing \\r. Otherwise, comparisons based on the output can fail.
- Instead of MD5, another algorithm can be used. See the [`Get-FileHash` documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash?view=powershell-7.2#parameters)(`-Algorithm` parameter).


#### Reading the Last Modified timestamp of a file if the drive is not mounted in WSL

Again, useful for Boxcryptor drives. Returns the timestamp with maximum precision.

Usage: 

    get_last_modified filepath

Argument: The file path. The path, in the stand-alone version below, must be provided in Windows format.

```bash
get_last_modified() { Powershell.exe -command "(Get-Item '"$1"').LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff')" | tr -d '\r'; }
```

In the alternative version, the path can be passed either in Windows format or as a WSL/Linux path (`/mnt/[drive]/...`). BUT it requires the `wsl-windows-path` utility.

```bash
get_last_modified() { Powershell.exe -command "(Get-Item '"$(wsl-windows-path -f "$1")"').LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff')" | tr -d '\r'; }
```

Notes: 
- The date format of the output, and the precision, can easily be changed by altering the [`ToString` format string](https://docs.microsoft.com/en-us/dotnet/standard/base-types/formatting-types#custom-format-strings).
- `wsl-windows-path`, `tr -d '\r'`: see `get_hash` notes, above.


#### Converting a Windows path to Linux format even if the drive is not mounted in WSL

The problem: `wslpath` throws an error if the drive is not mounted in WSL. So `wslpath` doesn't work for the Boxcryptor drive.

The function below does handle that special case and works for ordinary, mounted drives, too. It converts a Windows path to Linux format. The path does not have to exist. 

If the path does not conform to an absolute Windows path pattern (i.e., it doesn't begin with `[Drive letter]:\\`), then backslashes are converted to forward slashes, but otherwise the path is returned as it was passed in. A Linux path is returned unchanged.

The function expects the path as an argument or from stdin, i.e. it works in a pipe.

Usage: 

    to_linux_path filepath
    ... | to_linux_path

```bash
to_linux_path() {
    local path="${1:-$(</dev/stdin)}"
    <<<"$path" sed -r -e 's_^([a-zA-Z]):(.+)$_/mnt/\L\1\E\2_' -e 's_\\_/_g'
}
```

Notes: 
- `\L` in sed replacement: text is converted to lower case from here on out
- `\E` in sed replacement: ends `\L` conversion


#### Testing if Powershell scripts can execute

Powershell commands can always be executed directly, but for executing scripts, the appropriate policy must be set on the machine. Execution of unsigned scripts is not permitted by default. The function checks it and is to be used in `if` statements etc.

Usage: 

    can-execute-powershell-scripts || fatal_error "Execution of Powershell scripts is not permitted"
    if can-execute-powershell-scripts; then ...

Argument: None.

```bash
can-execute-powershell-scripts() { [[ $(Powershell.exe -command '$policy = Get-ExecutionPolicy; Write-Host (($policy -eq "Restricted") -or ($policy -eq "AllSigned"))' | tr -d '\r') == False ]]; }
```

Notes: 
- For more on Powershell execution policies, see [Managing the execution policy with PowerShell](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2) in the Microsoft Docs.
- `tr -d '\r'`: see `get_hash` notes, above.


