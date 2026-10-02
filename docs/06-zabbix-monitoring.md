# Zabbix Monitoring Verification

**Status:** Authenticated frontend access and opening the dashboard are confirmed, and the lab owner reports changing the default password. The frontend reported a running Zabbix server at `localhost:10051` and matching server/frontend versions `7.0.31`. The enabled `Zabbix server` entry monitors `linux01` through `127.0.0.1:10050`; uptime, CPU, memory, root filesystem, and network traffic metrics have been verified. Monitoring of the unidentified `matt` entry at `192.168.0.28:10050` has been disabled while retaining its configuration. Its original target and the cause of its earlier timeout remain unknown. The agent-availability and custom HTTP trigger exercises are complete. Starting Nginx restored Windows HTTP access, both Nginx and Zabbix Server were active afterward, and the custom HTTP event was resolved with a displayed duration of `11m 30s`.

## Existing Deployment

Zabbix was already installed before this lab's verification work. The [server baseline](01-server-setup.md) records the installed packages and earlier service checks. The frontend is accessed from Windows at `http://127.0.0.1:8080/` through VirtualBox NAT to guest TCP port `80` on `linux01`.

The [firewall exercise](04-networking-and-firewall.md) verified restoration of the login page after a temporary HTTP block was removed.

## Authenticated Frontend Access

On 2026-09-30, the lab owner confirmed successful login and opening the Zabbix dashboard.

| Check | Confirmed result |
| --- | --- |
| Frontend login | Successful, as reported by the lab owner |
| Dashboard after login | Opened successfully |
| Account password status | Lab owner subsequently confirmed changing the default password |

The password change is recorded from the lab owner's confirmation. An authenticated host-list screenshot was supplied with that confirmation. No credentials are recorded here.

## System Information

Before disabling monitoring of `matt`, the lab owner supplied a screenshot of the system information table with these values:

| Parameter | Observed value | Details shown |
| --- | --- | --- |
| Zabbix server is running | `Yes` | `localhost:10051` |
| Zabbix server version | `7.0.31` | `Up to date` |
| Zabbix frontend version | `7.0.31` | `Up to date` |
| Software update last checked | `2026-09-30` | |
| Latest release | `7.0.31` | Release notes link |
| Number of hosts (enabled/disabled) | `2` | `2 / 0` |

These are values reported by the frontend at the time of the screenshot. The server and frontend versions match each other and the earlier package baseline. The update labels are recorded as displayed, rather than used as an independent check of the latest available release.

The report confirms that the frontend sees the Zabbix server as running. An enabled host is configured for monitoring; this count alone does not establish successful collection or the number of distinct physical or virtual machines. The subsequent host-list inspection is recorded below.

The fields are described in the [Zabbix 7.0 system information reference](https://www.zabbix.com/documentation/7.0/en/manual/web_interface/frontend_sections/reports/status_of_zabbix).

## Existing Host Configuration and Availability

The screenshot from **Data collection → Hosts** showed:

| Host name shown | Interface | Linked templates | Status | Agent availability |
| --- | --- | --- | --- | --- |
| `matt` | `192.168.0.28:10050` | `Linux by Zabbix agent` | `Enabled` | Red `ZBX`; tooltip reports `Not available` |
| `Zabbix server` | `127.0.0.1:10050` | `Linux by Zabbix agent`, `Zabbix server health` | `Enabled` | Green `ZBX` |

The Agent encryption column showed `None` for both entries. In this deployment, the loopback interface on `Zabbix server` refers to the Ubuntu system running the Zabbix server process. The green indicator is evidence of agent availability reported by Zabbix. A subsequent inspection of individual values is recorded below.

The host-list fields and availability tooltips are described in the [Zabbix 7.0 host list reference](https://www.zabbix.com/documentation/7.0/en/manual/web_interface/frontend_sections/data_collection/hosts).

### Unavailable Agent on `matt`

The lab owner supplied the red availability icon's tooltip. It identified interface `192.168.0.28:10050`, status `Not available`, and this error:

```text
Get value from agent failed: cannot establish TCP connection to [[192.168.0.28]:10050]: timed out
```

This establishes a TCP connection timeout to that configured endpoint. It does not by itself identify whether the address is obsolete, the target is offline, or traffic is being filtered.

The last verified address of the Ubuntu VM was `10.0.2.15` on its NAT interface. Address `192.168.0.28` appeared in the earlier Windows SSH history, but that does not prove which machine the `matt` entry was intended to monitor. When asked, the lab owner did not remember whether it referred to this Ubuntu VM or another device.

A stale interface address is therefore a hypothesis, not a confirmed cause. At this stage, no host entry had been changed, disabled, or deleted. The subsequent checks below compare the current Ubuntu configuration with the available values collected under `Zabbix server`; the later decision to disable monitoring of `matt` is recorded separately.

## Current Ubuntu Identity and First Fresh Metric

The lab owner ran these commands on Ubuntu:

```bash
hostname
ip -br addr
```

The output confirmed:

| Check | Observed result |
| --- | --- |
| Hostname | `linux01` |
| Loopback addresses | `127.0.0.1/8`, `::1/128` |
| Network interface | `enp0s3`, state `UP` |
| Interface IPv4 address | `10.0.2.15/24`, metric `100` |
| Interface IPv6 addresses | `fd17:625c:f037:2:a00:27ff:fe64:3697/64`, `fe80::a00:27ff:fe64:3697/64` |

The configured `matt` endpoint address, `192.168.0.28`, was not present in this interface listing. This confirms the address mismatch with the current Ubuntu VM; it does not establish the original purpose of that host entry.

In **Monitoring → Latest data**, the screenshot showed these rows for `Zabbix server`:

| Item | Last check shown | Last value shown | Change shown |
| --- | --- | --- | --- |
| `System name` | Blank | Blank | Blank |
| `System uptime` | `3s` | `00:15:54` | `+00:00:30` |

The uptime row provides direct evidence of recent data collection: its last-check age was three seconds at capture, and the displayed value was 15 minutes and 54 seconds, increasing by 30 seconds from the previous value. This confirms collection of this metric; other metrics and alert behavior still need verification.

No value or last-check age was visible for `System name` in that first screenshot. At that point, the Ubuntu command confirmed the OS hostname, but the corresponding Zabbix value had not been verified. An immediate check using **Execute now** was suggested.

### Follow-up: System Name Visible and Uptime Still Updating

The lab owner then supplied another **Latest data** screenshot for the same host:

| Item | Last check shown | Last value shown | Change shown |
| --- | --- | --- | --- |
| `System name` | `2m 45s` | `linux01` | Blank |
| `System uptime` | `6s` | `00:22:24` | `+00:00:30` |

The system-name value now matches the `hostname` output from Ubuntu. Together with the loopback agent interface, this identifies the `Zabbix server` entry as monitoring the `linux01` VM. `Zabbix server` is the name shown for the monitoring entry; the reported OS hostname is `linux01`.

The second fresh uptime value confirms continued collection beyond the initial sample. The screenshot establishes that the previously blank system-name value became visible, but it does not establish why it was blank initially or provide a separate result for the **Execute now** action. No item configuration change is recorded.

## CPU, Memory, and Root Filesystem Metrics

On 2026-09-30, the lab owner supplied the following **Monitoring → Latest data** values for `Zabbix server`:

| Item | Last check shown | Last value shown | Change shown |
| --- | --- | --- | --- |
| `CPU utilization` | `22s` | `1.2664 %` | `+0.04971 %` |
| `Memory utilization` | `56s` | `36.4083 %` | `+0.08194 %` |
| `FS [/]: Space: Used, in %` | `46s` | `47.8492 %` | `+0.0002011 %` |

Each value had been checked less than a minute before its respective capture. These samples confirm collection of the three resource metrics; they do not establish resource usage over a longer period or verify trigger behavior.

The root filesystem screenshot also showed these values, all with a last-check age of `46s`:

| Item | Last value shown | Change shown |
| --- | --- | --- |
| `FS [/]: Space: Available` | `8.9 GB` | `-36 KB` |
| `FS [/]: Space: Total` | `18.01 GB` | Blank |
| `FS [/]: Space: Used` | `8.17 GB` | `+36 KB` |
| `FS [/]: Inodes: Free, in %` | `87.0219 %` | Blank |
| `FS [/]: Option: Read-only` | `0` | Blank |

The screenshot identified filesystem `/` and type `ext4`. Sizes and units are recorded as displayed by Zabbix. These values describe the root filesystem, not the full 40 GB virtual disk; the [server baseline](01-server-setup.md) records the smaller root logical volume and free space remaining in the volume group.

The latest-data view and its history links are described in the [Zabbix 7.0 latest data reference](https://www.zabbix.com/documentation/7.0/en/manual/web_interface/frontend_sections/monitoring/latest_data).

## Historical Identity Check for `matt`

The lab owner filtered **Monitoring → Latest data** to host `matt` and item name `System name`. The screenshot showed one matching item, with blank **Last check**, **Last value**, and **Change** fields. A **History** link was visible for that item.

This confirms that the item exists but no latest value was displayed. It does not establish that the item never collected data: the latest-data view has a display-age limit.

History was inspected in **View as: Values**. The supplied screenshots showed:

| Applied range | From | To | Result |
| --- | --- | --- | --- |
| Last 15 minutes | `now-15m` | `now` | `No data found` |
| Last 30 days | `now-30d` | `now` | `No data found` |

The second screenshot confirmed that the 30-day range had been applied. No system-name records were displayed for that period, so this history check did not identify the original target of `matt`. It does not prove that the host never collected data or establish the cause of its TCP timeout.

## Monitoring of the Unidentified Host Disabled

On 2026-09-30, the lab owner supplied a host-list screenshot confirming:

| Host | Interface | Status | Availability shown |
| --- | --- | --- | --- |
| `matt` | `192.168.0.28:10050` | `Disabled` | Red `ZBX` still visible |
| `Zabbix server` | `127.0.0.1:10050` | `Enabled` | Green `ZBX` |

The `matt` entry and its linked `Linux by Zabbix agent` template remain present. Monitoring of that entry was disabled temporarily so that further exercises can focus on the confirmed `linux01` target. The entry's original purpose and the cause of its timeout remain unresolved; this is a monitoring scope change, not a repaired connectivity incident.

The screenshot confirms the status change. Interface availability can update later, after Zabbix server synchronizes configuration changes, as described in the [host-list reference](https://www.zabbix.com/documentation/7.0/en/manual/web_interface/frontend_sections/data_collection/hosts). A subsequent availability icon change has not been verified.

## Agent-Availability Trigger Inspection

On 2026-10-02, the lab owner supplied a trigger-list screenshot for `Zabbix server` with the following settings:

| Field | Observed value |
| --- | --- |
| Trigger | `Linux: Zabbix agent is not available` |
| Inherited from | `Linux by Zabbix agent` |
| Severity | `Average` |
| Value | `OK` |
| Status | `Enabled` |
| Tag | `scope: availability` |

The displayed expression was:

```text
max(/Zabbix server/zabbix[host,agent,available],{$AGENT.TIMEOUT})=0
```

The expression checks the maximum recorded agent-availability value within the period specified by `{$AGENT.TIMEOUT}`. Availability value `0` means unavailable, so the condition is true when all recorded values in that window are `0`. See the [internal item reference](https://www.zabbix.com/documentation/7.0/en/manual/config/items/itemtypes/internal) and [aggregate function reference](https://www.zabbix.com/documentation/7.0/en/manual/appendix/functions/aggregate).

The trigger-list screenshot confirmed that the trigger was enabled and reported `OK` before the outage exercise. The effective macro value and subsequent event were inspected separately, as recorded below. No trigger configuration change is recorded.

### Effective Agent Timeout

The lab owner then supplied a screenshot from the host's **Macros → Inherited and host macros** view:

| Field | Observed value |
| --- | --- |
| Macro | `{$AGENT.TIMEOUT}` |
| Effective value | `3m` |
| Template value | `Linux by Zabbix agent: "3m"` |

This confirms a three-minute evaluation window for the availability trigger. The macro was read without a reported edit. The view shows resolved values and their source, as described in the [host configuration reference](https://www.zabbix.com/documentation/7.0/en/manual/config/hosts/host).

Three minutes is the period evaluated by `max()`, not a guarantee that an event appears exactly three minutes after the service stops. Interface failure detection and polling introduce additional delays; see the [interface availability reference](https://www.zabbix.com/documentation/7.0/en/manual/appendix/items/unreachability). Event and service times are recorded below, with the timezone assumption needed to compare them.

## Agent-Availability Exercise: Detection and Recovery

After the test instructions were provided on 2026-10-02, the lab owner supplied a **Monitoring → Problems** screenshot showing:

| Field | Observed value |
| --- | --- |
| Host | `Zabbix server` |
| Problem | `Linux: Zabbix agent is not available (for 3m)` |
| Severity | `Average` |
| Event time shown | `06:31:26 AM` |
| Duration at capture | `11s` |
| Recovery time | Blank |

This confirms that Zabbix generated the expected agent-unavailable problem. The displayed duration is the age of the problem event at capture, not the elapsed time from stopping the service. At this stage, the exact service stop time was not yet known; the subsequent journal inspection established it.

The screenshot also contained a separate warning, `Linux: Zabbix server has been restarted (uptime < 10m)`, with event time `06:18:30 AM`, recovery time `06:28:00 AM`, and status `RESOLVED`. That resolved row does not establish recovery of the later agent-unavailable event.

The lab owner then ran these commands on Ubuntu:

```bash
sudo systemctl start zabbix-agent2
date -Is
systemctl is-active zabbix-agent2 zabbix-server
```

The output was:

```text
2026-10-02T04:31:56+00:00
active
active
```

Both services were active after the start command. The shell timestamp includes a UTC offset; the screenshot's event times are preserved as displayed, without assuming its timezone. Event recovery and resumed data collection were checked separately, as recorded below.

### Resolved Event and Fresh Uptime

The next **Monitoring → Problems** screenshot showed the same agent-unavailable event for `Zabbix server`:

| Field | Observed value |
| --- | --- |
| Event time | `06:31:26 AM` |
| Recovery time | `06:33:26 AM` |
| Status | `RESOLVED` |
| Severity | `Average` |
| Duration | `2m` |

The event was resolved after the service was started. No manual event closure was reported. The two-minute duration measures the period from problem creation to resolution in Zabbix; it does not measure the entire service outage or the delay before detection.

A subsequent **Monitoring → Latest data** screenshot confirmed a fresh agent metric:

| Host | Item | Last check | Last value | Change |
| --- | --- | --- | --- | --- |
| `Zabbix server` | `System uptime` | `30s` | `00:17:03` | `+00:00:30` |

This verifies resumed uptime collection after the start command. Together with the resolved event and active service checks, it confirms the functional detection/recovery test. The following journal inspection completed the incident evidence.

### Service Journal and Incident Timeline

The lab owner ran:

```bash
sudo journalctl -u zabbix-agent2 --since "2026-10-02 04:15:00 UTC" --until "2026-10-02 04:40:00 UTC" --utc --no-pager
```

The unit filter selects Agent 2, the time filters limit the output to the exercise, `--utc` displays UTC timestamps, and `--no-pager` prints directly to the terminal. Relevant supplied lines were:

```text
Oct 02 04:18:05 linux01 systemd[1]: Started zabbix-agent2.service - Zabbix Agent 2.
Oct 02 04:28:00 linux01 systemd[1]: Stopping zabbix-agent2.service - Zabbix Agent 2...
Oct 02 04:28:00 linux01 zabbix_agent2[1431]: Zabbix Agent 2 stopped. (7.0.31)
Oct 02 04:28:00 linux01 systemd[1]: zabbix-agent2.service: Deactivated successfully.
Oct 02 04:28:00 linux01 systemd[1]: Stopped zabbix-agent2.service - Zabbix Agent 2.
Oct 02 04:31:55 linux01 systemd[1]: Starting zabbix-agent2.service - Zabbix Agent 2...
Oct 02 04:31:56 linux01 zabbix_agent2[2458]: Validation successful
Oct 02 04:31:56 linux01 systemd[1]: Started zabbix-agent2.service - Zabbix Agent 2.
```

The output also identified Agent 2 version `7.0.31` and configured agent hostname `Zabbix server` after both starts. This agent identity remains distinct from the OS hostname `linux01`.

| Event on 2026-10-02 | Time | Evidence |
| --- | --- | --- |
| Earlier Agent 2 start | `04:18:05 UTC` | Service journal |
| Agent 2 stopped | `04:28:00 UTC` | Service journal |
| Agent-unavailable problem created | `06:31:26 AM` (UI time) | Zabbix event |
| Agent 2 started | `04:31:56 UTC` | Service journal and active service check |
| Agent-unavailable problem resolved | `06:33:26 AM` (UI time) | Zabbix event |

The journal establishes a service interruption of **3 minutes 56 seconds**. The event lasted **2 minutes**, measured entirely using Zabbix's displayed timestamps. If the frontend uses UTC+02:00, the event times correspond to `04:31:26 UTC` and `04:33:26 UTC`: detection then took **3 minutes 26 seconds** after the stop, and recovery was recorded **1 minute 30 seconds** after the service started. Those two cross-clock intervals are conditional on the frontend timezone; its setting was not separately inspected.

The cause of the exercise's agent unavailability was the stopped Agent 2 service, confirmed by the journal. Starting the service restored it; both services were then active, the event became `RESOLVED`, and fresh uptime data returned. This completes the third controlled failure record, alongside the permissions and HTTP firewall exercises.

## Network Traffic Metrics

On 2026-10-02, the lab owner supplied a **Monitoring → Latest data** screenshot for `Zabbix server`, filtered to `enp0s3`:

| Item | Last check shown | Last value shown | Change shown |
| --- | --- | --- | --- |
| `Interface enp0s3: Bits received` | `30s` | `2.18 Kbps` | `-592 bps` |
| `Interface enp0s3: Bits sent` | `27s` | `2.68 Kbps` | `-872 bps` |

Both rows had tags `component: network` and `interface: enp0s3`. These fresh values confirm collection of incoming and outgoing traffic rates on the VM's NAT interface. The displayed units are bits per second, with `Kbps` denoting kilobits per second; the negative changes indicate lower rates than the preceding values, not negative traffic. These are traffic samples, not a measurement of the interface's maximum capacity.

The network items and their rate preprocessing are documented in the official [Linux by Zabbix agent template](https://raw.githubusercontent.com/zabbix/zabbix/release/7.0/templates/os/linux/README.md).

## HTTP Web Scenario Baseline

On 2026-10-02, after following the web scenario setup instructions, the lab owner supplied the **Details of web scenario: Linux lab HTTP** view:

| Field | Observed value |
| --- | --- |
| Scenario | `Linux lab HTTP` |
| Step | `Homepage` |
| Response code | `200` |
| Step status | `OK` |
| Total status | `OK` |
| Response time | `0.36 ms` |
| Download speed | `503.33 KBps` |

The result confirms successful scenario execution and collected response-time and download-speed samples. `KBps` represents kilobytes per second, unlike the network items' `Kbps` (kilobits per second). These samples do not measure the Internet connection's capacity. See the [web monitoring item reference](https://www.zabbix.com/documentation/7.0/en/manual/web_monitoring/items).

The setup instructions specified a request from Zabbix Server on Ubuntu to `http://127.0.0.1/`, with header `Host: lab.test`, required text `Linux Administration Lab`, and required status `200`. This follows the existing [Nginx routing](05-nginx.md). The supplied result view does not show those configuration fields. The intended check covers the local HTTP endpoint; access through Windows NAT forwarding is tested separately.

This establishes the successful baseline. The custom trigger and its subsequent problem and recovery event are verified below. Windows HTTP failure, service diagnosis, and restored HTTP access are documented in the Nginx outage exercise.

## Custom HTTP Trigger

On 2026-10-02, the lab owner supplied a trigger-list screenshot after creating the custom trigger for the scenario:

| Field | Observed value |
| --- | --- |
| Name | `Nginx: Linux lab HTTP check failed` |
| Severity | `Average` |
| Value | `OK` |
| Status | `Enabled` |

The displayed expression was:

```text
last(/Zabbix server/web.test.fail[Linux lab HTTP])>0
```

`web.test.fail` returns the failed step number, or `0` when all steps succeed. `last()` selects the latest value, so the expression detects a failed scenario step. With the single `Homepage` step, a failure returns `1`. See the [web monitoring item and trigger examples](https://www.zabbix.com/documentation/7.0/en/manual/web_monitoring/items).

The screenshot confirms that the custom trigger exists, is enabled, and reports `OK` before the outage exercise. The trigger list does not show the configured recovery mode.

During the controlled outage, Windows curl returned exit code `56`, and Nginx status and journal output confirmed an orderly stop at `2026-10-02 20:30:03 UTC`. The [Nginx outage exercise](05-nginx.md#controlled-nginx-outage) records the diagnosis, repair, and Windows HTTP recovery.

## HTTP Trigger: Problem and Recovery

After running `sudo systemctl start nginx`, the lab owner supplied a shell timestamp of `2026-10-02T20:41:35+00:00`. The following `systemctl is-active nginx zabbix-server` check returned `active` for both services. Windows curl then returned the lab HTML, HTTP `200`, and exit code `0`.

The supplied event-history screenshot confirmed:

| Field | Observed value |
| --- | --- |
| Host | `Zabbix server` |
| Problem | `Nginx: Linux lab HTTP check failed` |
| Severity | `Average` |
| Event time | `10:30:31 PM` (UI time) |
| Recovery time | `10:42:01 PM` (UI time) |
| Status | `RESOLVED` |
| Duration | `11m 30s` |

The event confirms that the custom HTTP trigger detected a failed scenario and subsequently recovered after service restoration. No manual event closure was reported. The screenshot also showed a separate, already resolved Zabbix-server uptime warning; that row is not the HTTP incident.

| Event on 2026-10-02 | Time | Evidence |
| --- | --- | --- |
| Nginx stopped | `20:30:03 UTC` | Service status and journal |
| HTTP problem created | `10:30:31 PM` (UI time) | Zabbix event history |
| Post-start shell timestamp | `20:41:35 UTC` | `date -Is` after `systemctl start nginx` |
| HTTP problem resolved | `10:42:01 PM` (UI time) | Zabbix event history |

The event lasted **11 minutes 30 seconds**, using the UI's timestamps. The service stop and post-start shell observation are **11 minutes 32 seconds** apart; the latter was printed after the start command completed, so this interval is not an exact measurement of service downtime. The UI times are consistent with UTC+02:00, but the frontend timezone setting was not inspected. The table therefore preserves the separate clock labels rather than assuming an offset for detection or recovery-delay calculations.

Service activity, Windows HTTP recovery, and the resolved custom trigger complete the Nginx monitoring exercise. The results demonstrate local HTTP failure detection by Zabbix Server and recovery of access through Windows NAT forwarding.

## Next Steps

- Build the Bash health check incrementally, then verify scheduled execution with cron.
- Complete the planned DNS/connectivity troubleshooting exercise.
- Revisit the retained `matt` configuration if its intended target is identified.

Both monitoring outage exercises are complete: Agent 2 recovery restored metric collection, and Nginx recovery restored HTTP access. The corresponding availability and custom HTTP problem events were resolved.
