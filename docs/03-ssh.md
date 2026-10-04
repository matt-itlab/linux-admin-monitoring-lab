# SSH Key Setup and Verification

**Status:** SSH key login and authentication hardening checks completed. The configuration passed validation, a new key-authenticated connection succeeded as `matt` on `linux01`, and a password-only connection was rejected with `Permission denied (publickey)` and exit code `255`.

## Existing Connection

During the initial baseline, password-based SSH access from Windows to the Ubuntu account `matt` was confirmed:

```powershell
ssh -p 2222 matt@127.0.0.1
```

See [server setup](01-server-setup.md) for the verified NAT access and server baseline.

## Client Public Key Verification

The lab owner ran this command in Windows PowerShell:

```powershell
ssh-keygen -l -f "$env:USERPROFILE\.ssh\id_ed25519_linux_lab.pub"
```

It returned:

```text
256 SHA256:6mh4xertrJnO5/HENQpFZw4Q2DV7kTQeHrtCPUyGQCY matt-linux-lab (ED25519)
```

This verifies that the inspected public key uses Ed25519 and has the comment `matt-linux-lab`. The SHA256 fingerprint identifies the key when checking its transfer to Ubuntu. This result alone does not establish that the server accepts the key for login.

The later successful login screenshot records the custom client path `C:\Users\Matt.ssh\id_ed25519_linux_lab`. The transfer and login commands below use that observed location. It differs from the `.ssh` directory inside the user profile used in the initial fingerprint command above; use the actual key location when repeating a connection. No directory move is established by these observations.

## Public Key Transfer and Server-side Inspection

The lab owner transferred the public key from Windows to the Ubuntu account's home directory using SCP on port `2222`:

```powershell
scp -P 2222 "$env:USERPROFILE.ssh\id_ed25519_linux_lab.pub" matt@127.0.0.1:linux-lab-key.pub
```

SCP reported a completed transfer of 97 bytes. After connecting to Ubuntu with the account password, the lab owner ran:

```bash
ssh-keygen -l -f ~/linux-lab-key.pub
ls -ld ~ ~/.ssh
ls -l ~/.ssh/authorized_keys
```

The transferred public key returned the same SHA256 fingerprint, Ed25519 type, and `matt-linux-lab` comment as the Windows copy.

| Inspected path | Owner and group | Permissions | Additional observation |
| --- | --- | --- | --- |
| `/home/matt` | `matt:matt` | `drwxr-x---` (`750`) | Account home directory |
| `/home/matt/.ssh` | `matt:matt` | `drwx------` (`700`) | SSH directory already exists |
| `/home/matt/.ssh/authorized_keys` | `matt:matt` | `-rw-------` (`600`) | Empty file, 0 bytes before adding the lab key |

The observed ownership and permissions were suitable for adding the public key. At this inspection, the authorized-keys file was still empty.

## Authorized Key and Login Verification

After adding the key, the lab owner checked the authorized-keys file:

```bash
ssh-keygen -l -f ~/.ssh/authorized_keys
```

The result matched the client key's fingerprint `SHA256:6mh4xertrJnO5/HENQpFZw4Q2DV7kTQeHrtCPUyGQCY`, type `ED25519`, and comment `matt-linux-lab`.

The lab owner then opened a new connection from Windows PowerShell:

```powershell
ssh -p 2222 -i "$env:USERPROFILE.ssh\id_ed25519_linux_lab" -o IdentitiesOnly=yes -o PreferredAuthentications=publickey matt@127.0.0.1
```

The client prompted for the private key's passphrase and opened an Ubuntu shell. The connection restricted authentication to `publickey`, so the successful login did not fall back to the Ubuntu account password. The passphrase unlocks the private key locally; it is separate from the account password.

Inside the new session, the lab owner ran:

```bash
whoami
hostname
```

| Verification | Confirmed result |
| --- | --- |
| Authorized public key | Fingerprint matches the Windows key |
| Authentication method in the new connection | Public key, with a private-key passphrase prompt |
| Logged-in account | `matt` |
| Server hostname | `linux01` |

This confirms working key-based login. It does not establish that password-based login has been disabled on the server.

Evidence: [SSH key login from Windows, followed by account and hostname checks](../screenshots/ssh-key-login.png).

## Authentication Configuration Before Hardening

The lab owner inspected the effective configuration and active configuration lines:

```bash
sudo /usr/sbin/sshd -T | grep -E '^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|authenticationmethods|usepam) '
sudo grep -nEv '^[[:space:]]*(#|$)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf
```

| Setting | Observed value | Meaning |
| --- | --- | --- |
| `PubkeyAuthentication` | `yes` | Public-key authentication is enabled |
| `PasswordAuthentication` | `yes` | Account-password authentication is enabled |
| `KbdInteractiveAuthentication` | `no` | Keyboard-interactive authentication is disabled |
| `PermitRootLogin` | `prohibit-password` | Root password and keyboard-interactive authentication are disabled; this does not prohibit root key authentication |
| `AuthenticationMethods` | `any` | Any one enabled authentication method can satisfy authentication |
| `UsePAM` | `yes` | PAM integration is enabled |

The main file includes `/etc/ssh/sshd_config.d/*.conf` at line 24. The reported drop-in `/etc/ssh/sshd_config.d/50-cloud-init.conf` contains `PasswordAuthentication yes` at line 1. No active `Match` blocks were present in the supplied configuration output.

For these authentication settings, OpenSSH uses the first obtained value, and included wildcard files are processed in lexical order. A lab drop-in named `00-lab-hardening.conf` therefore takes precedence over `50-cloud-init.conf` in this observed configuration. See the [OpenSSH configuration reference](https://man.openbsd.org/sshd_config).

## Hardening Configuration Validation

The lab owner edited `/etc/ssh/sshd_config.d/00-lab-hardening.conf` using `sudo nano`, then validated the configuration:

```bash
sudo /usr/sbin/sshd -t
echo $?
```

The validation produced no diagnostic output and returned exit code `0`. Repeating the `sshd -T` authentication inspection returned:

```text
usepam yes
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
authenticationmethods publickey
```

The resulting configuration requires public-key authentication, disables password and keyboard-interactive authentication, and prohibits direct root login over SSH. PAM integration remains enabled.

Both `sshd -t` and `sshd -T` inspect the configuration on disk; neither reloads the running service. Live authentication behavior was subsequently checked with the new connections below.

## Live Authentication Tests After Configuration Change

The lab owner repeated the public-key-only PowerShell connection command from the earlier login verification. The client prompted for the private key's passphrase and opened a new Ubuntu session. Inside that session, `whoami` returned `matt` and `hostname` returned `linux01`.

After leaving this test session with `exit`, the lab owner attempted a password-only connection from PowerShell:

```powershell
ssh -p 2222 -o PubkeyAuthentication=no -o PreferredAuthentications=password matt@127.0.0.1
echo $LASTEXITCODE
```

The result was:

```text
matt@127.0.0.1: Permission denied (publickey).
255
```

No account-password prompt appeared. The client disabled public-key authentication and selected only the password method, while the server offered only public-key authentication. The refusal is the expected result of this negative test.

| Live test | Confirmed result |
| --- | --- |
| New connection using the lab key | Login succeeded as `matt` on `linux01` |
| Password-only connection | Rejected without a password prompt; exit code `255` |

These tests confirm key access and rejection of password authentication for `matt` through `127.0.0.1:2222`. Direct root login was disabled in the inspected configuration; no separate root connection test was performed. The reload command's output was not supplied, so its exit status is not recorded as verified.

Only the public key fingerprint is recorded here. Private key material and passphrases must stay outside this repository.
