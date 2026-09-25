# Oracle Cloud

What differs on an OCI instance running an Ubuntu platform image. Set `host_kind: vm`.

## Ingress

The VCN's security list, or a network security group on the instance, is the firewall: open 22, and 80/443 on an edge
host. Traffic it drops never reaches the host.

## The seed

Create instance → Advanced options → Initialization script takes the seed's `user-data`
([where the seed goes](../seed/where-the-seed-goes.md)). The image's `ubuntu` user stays as break-glass.

## No `firewall`, no `fail2ban`

The platform image ships iptables rules in `/etc/iptables/rules.v4`, restored at boot by `netfilter-persistent`. Among
them are the rules that let the instance reach its boot and block volumes. Oracle's
[known issues](https://docs.oracle.com/en-us/iaas/Content/Compute/known-issues.htm) say not to use ufw: it can drop
those rules, and the next reboot cannot reach the boot volume. On noble, installing `ufw` also removes
`netfilter-persistent`, which its package `Breaks`.

So leave both roles out of the plays for OCI hosts:

- `firewall` refuses a host with `netfilter-persistent` installed, before it installs ufw.
- `fail2ban` bans through ufw and refuses a host where ufw is inactive.

A host port beyond the image's rules goes into `/etc/iptables/rules.v4`, applied with
`sudo iptables-restore < /etc/iptables/rules.v4`. That file is the consumer's to manage.
