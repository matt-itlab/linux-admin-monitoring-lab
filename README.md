# Linux Administration & Monitoring Lab

A practical home lab for developing Linux administration, monitoring, and troubleshooting skills for junior infrastructure and support roles.

**Status:** Work in progress. SSH access, basic network checks, and an initial package upgrade with reboot verification are complete. Monitoring validation remains pending.

## Current Environment

| Component | Verified state |
| --- | --- |
| Virtualization | Oracle VirtualBox on Windows |
| Operating system | Ubuntu 26.04.1 LTS |
| Hostname | `ubuntu-server-26` |
| Networking | VirtualBox NAT; outbound IPv4 ICMP and DNS resolution verified |
| Remote access | SSH login from Windows as `matt` |
| Monitoring software | Zabbix Server and Agent 2 packages at version 7.0.31 |

Nginx, MySQL, Zabbix Server, Zabbix Agent 2, and PHP-FPM were confirmed active after the upgrade and reboot. HTTP responses, metric collection, and alerts still require validation.

## Planned Work

- Complete the server baseline and practice users, groups, sudo, and permissions.
- Configure SSH keys, UFW, and an Nginx site; inspect services and logs.
- Validate Zabbix monitoring, triggers, and recovery.
- Build a Bash health check incrementally and schedule it with cron.
- Diagnose and document at least four controlled failure scenarios.

## Documentation

- [Server setup and initial verification](docs/01-server-setup.md)
