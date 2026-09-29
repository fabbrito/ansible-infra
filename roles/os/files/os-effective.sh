#!/usr/bin/env bash
# The os role's effective state, read back from the host: key=value lines.
# Labeled, so a probe that prints nothing cannot shift the others. Read-only;
# run through ansible.builtin.script, so nothing stays on the host.
#
#   os-effective.sh <swap file>

swap_file=$1

# What the next boot applies: systemd-sysctl's merged config, last assignment
# wins. The runtime value says nothing about the next boot.
boot_sysctl() {
	local want=$1
	local line key value=
	while IFS= read -r line; do
		[[ $line == *=* && $line != [#\;]* ]] || continue
		key=${line%%=*}
		key=${key//[[:space:]]/}
		# A leading `-` only tells systemd-sysctl to ignore a failure.
		key=${key#-}
		[[ $key == "$want" ]] || continue
		value=${line#*=}
		value=${value//[[:space:]]/}
	done < <(/usr/lib/systemd/systemd-sysctl --cat-config)
	echo "$value"
}

swap=0
while read -r name _; do
	[[ $name == "$swap_file" ]] && swap=$((swap + 1))
done </proc/swaps

printf '%s=%s\n' \
	swap "$swap" \
	boot_swappiness "$(boot_sysctl vm.swappiness)" \
	boot_vfs_cache_pressure "$(boot_sysctl vm.vfs_cache_pressure)" \
	timezone "$(timedatectl show --property=Timezone --value)" \
	reboot "$(apt-config dump Unattended-Upgrade::Automatic-Reboot-Time)" \
	ntp "$(timedatectl show-timesync --property=SystemNTPServers --value)"
