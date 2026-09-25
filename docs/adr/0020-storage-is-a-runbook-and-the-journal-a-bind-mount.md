# 20. Storage is a runbook; the journal moves by bind mount

- Status: accepted

## Chosen

Attaching a storage volume is a manual, one-time operator step: partition, format, mount by filesystem UUID with nofail,
and make the empty mount point immutable. No role formats or mounts a volume.

The journal role, opt-in, bind-mounts a directory on the volume over the journal's persistent location and asks journald
to persist. It asserts the volume mounted first, and reads back that the journal sits on the volume's device.

## Why

Formatting is the dangerous half, and the operator has to choose the disk anyway; a role would automate only the part
that can erase the wrong one. Mounting by UUID survives a port change; nofail keeps a headless board booting without the
volume; the immutable mount point makes writes fail, not land on the card, while it is absent.

journald has no setting for its storage directory, so a bind mount is the only way to move it. With the volume absent
the mount fails and journald stays in memory, which is the safe side.

## Cost

A volume is a manual step per host. Journal files kept before the move are hidden under the mount until copied.

## Reverses

A role that formats and mounts, with the operator's disk choice as input; or drop the journal role and leave the journal
where the image puts it.
