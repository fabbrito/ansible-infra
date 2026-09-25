# 19. Unattended-upgrades is the only scheduled upgrader and rebooter

- Status: accepted

## Chosen

A converge never upgrades packages or reboots. The OS role configures unattended-upgrades — daily on a VM, weekly on a
board, a reboot when one is required at a per-host time — and adds the origins of the third-party repos the roles
install. The update play is the manual catch-up: serial, one host at a time.

## Why

A headless host nobody logs into has to keep itself patched, and the distribution's own upgrader already does that with
its policy and its logs. An upgrade inside the converge made every converge slow, made a dry-run lie about what would
change, and rebooted hosts at whatever hour someone ran it.

The reboot minute is seeded per host so a fleet never reboots at once, and stays stable so the render does not churn.

## Cost

A fix lands when the timer fires, not when the converge runs; waiting on it needs the update play. Our settings sit in a
drop-in beside the package's own files, so a later drop-in can override them — the role reads the effective values back
to catch that.

## Reverses

Upgrade in the converge again, or disable unattended-upgrades and schedule the update play. Both put upgrades back on
someone's calendar.
