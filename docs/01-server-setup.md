# Server Setup and Initial Verification

**Status:** Initial server baseline verification complete. Functional Zabbix validation remains pending. The observations below are based on terminal results and confirmations provided by the lab owner.

## Confirmed Environment

| Item | Observed value |
| --- | --- |
| Platform | Oracle VirtualBox on Windows |
| Operating system | Ubuntu 26.04.1 LTS (`resolute`) |
| Running kernel after the upgrade and reboot | `7.0.0-34-generic` |
| Current hostname | `linux01` (verified after reboot) |
| Login account | `matt` |
| Network mode | NAT |
| Network interface | `enp0s3`, state `UP` |
| Guest IPv4 address at inspection | `10.0.2.15/24` |
| Remote access | SSH from Windows to `127.0.0.1:2222` as `matt`, using the account password |

## Verification Performed

The following commands were run on Ubuntu to inspect identity, OS version, network addresses, and listening TCP sockets:

```bash
whoami
hostname
cat /etc/os-release
ip -br addr
sudo ss -ltnp
```

At the initial inspection, `whoami` returned `matt`, `hostname` returned `ubuntu-server-26`, and `/etc/os-release` reported `VERSION_ID="26.04"` and `PRETTY_NAME="Ubuntu 26.04.1 LTS"`.

The socket inspection showed:

| TCP port | Observed listener |
| --- | --- |
| 22 | `systemd`, on IPv4 and IPv6 wildcard addresses |
| 80 | `nginx` |
| 10050 | `zabbix_agent2` |
| 10051 | `zabbix_server` |

SSH login was subsequently confirmed. The other listeners establish that processes are present; HTTP responses, Zabbix configuration, metric collection, and alerts have not yet been validated.

## SSH Access

The lab owner confirmed connecting from Windows PowerShell with:

```powershell
ssh -p 2222 matt@127.0.0.1
```

The `-p 2222` option selects the SSH destination port on Windows. Here, `127.0.0.1` is the Windows host's loopback address, used to reach the VM through VirtualBox NAT forwarding. The SSH listener inside Ubuntu was observed on TCP port `22`.

Authentication uses the Ubuntu account password for `matt`. SSH key authentication has not yet been configured or verified as part of this lab. The password itself is not recorded in this document.

## Account and Resource Checks

The following commands were run in the SSH session:

```bash
id
sudo -l
free -h
df -h / /boot
```

The account `matt` has UID and primary GID `1000` and belongs to the `sudo` group. `sudo -l` reported `(ALL : ALL) ALL`, allowing any command as any target user and group, including root.

| Resource | Observed value |
| --- | --- |
| Memory visible to Ubuntu | 3.3 GiB total, 1.1 GiB used, 2.2 GiB available |
| Swap | 3.7 GiB total, 0 B used |
| Root filesystem device | `/dev/mapper/ubuntu--vg-ubuntu--lv` |
| Root filesystem usage | 19G size, 8.1G used, 9.0G available, 48% used (post-upgrade `df -h` observation) |
| Boot filesystem | `/dev/sda2`, 2.0G size, 184M used, 1.7G available, 11% used |

These memory and filesystem usage figures are point-in-time observations.

## Disk Layout

After the upgrade, the lab owner inspected the disk layout and filesystem usage:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
df -h / /boot
```

| Device | Size reported by `lsblk` | Type / filesystem | Role |
| --- | --- | --- | --- |
| `/dev/sda` | 40G | Disk | Virtual disk presented to Ubuntu |
| `/dev/sda1` | 1G | Partition / vfat | EFI system partition mounted at `/boot/efi` |
| `/dev/sda2` | 2G | Partition / ext4 | Boot filesystem mounted at `/boot` |
| `/dev/sda3` | 36.9G | Partition / LVM2_member | Storage backing the LVM logical volume |
| `/dev/mapper/ubuntu--vg-ubuntu--lv` | 18.5G | Logical volume / ext4 | Root filesystem mounted at `/` |

The output also showed SquashFS loop devices mounted under `/snap` and an optical device, `/dev/sr0`, containing an ISO 9660 filesystem.

The lab owner then checked the volume group:

```bash
sudo vgs
```

The `ubuntu-vg` volume group contains one physical volume and one logical volume. Its reported total size is `<36.95g`, with `18.47g` (approximately 18.47 GiB) free for allocation to logical volumes.

This unallocated LVM capacity is separate from the approximately 9.0 GiB available inside the root filesystem. No volume or filesystem resize has been performed during these checks.

## Routing and DNS Checks

The following commands were run in the SSH session:

```bash
ip route
resolvectl status
ping -c 4 1.1.1.1
resolvectl query ubuntu.com
```

| Check | Observed result |
| --- | --- |
| Default IPv4 route | Via `10.0.2.2` on `enp0s3`, source address `10.0.2.15`; route supplied by DHCP |
| Directly connected IPv4 network | `10.0.2.0/24` |
| Current DNS server | `178.235.153.33` |
| Configured DNS servers on `enp0s3` | `178.235.153.33`, `178.235.153.32`, `fd17:625c:f037:2::3` |
| Resolver mode | `stub` |
| IPv4 ICMP test to `1.1.1.1` | Four replies from four requests, 0% packet loss |
| DNS query for `ubuntu.com` | Returned IPv4 and IPv6 addresses; result obtained from the network |

These checks confirm outbound IPv4 ICMP connectivity to the tested address and successful DNS resolution for the tested domain. These particular tests do not establish HTTPS access or outbound IPv6 connectivity.

## Package Sources and Available Updates

The lab owner ran:

```bash
sudo apt update
apt list --upgradable
```

The provided output showed a completed index refresh with no visible errors and reported 49 upgradable packages. Ubuntu indexes used the `resolute`, `resolute-updates`, `resolute-security`, and `resolute-backports` suites, matching the installed release.

| Repository observed in the output | Purpose |
| --- | --- |
| `http://pl.archive.ubuntu.com/ubuntu` | Ubuntu packages, updates, and backports |
| `http://security.ubuntu.com/ubuntu` | Ubuntu security updates |
| `https://repo.zabbix.com/zabbix/7.0/ubuntu` | Zabbix 7.0 packages for `resolute` |
| `https://repo.zabbix.com/zabbix-tools/debian-ubuntu` | Zabbix tools repository for `resolute` |

Before the upgrade, APT reported the following Zabbix packages as installed at `1:7.0.30-1+ubuntu26.04`, with `1:7.0.31-1+ubuntu26.04` available:

- `zabbix-server-mysql`
- `zabbix-agent2`
- `zabbix-frontend-php`
- `zabbix-nginx-conf`
- `zabbix-sql-scripts`

The update list also included the `linux-generic` kernel metapackage (`7.0.0-31.31` to `7.0.0-34.34`), Netplan, NetworkManager, and system libraries. The installed kernel metapackage version does not establish which kernel is currently running.

### Upgrade Preflight

The lab owner checked candidate versions and simulated the upgrade:

```bash
apt policy zabbix-server-mysql zabbix-agent2
sudo apt -s upgrade
```

For both Zabbix packages, APT selected `1:7.0.31-1+ubuntu26.04` from `https://repo.zabbix.com/zabbix/7.0/ubuntu`, suite `resolute/main`. The installed version remained `1:7.0.30-1+ubuntu26.04`.

| Simulated operation | Count |
| --- | --- |
| Upgrade installed packages | 42 |
| Install new dependencies | 7 |
| Remove packages | 0 |
| Defer upgrades due to phasing | 7 |

APT reported 31 standard LTS security updates. The new dependencies included the `7.0.0-34-generic` kernel image, headers, modules, and tools. The simulation completed without a reported dependency error.

The seven deferred packages were explicitly listed under `Not upgrading yet due to phasing`. Ubuntu releases these updates gradually; the deferral is not a failed installation. See [Ubuntu's explanation of phased updates](https://ubuntu.com/server/docs/explanation/software/about-apt-upgrade-and-phased-updates/).

### Pre-upgrade Runtime Checks

The lab owner ran:

```bash
uname -r
systemctl --failed --no-pager
```

The running kernel was `7.0.0-31-generic`. The failed-unit query returned `0 loaded units listed`, confirming that no systemd units were listed in the failed state at inspection time.

### Restore Point

The lab owner confirmed that the VirtualBox snapshot `before-baseline-upgrade` was saved before installing updates. This is the rollback point for the planned package upgrade.

### Package Upgrade Result

The lab owner completed the package upgrade and checked its exit status immediately afterward:

```bash
sudo apt upgrade
echo $?
```

The exit status was `0`. The supplied completion log showed:

- The `7.0.0-34-generic` kernel image and initrd were present in `/boot` and detected while generating the GRUB configuration.
- The previous `7.0.0-31-generic` kernel was still running, and the output requested a reboot to load the new kernel.
- The restart phase listed `php8.5-fpm`, `polkit`, `udisks2`, and `zabbix-server`; some other service restarts were deferred.
- GRUB reported that `os-prober` was disabled. This concerns detection of other installed operating systems; both Ubuntu kernel images were detected in the supplied log. See the [GNU GRUB configuration documentation](https://www.gnu.org/software/grub/manual/grub/html_node/Simple-configuration.html).

### Post-reboot Verification

After the reboot, the lab owner ran:

```bash
uname -r
systemctl --failed --no-pager
systemctl is-active nginx mysql zabbix-server zabbix-agent2 php8.5-fpm
dpkg -l 'zabbix*'
apt list --upgradable
```

| Check | Confirmed result |
| --- | --- |
| Running kernel | `7.0.0-34-generic` |
| Failed systemd units | None listed |
| Service states | `nginx`, `mysql`, `zabbix-server`, `zabbix-agent2`, and `php8.5-fpm` all returned `active` |
| Zabbix application packages | All five packages listed in the pre-upgrade inventory were at `1:7.0.31-1+ubuntu26.04`, with status `ii` |
| Zabbix repository configuration package | `zabbix-release` at `1:7.0-5+ubuntu26.04`, with status `ii` |
| Remaining available updates | The same seven packages identified as phased updates in the pre-upgrade simulation |

The `un` entries for `zabbix-apache-conf` and `zabbix-server-pgsql` represent packages that are not installed. The observed stack uses Nginx and MySQL.

**Upgrade status:** The initial package upgrade and reboot verification are complete. Service activity is confirmed; HTTP responses, Zabbix metrics, alerts, and recovery still require functional testing.

## Hostname Change

### Pre-change Checks

Before changing the system hostname, the lab owner ran:

```bash
cat /etc/hosts
sudo zabbix_agent2 -c /etc/zabbix/zabbix_agent2.conf -t agent.hostname
```

The local hosts file mapped `127.0.0.1` to `localhost` and `127.0.1.1` to `ubuntu-server-26`. It also contained IPv6 localhost, local-network, multicast, all-nodes, and all-routers entries.

The agent test returned:

```text
agent.hostname                                [s|Zabbix server]
```

The tested agent identity was `Zabbix server`, which differed from the system hostname. This local test does not establish connectivity to the Zabbix server or successful metric collection.

### Verification After the Change

The planned lab host `LINUX01` uses the lowercase system hostname `linux01`. After the change, the lab owner ran:

```bash
hostname
cat /etc/hostname
getent hosts linux01
sudo zabbix_agent2 -c /etc/zabbix/zabbix_agent2.conf -t agent.hostname
```

| Check | Confirmed result |
| --- | --- |
| Running hostname | `linux01` |
| Hostname saved in `/etc/hostname` | `linux01` |
| Local name resolution | `127.0.1.1 linux01 ubuntu-server-26` |
| Agent identity in the local test | `Zabbix server`, unchanged from the pre-change test |

The old name remains a local alias. The running hostname and saved configuration agree. The name-resolution check was performed inside Ubuntu and does not establish that Windows can resolve `linux01`.

### Verification After Reboot

After rebooting, the lab owner ran:

```bash
hostname
getent hosts linux01
systemctl --failed --no-pager
systemctl is-active nginx mysql zabbix-server zabbix-agent2 php8.5-fpm
```

The hostname remained `linux01`, and the local lookup returned `127.0.1.1 linux01 ubuntu-server-26`. No failed systemd units were listed. Nginx, MySQL, Zabbix Server, Zabbix Agent 2, and PHP-FPM all returned `active`.

These results confirm that the hostname change persisted across the reboot and that the five checked services were active afterward. Application-level monitoring checks remain pending.

## Deferred Monitoring Validation

The Zabbix frontend, collected metrics, alerts, and recovery still require functional validation during the monitoring stage. Active service states alone do not establish that monitoring works.
