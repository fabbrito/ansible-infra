# 20. Storage is a runbook; the journal moves by bind mount

- Status: accepted

## Chosen

Attaching a storage volume is a manual, one-time operator step: partition, format, mount by filesystem UUID with nofail,
and make the empty mount point immutable. No role formats or mounts a volume.

The journal role, opt-in, bind-mounts a directory on the volume over the journal's persistent location and asks journald
to persist. It asserts the volume mounted first, and reads back that the journal sits on the volume's device.

A host with no volume can keep the journal on its root disk instead, but only by naming that mode. An unset volume path
is still refused, never read as the root disk. Switching to the root disk removes the bind mount.

## Why

Formatting is the dangerous half, and the operator has to choose the disk anyway; a role would automate only the part
that can erase the wrong one. Mounting by UUID survives a port change; nofail keeps a headless board booting without the
volume; the immutable mount point makes writes fail, not land on the card, while it is absent.

journald has no setting for its storage directory, so a bind mount is the only way to move it. With the volume absent
the mount fails and journald stays in memory, which is the safe side.

A small board with no volume still wants logs that survive a reboot, and the card holds them: journald caps itself at a
share of the filesystem. Naming the mode keeps the refusal's point, that the journal never lands on the card by
accident.

## Cost

A volume is a manual step per host. Journal files kept before the move are hidden under the mount until copied.

Root-disk mode writes to the card, and wears it. Files kept on a volume stay there after a switch to the root disk.

## Reverses

A role that formats and mounts, with the operator's disk choice as input; or drop the journal role and leave the journal
where the image puts it. Dropping root-disk mode hands that case back to the consumer.
