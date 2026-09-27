# Users, Groups, and Permissions

**Status:** Core exercise complete. Account memberships, shared-directory permissions, authorized file creation, and access denial for an account outside `labops` have been verified. The first controlled troubleshooting scenario, a missing group-write permission, has been reproduced, diagnosed, corrected, and retested.

## Initial Lab Account Verification

The lab owner ran these commands on `linux01`:

```bash
id labuser
ls -ld /home/labuser
```

| Check | Observed value |
| --- | --- |
| Account | `labuser` |
| UID | `1002` |
| Primary group | `labuser`, GID `1002` |
| Supplementary group | `users`, GID `100` |
| Inspected home directory | `/home/labuser` |
| Directory owner and group | `labuser:labuser` |
| Directory type and permissions | `drwxr-x---`, directory mode `750` |

The directory mode grants read, write, and search permissions to its owner; read and search permissions to its owning group; and no permissions to others. For a directory, search permission (`x`) allows traversal and lookup of entries by name. The owning group here is `labuser`, not the supplementary group `users`.

These observations establish the account's initial recorded memberships and the directory's ownership and mode.

## Supplementary Group Membership

After the group membership change, the lab owner ran:

```bash
id labuser
getent group labops
```

The commands returned, respectively:

```text
uid=1002(labuser) gid=1002(labuser) groups=1002(labuser),100(users),1003(labops)
labops:x:1003:labuser
```

The `labops` group has GID `1003` and lists `labuser` as a member. The account retained its primary group `labuser` (GID `1002`) and supplementary group `users` (GID `100`). These results verify the recorded memberships; functional testing is recorded below.

## Shared Directory and Authorized File Creation

The lab owner ran:

```bash
ls -ld /srv/lab-share
sudo -u labuser touch /srv/lab-share/labuser-test.txt
sudo -u labuser ls -l /srv/lab-share/labuser-test.txt
```

| Check | Observed result |
| --- | --- |
| Shared directory | `/srv/lab-share`, owned by `root:labops` |
| Directory permissions | `drwxrws---`, mode `2770` (setgid enabled) |
| File creation as `labuser` | `touch` reported no error; the subsequent listing showed the file |
| Test file | `/srv/lab-share/labuser-test.txt`, 0 bytes, owned by `labuser:labops` |
| File permissions | `-rw-r--r--`, mode `644` |

The authorized account successfully created a file in the shared directory. The file inherited the directory's group `labops`, while the account's primary group remained `labuser`, demonstrating setgid group inheritance for this operation.

The file's mode grants write permission only to its owner. Directory write permission and setgid do not themselves grant group members permission to edit an existing file's contents. Although the file has read permission for others, accessing it by path also requires search permission on the parent directories.

## Access Denial for an Account Outside the Group

The lab owner ran:

```bash
sudo adduser --disabled-password --comment "" labguest
sudo -u labguest id
```

The identity check returned:

```text
uid=1004(labguest) gid=1004(labguest) groups=1004(labguest),100(users)
```

This confirmed that the test process ran as `labguest`, with primary group `labguest` and supplementary group `users`, without membership in `labops`.

The lab owner then tested access and checked each exit status immediately afterward:

```bash
sudo -u labguest cat /srv/lab-share/labuser-test.txt
echo $?
sudo -u labguest touch /srv/lab-share/labguest-test.txt
echo $?
```

| Test | Observed result | Exit status |
| --- | --- | --- |
| Read the existing file with `cat` | `Permission denied` | `1` |
| Create or update the target path with `touch` | `Permission denied` | `1` |

Both operations were denied as intended. The existing file's `644` mode did not make it readable by this account through `/srv/lab-share`, whose `2770` mode grants no search permission to others. These are successful access-control checks, not unintended service failures.

## Controlled Permission Failure: Group Write Denied

The exercise requires `labuser`, a member of `labops`, to append text to a team file owned by `root:labops`. The lab owner inspected the file and attempted the write:

```bash
sudo ls -l /srv/lab-share/team-note.txt
sudo -u labuser sh -c 'echo "group write test" >> /srv/lab-share/team-note.txt'
echo $?
```

| Check | Observed result |
| --- | --- |
| File ownership | `root:labops` |
| File size before the write attempt | 0 bytes |
| File permissions | `-rw-r-----`, mode `640` |
| Append attempt as `labuser` | `sh: 1: cannot create /srv/lab-share/team-note.txt: Permission denied` |
| Exit status | `2` |

The file grants its owner `root` read and write access, while group `labops` has read access only. Since `labuser` is a group member rather than the file owner, the missing group-write bit blocks appending. The shared directory's `2770` permissions allow traversal and file creation by the group, but do not grant write permission to the contents of this existing file.

The failure occurred when the shell tried to open the file for the `>>` redirection. The observed exit status `2` indicates failure for this shell command; it is not a universal exit code for permission errors.

### Correction and Verification

The lab owner added group-write permission to the affected file and inspected the result:

```bash
sudo chmod g+w /srv/lab-share/team-note.txt
sudo ls -l /srv/lab-share/team-note.txt
```

The file remained owned by `root:labops`; its mode changed from `640` to `660` (`-rw-rw----`). The correction added group-write permission without changing ownership or granting permissions to others.

The lab owner repeated the append, read back the contents, and checked access as the account outside the group:

```bash
sudo -u labuser sh -c 'echo "group write test" >> /srv/lab-share/team-note.txt'
echo $?
sudo -u labuser cat /srv/lab-share/team-note.txt
sudo -u labguest cat /srv/lab-share/team-note.txt
echo $?
```

| Verification | Confirmed result |
| --- | --- |
| Append as `labuser` | Exit status `0` |
| Read back as `labuser` | Returned `group write test` |
| Read as `labguest` | `Permission denied`, exit status `1` |

**Scenario outcome:** Resolved. The group member can append to the team file, and the account outside the group remains unable to read it through the shared directory. This completes one controlled troubleshooting scenario; it does not establish a default group-write policy for all newly created files.
