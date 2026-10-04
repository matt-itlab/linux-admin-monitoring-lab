# Bash Health Check Development

**Status:** The repository script checks service activity, root filesystem usage, memory usage, and ICMP reachability, returning one overall exit code. Ubuntu runs verified service or resource-check failure (`1`), invalid input (`1`), ICMP failure (`1`), and preservation of an earlier service failure despite successful resource and ICMP checks. After normal settings were restored, the final run passed all four checks and returned `0`. The supplied final Ubuntu source matches the repository logic. Logging and cron execution remain pending.

## First Verified Service Check

On 2026-10-02, the lab owner ran this Bash fragment in the Ubuntu SSH session as `matt` on `linux01`:

```bash
if systemctl is-active --quiet nginx; then
    echo "OK: nginx is running"
else
    echo "ERROR: nginx is not active"
fi
```

The supplied output was:

```text
OK: nginx is running
```

`systemctl is-active` checks the unit's runtime state. `--quiet` suppresses its normal status output while preserving its exit code. Bash `if` runs the `then` branch when the command succeeds with exit code `0`, and the `else` branch otherwise. The observed message confirms that the active-service branch ran.

This checks Nginx's systemd state. HTTP response checks are separate; the [Nginx outage exercise](05-nginx.md#controlled-nginx-outage) records the earlier curl verification.

The initial checks were executed interactively; saved-file verification is recorded below. Printing an error message alone does not establish a meaningful script exit code. The subsequent failure test and fix demonstrate this distinction.

## Service Name Variable

On 2026-10-04, the lab owner supplied this updated fragment and its result from the Ubuntu SSH session:

```bash
service='nginx'
if systemctl is-active --quiet "$service"; then
    echo "OK: $service is running"
else
    echo "ERROR: $service is not active"
fi
```

Observed output:

```text
OK: nginx is running
```

The assignment stores the literal unit name. Double quotes around `"$service"` allow variable expansion while passing the name as one argument to `systemctl`. The double-quoted messages also expand the variable. This verifies the variable-based check and message for active Nginx. The following test covers the `else` branch.

## Nonexistent Unit Check

On 2026-10-04, the lab owner repeated the same fragment with the assignment changed to:

```bash
service='linux-lab-missing.service'
```

The supplied output was:

```text
ERROR: linux-lab-missing.service is not active
```

This confirms that the unsuccessful `systemctl` check selected `else` and that the message used the changed variable value. It is a test using a deliberately nonexistent unit; it does not establish a Nginx outage. Both branch-selection tests are now complete. The overall fragment's exit code was not supplied.

## Saved Script and First Run

On 2026-10-04, the lab owner supplied the output of `cat health-check.sh` from `~/linux-lab/scripts` on Ubuntu. The initial file included the `#!/usr/bin/env bash` shebang, `service='nginx'`, and the verified conditional. The repository's [scripts/health-check.sh](../scripts/health-check.sh) contains the latest verified version; the exit-code fix and subsequent disk-check integration are documented below.

The lab owner then ran:

```bash
bash health-check.sh
echo $?
```

Observed output:

```text
OK: nginx is running
0
```

This verifies the active-service path when the code is read from a file. The script was invoked explicitly with Bash; direct execution via `./health-check.sh` was not tested. The repository's `.gitattributes` keeps shell scripts on LF line endings for Linux compatibility when checked out on Windows.

That initial version printed a message in each branch but did not explicitly set a failure exit code. The following test confirmed the effect of that limitation.

## Saved-File Failure Test: Incorrect Success Status

On 2026-10-04, after changing the Ubuntu script's assignment to `service='linux-lab-missing.service'`, the lab owner ran:

```bash
bash ~/linux-lab/scripts/health-check.sh
echo $?
```

Observed output:

```text
ERROR: linux-lab-missing.service is not active
0
```

The error branch was selected, but the script reported success to its caller. In that version, the branch ended with a successful `echo`; without an explicit exit status, Bash returns the status of the last executed command. See the [Bash exit-status reference](https://www.gnu.org/s/bash/manual/html_node/Exit-Status.html).

This test established the failure-reporting limitation. The subsequent change and verification are recorded below.

## Explicit Exit Codes: Fix and Verification

On 2026-10-04, the lab owner added `exit 0` after the success message and `exit 1` after the error message inside the script. The supplied executions verified both outcomes:

| Unit selected | Observed script output | Exit code read immediately after the run |
| --- | --- | --- |
| `nginx` | `OK: nginx is running` | `0` |
| `linux-lab-missing.service` | `ERROR: linux-lab-missing.service is not active` | `1` |

Each run used `bash ~/linux-lab/scripts/health-check.sh`, followed by `echo $?`. A separate `echo $?` after `nano` returned `0` for the editor; it was not evidence of a script exit code.

The final `cat` output confirmed both explicit exit instructions and `service='nginx'` restored in the Ubuntu file. The repository script was synchronized with that verified source.

That version reported service-check failure to its caller with code `1`. The missing-unit test verified that failure path without establishing a Nginx outage. It checked one service and exited immediately after its result. The later disk-check integration moved termination to the end so both checks could run and contribute to the overall result.

## Root Filesystem Baseline for the Disk Check

On 2026-10-04, the lab owner ran `df -P /` on Ubuntu and supplied:

```text
Filesystem                        1024-blocks    Used Available Capacity Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv    18889392 8575168   9329344      48% /
```

The `Capacity` column reports root filesystem usage of **48%**. This describes the filesystem mounted at `/`, not the entire virtual disk. The lab disk threshold is **80%**, treating values at or above the threshold as a failed check. The observed sample is below that threshold.

### Numeric Percentage Extraction

The lab owner then ran:

```bash
df -P / | awk 'NR == 2 {gsub(/%/, "", $5); print $5}'
```

Observed output:

```text
48
```

The pipeline selected the second row, removed `%` from the fifth field, and printed the numeric usage value. This verifies extraction for the supplied root filesystem output.

### Variable Assignment and Threshold Comparison

On 2026-10-04, the lab owner captured the percentage with command substitution:

```bash
disk_usage=$(df -P / | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')
disk_limit=80
echo "$disk_usage"
```

The output was `48`. The following comparison was then run in the terminal, first with `disk_limit=80` and again with `disk_limit=40`:

```bash
if [ "$disk_usage" -ge "$disk_limit" ]; then
    echo "ERROR: root filesystem usage is $disk_usage%"
else
    echo "OK: root filesystem usage is $disk_usage%"
fi
```

| Observed usage | Threshold | Observed output |
| --- | --- | --- |
| `48` | `80` | `OK: root filesystem usage is 48%` |
| `48` | `40` | `ERROR: root filesystem usage is 48%` |

The `-ge` operator tests whether usage is greater than or equal to the threshold. Lowering the threshold to `40` exercised the error branch without filling the filesystem; `80` was selected as the script default. Both branches were first verified as standalone terminal commands before the integration below.

## Combined Service and Disk Check

On 2026-10-04, the lab owner supplied three runs of the combined script and its final source. It initializes `exit_code=0`, sets it to `1` when either check fails, and executes a single `exit "$exit_code"` after both checks. Successful checks leave the accumulated result unchanged.

Each run used `bash ~/linux-lab/scripts/health-check.sh`; `echo $?` was executed immediately after the script to read its exit code.

| Test case | Service message | Disk message | Exit code |
| --- | --- | --- | --- |
| Active Nginx, normal disk threshold | `OK: nginx is running` | `OK: root filesystem usage is 48%` | `0` |
| Deliberately nonexistent unit, normal disk threshold | `ERROR: linux-lab-missing.service is not active` | `OK: root filesystem usage is 48%` | `1` |
| Active Nginx, temporarily lowered disk threshold | `OK: nginx is running` | `ERROR: root filesystem usage is 48%` | `1` |

All three runs printed both messages. The missing-unit case confirms that the disk check still runs after a service failure and that its success does not overwrite the failure exit code. The disk-failure case verifies that a later failure also sets the overall result to `1`.

The final `cat health-check.sh` output confirmed that `service='nginx'` and `disk_limit=80` had been restored, with a single exit at the end. The repository script was synchronized with that source. These tests used a missing unit and a lower threshold; they did not require stopping Nginx or filling the filesystem.

### Disk-Input Validation

The first combined version assumed that extraction returned an integer. An empty or nonnumeric result would make `[` report an error and select the `else` branch, producing an incorrect disk `OK` message. The validation developed below now rejects those inputs and sets the overall failure flag before any threshold comparison.

### Standalone Numeric Validation Exercise

On 2026-10-04, the lab owner tested `[[ "$disk_usage" =~ ^[0-9]+$ ]]` in the Ubuntu terminal. The first attempt selected the correct message for all three inputs but placed `exit_code=1` in the numeric-success branch. The lab owner then moved the assignment into the invalid-input branch and repeated the tests, initializing `exit_code=0` before each isolated run.

The corrected conditional was:

```bash
if [[ "$disk_usage" =~ ^[0-9]+$ ]]; then
    echo "OK: disk usage is numeric"
else
    echo "ERROR: invalid disk usage"
    exit_code=1
fi
echo "exit_code=$exit_code"
```

| Assigned value | Observed message | Observed flag output |
| --- | --- | --- |
| `48` | `OK: disk usage is numeric` | `exit_code=0` |
| Empty string | `ERROR: invalid disk usage` | `exit_code=1` |
| `abc` | `ERROR: invalid disk usage` | `exit_code=1` |

These runs verify classification and the stored failure flag. They printed the variable's value, not a script process exit code. In the combined script, initialization must remain at the start so disk validation preserves any earlier service failure. The integration exercise called for running the threshold comparison only inside the numeric-input branch and marking invalid input as a failed check.

### Saved-Script Validation Tests

On 2026-10-04, the lab owner supplied four subsequent executions of `bash ~/linux-lab/scripts/health-check.sh`, reading each process exit code immediately afterward with `echo $?`:

| Run | Service message | Disk message | Exit code |
| --- | --- | --- | --- |
| Normal input | `OK: nginx is running` | `OK: root filesystem usage is 48%` | `0` |
| First invalid-input test | `OK: nginx is running` | `ERROR: invalid disk usage` | `1` |
| Second invalid-input test | `OK: nginx is running` | `ERROR: invalid disk usage` | `1` |
| Deliberately nonexistent unit | `ERROR: linux-lab-missing.service is not active` | `OK: root filesystem usage is 48%` | `1` |

The two requested invalid inputs were an empty string and `abc`; the transcript showed the script results but not the intervening edits. Both invalid-input runs returned failure without printing a disk `OK` message. The missing-unit run confirmed that a successful disk check preserved the service failure.

After these tests, the lab owner supplied the final `cat ~/linux-lab/scripts/health-check.sh` output. It confirmed restoration of `service='nginx'`, the `df` and `awk` pipeline, and `disk_limit=80`. Source review confirmed that the threshold comparison is nested inside the numeric-input branch, invalid input sets `exit_code=1`, initialization occurs once at the start, and a single `exit "$exit_code"` remains at the end. The repository script was synchronized with this logic, using consistent indentation.

## Memory Baseline

On 2026-10-04, the lab owner ran `LC_ALL=C free -m` on Ubuntu and supplied:

```text
               total        used        free      shared  buff/cache   available
Mem:            3379        1137        1744          12         727        2242
Swap:           3780           0        3780
```

The `Mem:` row reports **3379 MiB total** and **2242 MiB available**. The memory check uses `(total - available) / total * 100`, which gives approximately **33.65%** for this sample. Using available memory accounts for memory that can be reclaimed for applications, rather than treating all cache as unavailable. The separate swap row reports **0 MiB used**.

### Percentage Extraction

The lab owner then ran:

```bash
LC_ALL=C free -m | awk '$1 == "Mem:" {print int(($2 - $7) / $2 * 100)}'
```

Observed output:

```text
33
```

The condition selects the `Mem:` row by its first field. Fields `$2` and `$7` provide total and available memory; `int()` discards the fractional part of the calculated percentage. The observed integer result is consistent with the earlier sample. Variable assignment, validation, threshold comparison, and integration into the saved script were subsequently verified below.

### Memory Check Integration and Verification

The lab owner added the memory check after the disk check and before the final exit. It captures the percentage in `memory_usage`, validates it with `^[0-9]+$`, and compares it with `memory_limit` using `-ge`. Invalid input or usage at or above the threshold sets `exit_code=1`; a successful check preserves the existing result.

Supplied Ubuntu runs of `bash ~/linux-lab/scripts/health-check.sh`, each followed immediately by `echo $?`, confirmed:

| Test case | Service result | Disk result | Memory result | Exit code |
| --- | --- | --- | --- | --- |
| Normal settings | Nginx OK | 49%, OK | 34%, OK | `0` |
| Lowered memory threshold | Nginx OK | 49%, OK | 34%, ERROR | `1` |
| Invalid memory input after correction | Nginx OK | 49%, OK | `ERROR: invalid memory usage` | `1` |
| Deliberately nonexistent unit | ERROR | 49%, OK | 34%, OK | `1` |
| Normal settings restored | Nginx OK | 49%, OK | 34%, OK | `0` |

An intermediate run also printed `line 31: [: : integer expected`, followed by `OK: memory usage is 34%`. No exit code or source for that intermediate version was supplied. The diagnostic indicates that a numeric comparison received an invalid argument; the transcript does not establish which operand was incorrect. The later invalid-input run correctly printed an error and returned `1`.

The final supplied source confirmed `service='nginx'`, actual measurements from `df` and `free`, and both `disk_limit=80` and `memory_limit=80`. The memory comparison is nested inside its numeric-input guard, with initialization only at the start and one exit at the end. The repository already contained the memory logic with the temporary threshold `30`; that threshold was restored to `80` to match the verified final Ubuntu source.

## IPv4 Reachability Baseline

The lab owner ran the following commands on Ubuntu:

```bash
ping -n -c 1 -W 2 1.1.1.1
echo $?
```

The supplied output showed one packet transmitted, one reply received, **0% packet loss**, a round-trip time of **17.203 ms**, and exit code **`0`**. This verifies ICMP reachability of `1.1.1.1` at the time of the test.

The options request numeric output without name lookups (`-n`), one echo request (`-c 1`), and a two-second response timeout (`-W 2`). Saved-script integration is documented below.

### Saved-Script ICMP Success

The lab owner added `ping_target='1.1.1.1'` and an `if ping ...` block after the memory check, before the final exit. The condition redirects standard output and standard error to `/dev/null`; it uses the command's exit status to select its branch. A failed ICMP check sets `exit_code=1`, and a successful check prints its message without resetting the accumulated result. Repository inspection confirmed this block, including its closing `fi`.

The supplied Ubuntu run of `bash ~/linux-lab/scripts/health-check.sh`, followed immediately by `echo $?`, produced:

```text
OK: nginx is running
OK: root filesystem usage is 49%
OK: memory usage is 33%
OK: 1.1.1.1 responds to ICMP
0
```

This verifies the ICMP success branch as part of the four-check script. The following runs verified failure handling and restoration of normal settings.

### ICMP Failure, Overall Status, and Recovery

The lab owner repeated the script with a temporary ICMP target and a missing unit, then restored the normal settings. Each run's exit code was read immediately afterward with `echo $?`.

| Service setting | ICMP target | Observed results | Exit code |
| --- | --- | --- | --- |
| `nginx` | `192.0.2.1` | Service, disk (49%), and memory (33%) OK; `ERROR: ICMP check failed for 192.0.2.1` | `1` |
| `linux-lab-missing.service` | `1.1.1.1` | Service ERROR; disk (49%), memory (33%), and ICMP OK | `1` |
| `nginx` | `1.1.1.1` | Service, disk (49%), memory (34%), and ICMP all OK | `0` |

The failed ICMP check set the overall failure status. The missing-unit run confirmed that the subsequent successful disk, memory, and ICMP checks did not clear that status. The last run confirmed recovery with normal settings. Changing the ICMP target exercised the script's failure branch; it did not establish a general network outage or a DNS failure.

The final `cat ~/linux-lab/scripts/health-check.sh` output confirmed `service='nginx'`, both resource thresholds at `80`, actual measurements from `df` and `free`, and `ping_target='1.1.1.1'`. All four checks precede the single final `exit "$exit_code"`. Repository inspection confirmed matching logic with consistent indentation.

## Planned Next Steps

- Add a timestamp and overall result to each run, then verify appending output to a log file.
- Add cron scheduling and verify an actual scheduled run.
