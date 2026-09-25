# 17. Hosts are Debian-family VMs or boards, and the host says which

- Status: accepted

## Chosen

A host is a Debian-family machine on systemd: Ubuntu or Debian at or above a per-distribution floor, Raspberry Pi OS
passing as Debian. The consumer declares each host a VM or a board. A pre-flight role refuses anything else before
another role changes the host.

Architecture means the userland, as the package manager reports it; packages install for that. ARMv6 is refused on the
kernel's architecture, the one fact that tells the truth there. Board-only work keys on the declared kind, and a board's
hostname must match its inventory name unless the consumer opts out.

## Why

Ansible reports Raspberry Pi OS as Debian, so a gate on the distribution alone would refuse the reference board; the
family plus a floor is what the roles actually depend on. The userland and the kernel disagree on a 64-bit kernel with a
32-bit userland, and only the userland decides which package installs. A Raspberry Pi OS userland reads the same on
ARMv6, where nothing here builds, so that one check reads the kernel.

The kind is declared, not detected: a wrong guess changes the SSH root policy. A device-tree probe only confirms a
declared board.

A card flashed for another board otherwise converges silently as the wrong board, hence the hostname check.

## Cost

A consumer sets one more var on every host. Debian is claimed on its floor and untested. An inventory keyed by address
must turn the hostname check off.

## Reverses

Drop the declared kind and detect it, accepting the misreads; or narrow to one distribution and assert it by name.
