# Bash Health Check and Cron

**Status:** Four checks, aggregated exit codes, timestamped logging, and scheduled execution are verified on Ubuntu. The script was developed incrementally and tested with successful and failing inputs on 2026-10-04.

Source: [scripts/health-check.sh](../scripts/health-check.sh).

## Checks and Defaults

| Check | Implementation | Failure condition |
| --- | --- | --- |
| Nginx activity | `systemctl is-active --quiet "$service"` | The command returns a nonzero status |
| Root filesystem usage | Fifth field from the second row of `df -P /`, with `%` removed | Invalid numeric result or usage ≥ 80% |
| Memory usage | Integer `(total - available) / total * 100` from `LC_ALL=C free -m` | Invalid numeric result or usage ≥ 80% |
| Numeric IPv4 reachability | `ping -n -c 1 -W 2 1.1.1.1` | The command returns a nonzero status |

The defaults are `service='nginx'`, `disk_limit=80`, `memory_limit=80`, and `ping_target='1.1.1.1'`.

The disk check measures the filesystem mounted at `/`, not the whole virtual disk. The memory calculation uses available memory, allowing for reclaimable memory, and truncates its fractional part with `int()`. An initial sample had 3379 MiB total and 2242 MiB available, producing `33`.

The ping options request numeric output (`-n`), one request (`-c 1`), and a two-second response timeout (`-W 2`). Its output is suppressed; the script reports success or failure using the command's exit status.

## Exit Codes and Input Validation

The script initializes `exit_code=0` once, sets it to `1` whenever a check fails, and exits once after all four checks. Successful checks never clear an earlier failure.

An early version printed a service error but returned `0`, because its last command was a successful `echo`. Explicit exit codes corrected that behavior. Combining multiple checks then required replacing per-check exits with the final aggregated result. See the [Bash exit-status reference](https://www.gnu.org/s/bash/manual/html_node/Exit-Status.html).

Disk and memory results must match `^[0-9]+$` before the numeric comparison. Empty or nonnumeric values produce an error rather than entering the normal-usage branch. An intermediate memory test emitted `integer expected`; the final guarded comparison and restored numeric threshold were verified afterward.

## Running on Ubuntu

The tested VM location is `/home/matt/linux-lab/scripts/health-check.sh`. From the `matt` session:

```bash
bash ~/linux-lab/scripts/health-check.sh
echo $?
```

Read `$?` immediately after the script: running an editor or another command first replaces that status. The repository uses LF line endings for `*.sh` through [.gitattributes](../.gitattributes). Execution was verified through Bash; direct execution with `./health-check.sh` was not part of the tests.

## Verified Test Matrix

Tests used temporary source edits during development, followed by restoration of the defaults. They did not require filling the disk or exhausting RAM.

| Test case | Observed result | Script exit code |
| --- | --- | --- |
| Normal settings | All checks OK; disk 49%, memory 33–34%, ICMP reply | `0` |
| Missing unit `linux-lab-missing.service` | Service ERROR; remaining checks still ran and succeeded | `1` |
| Disk threshold lowered to 40 with usage at 48% | Disk ERROR | `1` |
| Invalid disk measurement | `ERROR: invalid disk usage`, no disk OK message | `1` |
| Lowered memory threshold with usage at 34% | Memory ERROR | `1` |
| Invalid memory measurement | `ERROR: invalid memory usage` | `1` |
| ICMP target changed to `192.0.2.1` | ICMP ERROR; service, disk, and memory OK | `1` |
| Missing unit with successful ICMP to `1.1.1.1` | Later successful checks preserved the earlier failure | `1` |
| Defaults restored | All checks OK | `0` |

The standalone disk-validation exercise explicitly tested `48`, an empty string, and `abc`. Two subsequent invalid-input script runs returned `1`; the transcript did not include the intervening edits. The final supplied source confirmed actual measurements, numeric guards, both thresholds restored to 80, and a single final exit.

Changing the ICMP target tested a failure branch. It did not demonstrate a general network outage. The separate [DNS exercise](04-networking-and-firewall.md#controlled-dns-failure-and-recovery) showed that numeric IP reachability can succeed while name resolution fails.

## Timestamped Logging

The script prints a timestamp before the checks and `RESULT: exit_code=...` before exiting. The calling shell writes the report to a file:

```bash
mkdir -p ~/linux-lab/logs
bash ~/linux-lab/scripts/health-check.sh >> ~/linux-lab/logs/health-check.log 2>&1
echo $?
tail -n 6 ~/linux-lab/logs/health-check.log
```

`>>` appends standard output; `2>&1` sends standard error to the same destination. The manual invocation returned `0` and produced:

```text
=== 2026-10-04T14:49:03+00:00 health check ===
OK: nginx is running
OK: root filesystem usage is 49%
OK: memory usage is 34%
OK: 1.1.1.1 responds to ICMP
RESULT: exit_code=0
```

## Installed Cron Schedule

Initial checks confirmed `cron` was active, Bash was at `/usr/bin/bash`, and `matt` had no existing user crontab. After setup, `crontab -l` confirmed:

```cron
PATH=/usr/bin:/bin
*/5 * * * * /usr/bin/bash /home/matt/linux-lab/scripts/health-check.sh >> /home/matt/linux-lab/logs/health-check.log 2>&1
```

The schedule runs at minutes 00, 05, 10, through 55 of every hour. It uses absolute paths and runs as the user who owns the crontab, `matt`; a user crontab has no extra username field. See the [crontab format reference](https://manpages.ubuntu.com/manpages/resolute/man5/crontab.5.html).

### Evidence of Automatic Execution

At `2026-10-04T15:00:18+00:00`, the lab owner inspected:

```bash
tail -n 12 ~/linux-lab/logs/health-check.log
sudo journalctl -u cron --since "10 minutes ago" --no-pager
```

The log retained the earlier manual entry and added:

```text
=== 2026-10-04T15:00:01+00:00 health check ===
OK: nginx is running
OK: root filesystem usage is 49%
OK: memory usage is 34%
OK: 1.1.1.1 responds to ICMP
RESULT: exit_code=0
```

The journal included the matching command:

```text
Oct 04 15:00:01 linux01 CRON[4528]: (matt) CMD (/usr/bin/bash /home/matt/linux-lab/scripts/health-check.sh >> /home/matt/linux-lab/logs/health-check.log 2>&1)
```

It also recorded the cron session opening and closing for `matt`. The command, timestamp, and completed log report verify an actual scheduled run and appended output.

## Scope and Limitations

This is a small lab script with fixed settings, not a general monitoring agent. Numeric validation protects the threshold comparisons; it does not fully validate every raw field from `df` or `free`. Nginx's active state does not guarantee an HTTP response, and one successful numeric ping does not validate DNS or all network paths.

Cron invokes the script and the shell appends its output. Log rotation and external notifications are not implemented. Zabbix provides the separate HTTP and agent-availability checks documented in the [monitoring stage](06-zabbix-monitoring.md).
