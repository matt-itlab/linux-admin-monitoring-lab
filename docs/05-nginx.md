# Nginx Site Configuration

**Status:** Static lab site configuration, HTTP access, and logs are verified. The controlled Nginx outage exercise is complete: Windows curl failure `56` was diagnosed using service status and the journal, starting Nginx restored the lab HTML with HTTP `200` and exit code `0`, and the custom Zabbix HTTP problem was resolved. Nginx and Zabbix Server were both active after the start command.

## Existing HTTP Baseline

Nginx configuration validation passed, and Windows received HTTP `200 OK` at `http://127.0.0.1:8080/`. The browser displayed the Zabbix login page. The NAT mapping, firewall inspection, and HTTP test are recorded in [networking and firewall verification](04-networking-and-firewall.md).

## Configuration Inspection

The lab owner ran:

```bash
sudo nginx -T | grep -nE '^# configuration file|^[[:space:]]*(listen|server_name|root|index|location|access_log|error_log)[[:space:]]'
```

Nginx again reported that syntax was OK and the configuration test was successful. The filtered output identified these configuration files:

- `/etc/nginx/nginx.conf`
- `/etc/nginx/mime.types`
- `/etc/nginx/conf.d/zabbix.conf`
- `/etc/nginx/fastcgi_params`

| Observed setting | Value | Context in the supplied output |
| --- | --- | --- |
| Error log | `/var/log/nginx/error.log` | Main configuration |
| Access log | `/var/log/nginx/access.log` | Main configuration |
| Document root | `/usr/share/zabbix` | Zabbix site configuration |
| Index file | `index.php` | Zabbix site configuration |
| Asset access logging | `off` | `/assets` location in the Zabbix site |

The output also showed location blocks for the site root, favicon, assets, dotfile and application-directory patterns, vendor directory, and PHP requests. Only selected directive lines were displayed, so this inspection does not establish the full behavior of those blocks.

No active `listen` or `server_name` lines appeared in the filtered output. The follow-up inspection below confirmed that the example directives at the start of the Zabbix site file are commented out. Nginx supports a default listener when `listen` is omitted; the earlier socket inspection showed this installation listening on guest TCP port `80`. See the [Nginx listen directive](https://nginx.org/en/docs/http/ngx_http_core_module.html#listen).

`grep -n` reports line numbers in the combined `nginx -T` output, not line numbers within each original configuration file.

## Include Order and Existing Site Defaults

The lab owner inspected the start of the Zabbix site file and the main configuration's include directives:

```bash
sudo head -n 25 /etc/nginx/conf.d/zabbix.conf
sudo grep -nE '^[[:space:]]*include[[:space:]]' /etc/nginx/nginx.conf
```

The Zabbix server block starts with commented example directives:

```nginx
server {
#        listen          8080;
#        server_name     example.com;
```

The `#` marks these lines as comments, so they do not set the site's listening port or name. The Windows NAT forwarding port `8080` is configured separately in VirtualBox.

The main configuration listed:

| Line | Include directive |
| --- | --- |
| 6 | `include /etc/nginx/modules-enabled/*.conf;` |
| 27 | `include /etc/nginx/mime.types;` |
| 60 | `include /etc/nginx/conf.d/*.conf;` |
| 61 | `include /etc/nginx/sites-enabled/*;` |

The existing Zabbix configuration in `conf.d` is therefore read before site files in `sites-enabled`. This matters when adding another server block on port `80`: without an explicit `default_server`, the first server for an address and port is the default for requests that do not match another configured server name. See [how Nginx processes requests](https://nginx.org/en/docs/http/request_processing.html).

## Static Lab Page Preparation

The lab owner set permissions and inspected the new page:

```bash
sudo chmod 755 /var/www/linux-lab
sudo chmod 644 /var/www/linux-lab/index.html
ls -ld /var/www/linux-lab
ls -l /var/www/linux-lab/index.html
cat /var/www/linux-lab/index.html
```

| Path | Owner and group | Permissions | Observation |
| --- | --- | --- | --- |
| `/var/www/linux-lab` | `root:root` | `drwxr-xr-x` (`755`) | Separate document root |
| `/var/www/linux-lab/index.html` | `root:root` | `-rw-r--r--` (`644`) | 236-byte HTML file |

The directory permits traversal and the page permits reading by other users, including the web-server worker account. Only the owner has write permission under these mode bits.

The confirmed HTML content was:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Linux Administration Lab</title>
</head>
<body>
  <h1>linux01 — Linux Administration Lab</h1>
  <p>My first static website served by Nginx.</p>
</body>
</html>
```

These checks verify file preparation. HTTP delivery was subsequently verified in the connection tests below.

## Site Link and Configuration Validation

The lab owner inspected the site link and tested the configuration:

```bash
ls -l /etc/nginx/sites-enabled/linux-lab
sudo nginx -t
echo $?
```

The link inspection returned:

```text
lrwxrwxrwx 1 root root 36 Sep 28 14:40 /etc/nginx/sites-enabled/linux-lab -> /etc/nginx/sites-available/linux-lab
```

The `sites-enabled` entry points to the configuration file in `sites-available`. The previously inspected include directive makes this entry part of the configuration Nginx reads.

The configuration test returned:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

The immediately checked exit code was `0`. This confirms successful validation of the configuration on disk. It does not by itself reload the running service or verify which page an HTTP request receives.

## Reload and HTTP Routing Verification

The lab owner applied the configuration and checked the service:

```bash
sudo systemctl reload nginx
echo $?
systemctl is-active nginx
```

The reload returned exit code `0`, and the service state was `active`.

From Windows PowerShell, the lab owner requested the new site through the existing NAT endpoint:

```powershell
curl.exe -sS --max-time 10 -H "Host: lab.test" -w "\nHTTP %{http_code}\n" http://127.0.0.1:8080/
```

The response contained the prepared HTML, including the title `Linux Administration Lab`, the heading `linux01 — Linux Administration Lab`, and the paragraph `My first static website served by Nginx.` The final status line was:

```text
HTTP 200
```

The lab owner also supplied a new browser screenshot showing the Zabbix login page at `127.0.0.1:8080` after the reload.

| Request from Windows | Confirmed result |
| --- | --- |
| `http://127.0.0.1:8080/` with `Host: lab.test` | Lab HTML returned with HTTP `200` |
| Browser request to `http://127.0.0.1:8080/` | Zabbix login page displayed |

Both requests use the same Windows endpoint and guest TCP port. The explicit Host header selects the lab site, while the browser request by IP continues to reach the existing Zabbix site. This test does not establish DNS resolution or browser access using the name `lab.test`.

## Access, Error, and Service Log Inspection

The lab owner inspected the site logs and the Nginx service journal:

```bash
sudo tail -n 5 /var/log/nginx/linux-lab.access.log
sudo tail -n 10 /var/log/nginx/linux-lab.error.log
sudo journalctl -u nginx -b -n 20 --no-pager
```

The access log contained:

```text
10.0.2.2 - - [28/Sep/2026:14:45:36 +0000] "GET / HTTP/1.1" 200 236 "-" "curl/8.21.0"
```

| Field | Observed value | Interpretation |
| --- | --- | --- |
| Client address seen by Nginx | `10.0.2.2` | Address recorded for this connection |
| Request time | `28/Sep/2026:14:45:36 +0000` | Timestamp with UTC offset |
| HTTP method | `GET` | Request to retrieve the resource |
| Request path | `/` | Root URL path of the selected site |
| HTTP version | `HTTP/1.1` | Protocol version used by the client |
| Response status | `200` | Successful response |
| Response body bytes sent | `236` | HTML body size, excluding response headers; matches the inspected file size |
| User agent | `curl/8.21.0` | Client identification supplied in the request |

This field layout follows the standard Nginx combined access-log format. See the [Nginx logging reference](https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format).

The request path `/` is distinct from the filesystem paths: `/var/www/linux-lab/index.html` contains the served page, while `/var/log/nginx/linux-lab.access.log` stores the request record.

Reading the site error log produced no entries. This observation concerns that log at inspection time and does not establish that every service or log is error-free.

The journal showed these events on September 28, with times as printed by `journalctl`:

| Time | Observed service events |
| --- | --- |
| `14:30:51` | Starting and started `nginx.service` |
| `14:45:22` | Reloading, Nginx notice `signal process started`, and reloaded `nginx.service` |

The supplied notice is part of the reload sequence, not an error message. The service journal records service events; the separate site access log records the HTTP request.

## HEAD Request Verification

After a subsequent HEAD request, the lab owner read the latest access-log entry:

```bash
sudo tail -n 1 /var/log/nginx/linux-lab.access.log
```

The result was:

```text
10.0.2.2 - - [28/Sep/2026:14:58:51 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/8.21.0"
```

The two observed requests demonstrate the difference between GET and HEAD:

| HTTP method | Request path | Response status | Response body bytes sent |
| --- | --- | --- | --- |
| `GET` | `/` | `200` | `236` |
| `HEAD` | `/` | `200` | `0` |

HEAD returns response headers without a response body. The zero in this access-log field therefore represents body bytes, not the total amount of network traffic. See [HTTP HEAD semantics](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.2) and the [Nginx combined log format](https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format).

## Controlled Nginx Outage

**Status: Complete.** HTTP failure, stopped-service diagnosis, service restoration, Windows HTTP recovery, and the custom Zabbix trigger's problem and recovery event are confirmed.

### Symptom

After receiving the controlled outage instructions, the lab owner ran this check from Windows:

```powershell
curl.exe -sS --max-time 5 -H "Host: lab.test" http://127.0.0.1:8080/
echo $LASTEXITCODE
```

The supplied result was:

```text
curl: (56) Recv failure: Connection was aborted
56
```

The client failed to retrieve the page. Exit code `56` indicates a network receive error; the client message alone does not identify the cause. See the [curl error reference](https://curl.se/libcurl/c/libcurl-errors.html).

### Diagnostic Checks and Cause

The diagnostic question was whether Nginx was running and what its recent service events showed. The lab owner ran on Ubuntu:

```bash
sudo systemctl status nginx --no-pager -l
sudo journalctl -u nginx -b -n 20 --no-pager
```

| Evidence | Observed result |
| --- | --- |
| Unit configuration | Loaded and `enabled` |
| Current service state | `inactive (dead)` since `2026-10-02 20:30:03 UTC` |
| Time inactive at inspection | `2min 44s` |
| Previous startup | `20:28:58` in the supplied journal |
| Stop command and main process exit | `status=0/SUCCESS` |

Relevant journal lines were:

```text
Oct 02 20:30:03 linux01 systemd[1]: Stopping nginx.service - A high performance web server and a reverse proxy server...
Oct 02 20:30:03 linux01 systemd[1]: nginx.service: Deactivated successfully.
Oct 02 20:30:03 linux01 systemd[1]: Stopped nginx.service - A high performance web server and a reverse proxy server.
```

The status output explicitly identifies the stop time as UTC. It confirms that Nginx was stopped, explaining the HTTP outage in this exercise. The journal and successful exit statuses show an orderly stop. `enabled` describes startup configuration, while `inactive (dead)` describes the current runtime state. The displayed `Duration: 1min 5.003s` refers to the preceding active period.

### Repair and Verification

The lab owner ran on Ubuntu:

```bash
sudo systemctl start nginx
date -Is
systemctl is-active nginx zabbix-server
```

The output was:

```text
2026-10-02T20:41:35+00:00
active
active
```

Both services were active after the start command. The timestamp was printed after `systemctl start` returned; it is a post-start observation, not an exact service-start timestamp from the journal.

The lab owner repeated the HTTP check from Windows:

```powershell
curl.exe -sS --max-time 5 -H "Host: lab.test" -w "\nHTTP %{http_code}\n" http://127.0.0.1:8080/
echo $LASTEXITCODE
```

The prepared HTML returned, including `linux01 — Linux Administration Lab`, followed by `HTTP 200`. The exit code was `0`. This confirms recovery of the lab page through the Windows-to-VM forwarding path.

The supplied Zabbix event-history screenshot showed:

| Field | Observed value |
| --- | --- |
| Host | `Zabbix server` |
| Problem | `Nginx: Linux lab HTTP check failed` |
| Severity | `Average` |
| Event time | `10:30:31 PM` (UI time) |
| Recovery time | `10:42:01 PM` (UI time) |
| Status | `RESOLVED` |
| Duration | `11m 30s` |

The event was resolved after starting Nginx; no manual event closure was reported. Event duration measures the time between problem creation and recovery in Zabbix, rather than the entire service interruption. The [HTTP trigger timeline](06-zabbix-monitoring.md#http-trigger-problem-and-recovery) distinguishes UI timestamps from UTC service observations.

Starting the stopped Nginx service restored HTTP access. The active service checks, returned page, successful curl exit, and resolved monitoring event complete the exercise. This is the fourth completed controlled failure, alongside the permissions, HTTP firewall, and Zabbix agent exercises.
