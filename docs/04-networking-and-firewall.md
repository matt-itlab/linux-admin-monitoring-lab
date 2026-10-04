# Networking and Firewall Verification

**Status:** Network verification and both controlled failures are complete. The HTTP firewall exercise demonstrated blocked client traffic while Nginx remained healthy locally; removing the temporary rule restored Windows access. The DNS exercise demonstrated a name-resolution timeout while numeric IP reachability still worked; restoring the original DNS server list restored name resolution.

## Existing Network and Access Paths

The VM uses VirtualBox NAT with the guest address `10.0.2.15` on `enp0s3` and gateway `10.0.2.2`. The initial routing and DNS checks are recorded in [server setup](01-server-setup.md).

| Service | Windows host endpoint | Guest TCP port | Evidence |
| --- | --- | --- | --- |
| SSH | `127.0.0.1:2222` | `22` | Successful key login and rejected password-only login; see [SSH verification](03-ssh.md) |
| HTTP | `127.0.0.1:8080` | `80` | NAT mapping shown in the earlier VirtualBox screenshot; HTTP `200 OK` and the Zabbix login page subsequently verified from Windows |

UFW runs inside the guest and applies to the guest ports. The Windows forwarding ports are separate from those guest ports.

## UFW Inspection

The lab owner ran:

```bash
sudo ufw status verbose
sudo ufw app list
```

| Setting | Observed value |
| --- | --- |
| Status | `active` |
| Logging | `on (low)` |
| Default incoming policy | `deny` |
| Default outgoing policy | `allow` |
| Routed traffic setting | `disabled` |
| New profiles | `skip` |

The listed incoming rules were:

| Guest port | Rule label | Action | Source |
| --- | --- | --- | --- |
| `22/tcp` | `OpenSSH` | `ALLOW IN` | `Anywhere` |
| `80/tcp` | No application label | `ALLOW IN` | `Anywhere` |
| `22/tcp` | `OpenSSH (v6)` | `ALLOW IN` | `Anywhere (v6)` |
| `80/tcp` | No application label | `ALLOW IN` | `Anywhere (v6)` |

UFW reports rules for both IPv4 and IPv6. `Anywhere` means any source address for the relevant IP family within the scope of that rule; it does not establish that the VM is reachable from the Internet. NAT forwarding and service listeners also affect access.

The available application profiles were `Nginx Full`, `Nginx HTTP`, `Nginx HTTPS`, `Nginx QUIC`, and `OpenSSH`. An available profile is a rule definition, not evidence that its ports are allowed or that the corresponding service is running. See the [Ubuntu UFW reference](https://manpages.ubuntu.com/manpages/resolute/man8/ufw.8.html).

## Listening TCP Sockets

The lab owner ran:

```bash
sudo ss -ltn
```

Here, `-l` selects listening sockets, `-t` selects TCP, and `-n` keeps addresses and ports numeric. This command does not display process ownership.

| TCP port | Local addresses reported | Observation |
| --- | --- | --- |
| `22` | `0.0.0.0`, `[::]` | SSH port; matching UFW allow rules are present |
| `80` | `0.0.0.0` | HTTP port; matching UFW allow rules are present, but only an IPv4 listener was listed |
| `53` | `127.0.0.54`, `127.0.0.53%lo` | Loopback listeners |
| `3306`, `33060` | `127.0.0.1` | Loopback listeners; MySQL was identified in the earlier process inspection |
| `10050` | `*` | Zabbix Agent 2 was identified on this port in the earlier process inspection |
| `10051` | `0.0.0.0`, `[::]` | Zabbix Server was identified on this port in the earlier process inspection |
| `9090` | `*` | Listener present; application identity not established by this command |

`0.0.0.0` is the IPv4 wildcard address and `[::]` is the IPv6 wildcard address. Loopback listeners serve connections within the guest. The `*` notation above is preserved as reported rather than used to infer separate IPv4 and IPv6 listeners.

There were no allow rules for ports `10050`, `10051`, or `9090` in the supplied UFW status output. A listening socket alone does not prove remote reachability, and this inspection did not test blocked connections or inspect every underlying firewall rule.

## Nginx Configuration and HTTP Verification

The lab owner checked the Nginx configuration on Ubuntu:

```bash
sudo nginx -t
```

The command reported:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

This validates configuration syntax and access to the files referenced by the configuration. It does not itself test HTTP access. See the [Nginx command-line reference](https://nginx.org/en/docs/switches.html).

The lab owner also tested the Windows host endpoint from PowerShell:

```powershell
curl.exe -I --max-time 10 http://127.0.0.1:8080/
```

Selected response headers were:

```text
HTTP/1.1 200 OK
Server: nginx/1.28.3 (Ubuntu)
Content-Type: text/html; charset=UTF-8
```

The session cookie returned in `Set-Cookie` is omitted from this document. Session cookie values must not be committed to the repository.

The [browser screenshot](../screenshots/zabbix-login.png) showed the Zabbix login form at `127.0.0.1:8080`, with empty username and password fields.

| Check | Confirmed result |
| --- | --- |
| Nginx configuration test | Syntax OK; test successful |
| HTTP HEAD request from Windows | `200 OK` from the forwarded endpoint |
| Browser access from Windows | Zabbix login page displayed |

These results confirm HTTP access from the Windows host through the configured NAT path while UFW is active. They established frontend login-page availability at this stage. Subsequent authenticated access, metric collection, and trigger recovery are recorded in [Zabbix monitoring verification](06-zabbix-monitoring.md).

The separate static lab page was subsequently verified at the same endpoint using `Host: lab.test`, while browser access by IP continued to show Zabbix. See [Nginx site configuration](05-nginx.md) for the reload and HTTP routing tests.

## Controlled HTTP Blocking Scenario

### Baseline

Before introducing a temporary blocking rule, the lab owner checked the current rule order:

```bash
sudo ufw status numbered
```

UFW reported `Status: active` and these entries:

| Rule number at inspection | Destination | Action | Source |
| --- | --- | --- | --- |
| 1 | `OpenSSH` | `ALLOW IN` | `Anywhere` |
| 2 | `80/tcp` | `ALLOW IN` | `Anywhere` |
| 3 | `OpenSSH (v6)` | `ALLOW IN` | `Anywhere (v6)` |
| 4 | `80/tcp (v6)` | `ALLOW IN` | `Anywhere (v6)` |

Rules 2 and 4 permit HTTP for IPv4 and IPv6 respectively. Rules 1 and 3 permit SSH. These numbers describe the inspected baseline and can change when rules are inserted or removed.

Successful lab-site GET and HEAD requests with status `200` were already verified before this inspection.

### First Blocking Attempt: Rule Insertion Skipped

The lab owner attempted to insert a temporary deny rule before the existing allow rules:

```bash
sudo ufw insert 1 deny in 80/tcp comment 'lab-http-block-test'
sudo ufw status numbered
```

UFW returned:

```text
Skipping inserting existing rule
Skipping inserting existing rule (v6)
```

The numbered list still showed the same four allow rules from the baseline, with no HTTP deny rule. The lab owner reported that the pages remained accessible; no new curl output was supplied for this attempt. The intended block was not installed, so this result does not demonstrate traffic bypassing a deny rule.

### Second Attempt: Source-Specific Rule Inserted and Timeout Observed

The lab owner narrowed the deny rule to source `10.0.2.2`, the client address previously observed in the Nginx access log for Windows requests through VirtualBox NAT:

```bash
sudo ufw insert 1 deny in proto tcp from 10.0.2.2 to any port 80 comment 'lab-http-block-test'
sudo ufw status numbered
```

UFW reported `Rule inserted`, remained active, and listed:

| Rule number at inspection | Destination | Action | Source | Comment |
| --- | --- | --- | --- | --- |
| 1 | `80/tcp` | `DENY IN` | `10.0.2.2` | `lab-http-block-test` |
| 2 | `OpenSSH` | `ALLOW IN` | `Anywhere` | |
| 3 | `80/tcp` | `ALLOW IN` | `Anywhere` | |
| 4 | `OpenSSH (v6)` | `ALLOW IN` | `Anywhere (v6)` | |
| 5 | `80/tcp (v6)` | `ALLOW IN` | `Anywhere (v6)` | |

The new rule has different source criteria from the general HTTP allow rule and precedes it. The listed SSH rules are unchanged in scope; the temporary rule applies to IPv4 TCP port `80` from `10.0.2.2`.

The lab owner then tested from Windows PowerShell:

```powershell
curl.exe -sS --max-time 5 -H "Host: lab.test" http://127.0.0.1:8080/
echo $LASTEXITCODE
```

Observed output:

```text
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
28
```

This verifies the rule insertion and the subsequent failure of a new HTTP request through the forwarded endpoint. Exit code `28` is a curl timeout, not an HTTP response status. The result is consistent with the intended firewall block, but the timeout alone does not establish whether Nginx was still serving requests locally.

### Local Service Checks During the Blocking Scenario

With the temporary deny rule still in place, the lab owner ran these commands inside Ubuntu:

```bash
systemctl is-active nginx
curl -sS --max-time 5 -H "Host: lab.test" -w '\nHTTP %{http_code}\n' http://127.0.0.1/
```

| Check | Observed result |
| --- | --- |
| Nginx service state | `active` |
| Local HTTP request with `Host: lab.test` | Lab HTML returned, including `linux01 — Linux Administration Lab` and `My first static website served by Nginx.` |
| Local HTTP response status | `200` |

The local request used guest port `80` over loopback. It did not use the Windows forwarding endpoint on port `8080` or source address `10.0.2.2` targeted by the temporary rule. These results establish that the service was active and could serve the lab page locally during the scenario. Together with the earlier Windows timeout and the rule order, they support the firewall block as the cause of the failed Windows request.

### Packet Counters and Confirmed Cause

The rule was added without `log`; UFW does not log each rule match by default, so an absent log entry would not disprove a match. See the per-rule logging description in the [UFW manual](https://manpages.ubuntu.com/manpages/xenial/man8/ufw.8.html). The lab owner inspected packet counters instead:

```bash
sudo iptables -L ufw-user-input -n -v
```

The relevant row was:

```text
 pkts bytes target     prot opt in     out     source               destination
    6   264 DROP       tcp  --  *      *       10.0.2.2             0.0.0.0/0            tcp dpt:80
```

At inspection, this rule had matched and dropped `6` TCP packets totaling `264` bytes. These are firewall packet and byte counters, not HTTP request counts or HTTP response-body sizes. The lab owner correctly identified `pkts: 6`.

The cause was the temporary IPv4 deny rule for traffic from `10.0.2.2` to guest TCP port `80`, placed before the general HTTP allow rule. The nonzero DROP counter confirms that matching traffic reached the guest firewall and was discarded. The Windows timeout and successful local HTTP response are consistent with this cause.

### Recovery Verification

The lab owner removed the specific temporary rule and inspected the remaining rules:

```bash
sudo ufw delete deny in proto tcp from 10.0.2.2 to any port 80
sudo ufw status numbered
```

UFW reported `Rule deleted` and `Status: active`. The remaining rules matched the baseline:

| Rule number at inspection | Destination | Action | Source |
| --- | --- | --- | --- |
| 1 | `OpenSSH` | `ALLOW IN` | `Anywhere` |
| 2 | `80/tcp` | `ALLOW IN` | `Anywhere` |
| 3 | `OpenSSH (v6)` | `ALLOW IN` | `Anywhere (v6)` |
| 4 | `80/tcp (v6)` | `ALLOW IN` | `Anywhere (v6)` |

The lab owner repeated the request from Windows PowerShell:

```powershell
curl.exe -sS --max-time 5 -H "Host: lab.test" -w "\nHTTP %{http_code}\n" http://127.0.0.1:8080/
echo $LASTEXITCODE
```

The response contained the prepared lab HTML, including `linux01 — Linux Administration Lab` and `My first static website served by Nginx.`, followed by `HTTP 200`. `$LASTEXITCODE` was `0`.

A browser screenshot supplied for the recovery check showed the Zabbix login form at `http://127.0.0.1:8080/`, with empty username and password fields. This confirms restored login-page availability; it does not establish authenticated access or working monitoring.

| Evidence | Result |
| --- | --- |
| Temporary deny rule removed | `Rule deleted`; baseline four allow rules restored |
| Firewall state after correction | `active` |
| Lab page from Windows after correction | Expected HTML, HTTP `200`, curl exit code `0` |
| Browser access by IP after correction | Zabbix login page displayed |

**Scenario outcome:** Resolved. Removing the temporary HTTP deny rule restored access from Windows while UFW stayed active. This completes the second controlled troubleshooting scenario, after the [group-write permissions exercise](02-users-and-permissions.md).

The exercise demonstrated why service state, local HTTP responses, firewall rule order, and packet counters should be considered together: a service can be healthy locally while incoming client traffic is blocked.

## Controlled DNS Failure and Recovery

### Baseline

On 2026-10-04, the lab owner ran these commands on Ubuntu before the DNS failure exercise:

```bash
resolvectl status
getent ahostsv4 ubuntu.com
echo $?
```

The supplied resolver configuration was:

| Setting | Observed value |
| --- | --- |
| `resolv.conf` mode | `stub` |
| Interface | `enp0s3` (link 2) |
| Current DNS server | `178.235.153.33` |
| Configured DNS servers | `178.235.153.33`, `178.235.153.32`, `fd17:625c:f037:2::3` |
| DNS scope | `DNS` |
| DNS default route | `yes` |

The name lookup returned IPv4 addresses `185.125.190.20`, `185.125.190.21`, and `185.125.190.29`, with exit code **`0`**. The output listed each address for the `STREAM`, `DGRAM`, and `RAW` socket types. This establishes successful name resolution before fault injection and records the DNS server list needed for restoration.

### Fault Injection and Diagnosis

The lab owner temporarily replaced the interface's DNS server list with a test address and cleared the local resolver cache:

```bash
sudo resolvectl dns enp0s3 192.0.2.1
sudo resolvectl flush-caches
resolvectl status enp0s3
```

The status output showed only `192.0.2.1` under `DNS Servers`, with DNS scope and default route still enabled for `enp0s3`. The commands changed the active per-interface resolver settings. See the [resolvectl reference](https://manpages.ubuntu.com/manpages/resolute/man1/resolvectl.1.html).

The lab owner compared numeric IP reachability with name resolution:

```bash
ping -n -c 1 -W 2 1.1.1.1
echo $?
timeout 15s getent ahostsv4 ubuntu.com
echo $?
```

| Check during the fault | Observed result | Exit code |
| --- | --- | --- |
| ICMP to `1.1.1.1` | One reply, 0% packet loss, RTT `18.209 ms` | `0` |
| IPv4 lookup of `ubuntu.com` | No addresses returned before the 15-second limit | `124` |

Exit code `124` comes from `timeout`: the lookup exceeded the time limit. It is not an HTTP status or a DNS response such as NXDOMAIN. See the [timeout reference](https://manpages.ubuntu.com/manpages/resolute/man1/timeout.1.html).

The successful ping showed that numeric IPv4 reachability to the tested address still worked. The resolver configuration and failed lookup pointed to the substituted DNS server, rather than a loss of all network connectivity.

### Restoration and Verification

The lab owner restored all three original servers, flushed the cache again, and repeated the lookup:

```bash
sudo resolvectl dns enp0s3 178.235.153.33 178.235.153.32 fd17:625c:f037:2::3
sudo resolvectl flush-caches
timeout 15s getent ahostsv4 ubuntu.com
echo $?
resolvectl status enp0s3
```

| Recovery evidence | Observed result |
| --- | --- |
| Name lookup | `185.125.190.20`, `185.125.190.21`, and `185.125.190.29` returned |
| Lookup exit code | `0` |
| Current DNS server | `178.235.153.33` |
| Configured DNS servers | `178.235.153.33`, `178.235.153.32`, `fd17:625c:f037:2::3` |
| Interface DNS default route | `yes` |

**Scenario outcome:** Resolved. The temporary DNS server substitution caused the lookup to time out; restoring the original server list restored name resolution. No persistent network configuration edit was part of this exercise.

The [Bash health check](07-bash-automation.md) tests ICMP to a numeric address. That check alone cannot detect this DNS fault. The script was not run during this exercise; the direct ping and lookup provide the observed comparison.

## Monitoring Access Scope

Zabbix Server and Agent 2 communicate on the same VM through loopback. No additional incoming UFW rules were needed for the verified monitoring exercises. Monitoring an external host would require a separate review of the relevant communication path.
