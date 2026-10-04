# Linux Administration & Monitoring Lab

A practical home lab for developing Linux administration, monitoring, and troubleshooting skills for junior infrastructure and support roles.

**Status:** Work in progress. Server baseline, users/groups/permissions, SSH, and Nginx configuration checks are complete. Zabbix collects verified uptime, CPU, memory, root filesystem, and network traffic metrics from `linux01`. Four controlled failures are documented with recovery checks: missing group-write permission, a firewall rule blocking HTTP, a stopped Zabbix agent, and stopped Nginx. The Nginx exercise verified a custom HTTP trigger's problem detection and recovery, restored service activity, and HTTP `200` from Windows. The [Bash health check](scripts/health-check.sh) checks service activity and root filesystem usage, rejects empty or nonnumeric disk input, and returns one overall exit code after both checks. Ubuntu tests verified success (`0`) and failure (`1`) for a missing unit, an exceeded disk threshold, and invalid disk input. The final Ubuntu source was reviewed and synchronized into the repository with normal settings restored. Memory and connectivity checks, cron, and a DNS/connectivity exercise remain planned work.

## Current Environment

| Component | Verified state |
| --- | --- |
| Virtualization | Oracle VirtualBox on Windows |
| Operating system | Ubuntu 26.04.1 LTS |
| Hostname | `linux01` (renamed from `ubuntu-server-26`; verified after reboot) |
| Networking | VirtualBox NAT; outbound IPv4 ICMP and DNS resolution verified |
| Firewall | UFW active; default incoming deny and outgoing allow; TCP 22 and 80 allowed for IPv4 and IPv6; temporary HTTP deny rule removed after the controlled blocking test |
| Remote access | SSH from Windows to `127.0.0.1:2222` as `matt`; Ed25519 key login verified with a private-key passphrase prompt; password-only login rejected |
| Zabbix web access | Authenticated access at `http://127.0.0.1:8080/` verified; the lab owner supplied event history after restoring Nginx |
| Static lab site | After the Nginx outage, Windows curl with `Host: lab.test` returned the lab HTML, HTTP `200`, and exit code `0`; DNS resolution for `lab.test` has not been configured as part of this lab |
| Monitoring software | Zabbix Server and Agent 2 packages at version 7.0.31; frontend reports server and frontend versions `7.0.31` and a running server at `localhost:10051`; the latest host list has one enabled and one disabled host |
| Host monitoring status | `Zabbix server` at `127.0.0.1:10050` remains enabled; monitoring of the unidentified `matt` entry at `192.168.0.28:10050` is disabled, with its configuration retained |
| Collected metrics | The `Zabbix server` entry reports system name `linux01` and updating uptime; supplied CPU, memory, and root filesystem usage samples were `1.2664%`, `36.4083%`, and `47.8492%`, each checked less than a minute before its respective capture |
| Network traffic metrics | `enp0s3` received `2.18 Kbps` and sent `2.68 Kbps`, with last-check ages `30s` and `27s` respectively at capture |
| HTTP web scenario baseline | Before the Nginx outage: `Linux lab HTTP`, step `Homepage`, response code `200`, status `OK`, response time `0.36 ms` |
| Custom HTTP trigger | `Nginx: Linux lab HTTP check failed`: severity `Average`; event `RESOLVED`, from `10:30:31 PM` to `10:42:01 PM` in the UI, duration `11m 30s` |
| Nginx outage exercise | Complete: curl failure `56` and a stopped service were diagnosed; starting Nginx restored HTTP `200`, and both `nginx` and `zabbix-server` were active after the start command |
| Agent-availability trigger | Enabled, severity `Average`, effective `{$AGENT.TIMEOUT}` value `3m` inherited from `Linux by Zabbix agent`; the observed problem was resolved at `06:33:26 AM`, two minutes after its displayed start time |
| Agent service after the test | `sudo systemctl start zabbix-agent2` followed by a status check showed both `zabbix-agent2` and `zabbix-server` active at the check associated with `2026-10-02T04:31:56+00:00` |
| Agent outage evidence | Journal confirms the service stopped at `04:28:00 UTC` and started at `04:31:56 UTC` on 2026-10-02: a service interruption of `3m 56s` |
| Collection after recovery | `System uptime` showed `00:17:03`, with last-check age `30s` and change `+00:00:30` |

Nginx, MySQL, Zabbix Server, Zabbix Agent 2, and PHP-FPM were confirmed active after the upgrade and reboot. The lab owner reports changing the default frontend password. The `Zabbix server` entry monitors `linux01` through its loopback agent interface. Both the agent-availability and custom HTTP trigger exercises confirmed problem detection and recovery. Nginx and Zabbix Server were checked again after restoring HTTP access and were active.

## Planned Work

- Extend the Bash script with memory and connectivity checks while preserving its overall exit code, then schedule it with cron.
- Complete the DNS/connectivity troubleshooting exercise (four other controlled failure scenarios are complete).
- Review the completed repository for accuracy, security, and presentation.

## Documentation

- [Server setup and initial verification](docs/01-server-setup.md)
- [Users, groups, and permissions](docs/02-users-and-permissions.md)
- [SSH key setup and verification](docs/03-ssh.md)
- [Networking and firewall verification](docs/04-networking-and-firewall.md)
- [Nginx site configuration](docs/05-nginx.md)
- [Zabbix monitoring verification](docs/06-zabbix-monitoring.md)
- [Bash health check development](docs/07-bash-automation.md)
