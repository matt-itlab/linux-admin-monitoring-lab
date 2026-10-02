# Linux Administration & Monitoring Lab

A practical home lab for developing Linux administration, monitoring, and troubleshooting skills for junior infrastructure and support roles.

**Status:** Work in progress. Server baseline, users/groups/permissions, and SSH authentication checks are complete. Nginx serves the verified static lab page and the Zabbix frontend through the same forwarded port; its logs have been inspected. Three controlled failures are documented with recovery checks: missing group-write permission, a firewall rule blocking HTTP, and a stopped Zabbix agent. Zabbix collects verified uptime, CPU, memory, and root filesystem metrics from `linux01`. The agent outage exercise confirmed problem detection, service stop/start logs, event recovery, and resumed data collection. Network metrics, Nginx availability monitoring, Bash automation, and cron remain planned work.

## Current Environment

| Component | Verified state |
| --- | --- |
| Virtualization | Oracle VirtualBox on Windows |
| Operating system | Ubuntu 26.04.1 LTS |
| Hostname | `linux01` (renamed from `ubuntu-server-26`; verified after reboot) |
| Networking | VirtualBox NAT; outbound IPv4 ICMP and DNS resolution verified |
| Firewall | UFW active; default incoming deny and outgoing allow; TCP 22 and 80 allowed for IPv4 and IPv6; temporary HTTP deny rule removed after the controlled blocking test |
| Remote access | SSH from Windows to `127.0.0.1:2222` as `matt`; Ed25519 key login verified with a private-key passphrase prompt; password-only login rejected |
| Zabbix web access | Login-page recovery after the firewall exercise verified; successful login and opening the dashboard at `http://127.0.0.1:8080/` confirmed by the lab owner |
| Static lab site | Windows curl with `Host: lab.test` returns the lab HTML, HTTP `200`, and exit code `0` after firewall recovery; DNS resolution for `lab.test` has not been configured as part of this lab |
| Monitoring software | Zabbix Server and Agent 2 packages at version 7.0.31; frontend reports server and frontend versions `7.0.31` and a running server at `localhost:10051`; the latest host list has one enabled and one disabled host |
| Host monitoring status | `Zabbix server` at `127.0.0.1:10050` remains enabled; monitoring of the unidentified `matt` entry at `192.168.0.28:10050` is disabled, with its configuration retained |
| Collected metrics | The `Zabbix server` entry reports system name `linux01` and updating uptime; supplied CPU, memory, and root filesystem usage samples were `1.2664%`, `36.4083%`, and `47.8492%`, each checked less than a minute before its respective capture |
| Agent-availability trigger | Enabled, severity `Average`, effective `{$AGENT.TIMEOUT}` value `3m` inherited from `Linux by Zabbix agent`; the observed problem was resolved at `06:33:26 AM`, two minutes after its displayed start time |
| Agent service after the test | `sudo systemctl start zabbix-agent2` followed by a status check showed both `zabbix-agent2` and `zabbix-server` active at the check associated with `2026-10-02T04:31:56+00:00` |
| Agent outage evidence | Journal confirms the service stopped at `04:28:00 UTC` and started at `04:31:56 UTC` on 2026-10-02: a service interruption of `3m 56s` |
| Collection after recovery | `System uptime` showed `00:17:03`, with last-check age `30s` and change `+00:00:30` |

Nginx, MySQL, Zabbix Server, Zabbix Agent 2, and PHP-FPM were confirmed active after the upgrade and reboot. Authenticated Zabbix frontend access and the frontend's running-server status are now confirmed, and the lab owner reports changing the default frontend password. The `Zabbix server` entry is identified as monitoring `linux01` through its loopback agent interface, with matching system name and fresh resource metrics before the outage exercise. Agent-unavailable problem detection, recovery, and resumed uptime collection are verified.

## Planned Work

- Verify network traffic metrics and configure Nginx availability monitoring with a custom trigger.
- Build a Bash health check incrementally and schedule it with cron.
- Complete further troubleshooting exercises, including stopped Nginx and a DNS/connectivity problem (three scenarios are complete; the target is at least four).

## Documentation

- [Server setup and initial verification](docs/01-server-setup.md)
- [Users, groups, and permissions](docs/02-users-and-permissions.md)
- [SSH key setup and verification](docs/03-ssh.md)
- [Networking and firewall verification](docs/04-networking-and-firewall.md)
- [Nginx site configuration](docs/05-nginx.md)
- [Zabbix monitoring verification](docs/06-zabbix-monitoring.md)
