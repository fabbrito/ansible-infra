# Where the seed goes

`playbooks/seed.yml` renders a host's cloud-init seed into `seed_output_dir`. It creates `deploy_user` with
`deploy_authorized_keys`, key-only, with passwordless sudo, so the first converge can connect without `bootstrap`.

```bash
ansible-playbook fabbrito.infra.seed -e target=<host> -e seed_output_dir=<dir>
```

The seed is read once, on first boot. Changing it later changes nothing on a running VM; on a board, bump
`seed_generation` and boot to apply it again.

## Board

`user-data` and `meta-data` go on the boot partition, beside `cmdline.txt`: copy them from `<dir>`, or point
`seed_output_dir` at the mounted partition. Raspberry Pi Imager's customisation writes `user-data` too, and would
overwrite ours or strip sudo from the user: skip it.

## VM

`user-data` only: the provider serves its own `meta-data`. Paste the file into the provider's user-data field when
creating the instance. The field is read at create time; most providers ignore an edit after that.

| Provider      | Console                                                    | CLI                                              |
| ------------- | ---------------------------------------------------------- | ------------------------------------------------ |
| AWS EC2       | Advanced details → User data                               | `aws ec2 run-instances --user-data`              |
| Google Cloud  | —                                                          | `gcloud … --metadata-from-file user-data=<file>` |
| Azure         | —                                                          | `az vm create --custom-data`                     |
| DigitalOcean  | Advanced options → Add initialization scripts              | `doctl … --user-data-file`                       |
| Vultr         | Additional features → Enable cloud-init user-data          | `vultr-cli … --userdata`                         |
| Linode        | Create Linode → Add user data                              | `linode-cli … --metadata.user_data`              |
| Oracle Cloud  | Create instance → Advanced options → Initialization script | —                                                |
| Hetzner Cloud | Create server → Cloud config                               | —                                                |

Source: Tailscale's [cloud-init guide](https://tailscale.com/docs/install/with-cloud-init), which lists the same fields.
Consoles move; if a label is gone, search the provider's docs for "user data" or "cloud-init".

## Checking it ran

On the host, as the provider's default user or `deploy_user`:

```bash
cloud-init status --long   # status: done; errors listed if any
id <deploy_user>           # the account exists
```

`preflight` asserts `cloud-init status` is `done` before any role runs, so a converge started too early fails there
rather than halfway.
