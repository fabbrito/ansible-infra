# Persistent USB storage

Attach a USB stick so it mounts at the same path on every boot, in any port, and so its absence is loud. Application
state — databases, files, logs — goes on the stick; the SD card keeps the OS.

This is a one-time manual step per stick. The collection neither formats nor mounts storage.

## What keeps it predictable

- **Filesystem UUID.** It lives in the filesystem, so ports and `/dev/sdX` order do not matter. Reformatting makes a new
  UUID: a new volume.
- **`nofail` in `/etc/fstab`.** The mount is wanted, not required, by boot (`systemd.mount(5)`). Without it a missing
  stick stops boot in emergency mode, and a headless board is unreachable.
- **An immutable mount point.** While the stick is absent, writes to the path fail instead of landing on the SD card.
- **`RequiresMountsFor=` in services.** A service does not start without its mount.

## 1. Identify the stick

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS
```

Run it before and after plugging the stick in; the new disk (usually `sda`) is the stick. Check `SIZE` and `MODEL`: the
next step erases it. `mmcblk0` is the SD card.

## 2. Partition and format

Erases the stick.

```bash
sudo wipefs -a /dev/sdX
echo 'type=linux' | sudo sfdisk --label gpt /dev/sdX
sudo mkfs.ext4 -L data /dev/sdX1
sudo blkid -s UUID -o value /dev/sdX1
```

ext4 for ownership and permissions, locks SQLite relies on, and journal recovery after a power cut. `sfdisk` ships in
the `fdisk` package.

## 3. Create the mount point

```bash
sudo mkdir -p /srv/data
sudo chattr +i /srv/data
```

`chattr +i` marks the empty directory underneath; the stick's filesystem, once mounted over it, stays writable.

Mount only over an empty directory. A mount hides what was there: a stick on `/home` hides `~/.ssh/authorized_keys` and
locks you out.

## 4. Add it to fstab

```
UUID=<uuid>  /srv/data  ext4  defaults,noatime,nofail  0  2
```

- `noatime`: reads do not write.
- `nofail`: boot continues without the stick.
- `2`: fsck at boot. systemd treats the field as yes/no (`systemd-fstab-generator(8)`).

```bash
sudo systemctl daemon-reload
sudo mount /srv/data
sudo chown <user>:<user> /srv/data
```

`chown` after mounting sets the stick's root directory, so ownership travels with the stick.

## 5. Verify

```bash
findmnt /srv/data   # SOURCE is the stick, OPTIONS include noatime
```

1. Reboot: mounted again.
2. Power off, move the stick to another port, boot: same path.
3. Power off, remove the stick, boot: the board is reachable, `findmnt /srv/data` prints nothing, and
   `touch /srv/data/x` fails with "Operation not permitted".

Plugged back in after boot, the stick mounts with `sudo mount /srv/data`, a reboot, or a service that requires it.

## 6. Make services depend on it

```ini
[Unit]
RequiresMountsFor=/srv/data
```

Starting the service pulls the mount in; without the stick the service fails to start rather than writing elsewhere.

## Removing a stick

```bash
sudo umount /srv/data
sudoedit /etc/fstab   # delete its line
sudo systemctl daemon-reload
sudo chattr -i /srv/data && sudo rmdir /srv/data
```
