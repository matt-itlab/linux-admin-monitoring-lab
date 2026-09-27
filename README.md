# Linux Administration & Monitoring Lab

A practical home lab for developing Linux administration, monitoring, and troubleshooting skills for junior infrastructure and support roles.

**Status:** Work in progress. The initial server baseline and core users, groups, and permissions exercise are complete. One controlled group-write failure has been diagnosed, corrected, and retested. SSH keys and functional monitoring validation remain planned work.

## Current Environment

| Component | Verified state |
| --- | --- |
| Virtualization | Oracle VirtualBox on Windows |
| Operating system | Ubuntu 26.04.1 LTS |
| Hostname | `linux01` (renamed from `ubuntu-server-26`; verified after reboot) |
| Networking | VirtualBox NAT; outbound IPv4 ICMP and DNS resolution verified |
| Remote access | SSH from Windows to `127.0.0.1:2222` as `matt`, using the account password |
| Monitoring software | Zabbix Server and Agent 2 packages at version 7.0.31 |

Nginx, MySQL, Zabbix Server, Zabbix Agent 2, and PHP-FPM were confirmed active after the upgrade and reboot. HTTP responses, metric collection, and alerts still require validation.

## Planned Work

- Configure SSH keys, UFW, and an Nginx site; inspect services and logs.
- Validate Zabbix monitoring, triggers, and recovery.
- Build a Bash health check incrementally and schedule it with cron.
- Complete at least three additional controlled troubleshooting scenarios (one of the planned minimum of four is complete).

## Documentation

- [Server setup and initial verification](docs/01-server-setup.md)
- [Users, groups, and permissions](docs/02-users-and-permissions.md)
