# Bash Health Check Development

**Status:** The saved single-service script is verified on Ubuntu with explicit exit codes: active Nginx produced the success message and `0`; a deliberately nonexistent unit produced the error message and `1`. The earlier incorrect success status on failure was fixed. The final file inspection confirmed that the unit name was restored to `nginx`. Resource checks and cron execution remain pending.

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

On 2026-10-04, the lab owner supplied the output of `cat health-check.sh` from `~/linux-lab/scripts` on Ubuntu. The initial file included the `#!/usr/bin/env bash` shebang, `service='nginx'`, and the verified conditional. The repository's [scripts/health-check.sh](../scripts/health-check.sh) now includes the explicit exit-code fix documented below.

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

The script now reports service-check failure to its caller with code `1`. The missing-unit test verifies that failure path without establishing a Nginx outage. This implementation checks one service and exits immediately after its result; before adding further checks, termination must move to the end so every check can run and contribute to the overall result.

## Planned Next Steps

- Inspect root filesystem usage and define the disk check's warning threshold.
- Add disk usage, memory, and connectivity checks incrementally, collecting failures and returning one overall exit code after all checks.
- Add logging and cron scheduling, then verify an actual scheduled run.
