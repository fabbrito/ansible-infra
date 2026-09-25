# 18. The seed creates the deploy user, and on a board it is the break-glass

- Status: accepted

## Chosen

A cloud-init seed, rendered from the consumer's inventory, is the alternative to the bootstrap play: it creates the
deploy user, key-only, with passwordless sudo. A VM gets user-data for the provider and keeps the provider's default
user. A board gets user-data and meta-data for its boot partition, and its seed doubles as the break-glass: edit it,
bump its generation, boot, and cloud-init applies it again.

The seed is deterministic: the same inventory renders the same bytes, and a board's instance identity is its name plus
the generation. A hand-made seed is as valid as ours if the host ends in the same state; the converge asserts the
outcome — cloud-init finished, key-only SSH — and never reads the seed back.

## Why

A board has no provider console and no injected key, so the seed is the only first contact and the only way back. That
rules out disabling cloud-init and a root SSH key on a board: either would remove it. A VM already has the provider's
way back, so its default user stays and our user is added beside it.

A timestamp identity lost: it would re-apply the seed on every accidental regeneration and churn every golden render.

## Cost

Break-glass on a board needs physical access to the card. A VM carries two sudo-capable accounts. The seed is read once,
so changing it later changes nothing on a running VM.

## Reverses

Drop the seed and bootstrap every host over the provider's root key — which a board does not have — or disable
cloud-init after first boot and give up the board's way back.
