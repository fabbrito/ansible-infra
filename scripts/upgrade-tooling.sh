#!/usr/bin/env bash
# Bump the pins: ./scripts/upgrade-tooling.sh [apply]
#
# mise and dprint bump their own pins, each skipping too-young releases;
# previews by default. Hand pins live in .config/upgrade-pins.tsv and only get
# a hint: a changelog to read first. `apply` refuses a dirty tree, bumps, then
# formats and gates. Needs curl and jq.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

apply=${1:-}
fail=0
pins='.config/upgrade-pins.tsv'

case $apply in
	'' | apply) ;;
	*)
		echo 'usage: upgrade-tooling.sh [apply]' >&2
		exit 1
		;;
esac

# sed script file: the value it captures. `-n` is implicit; the script prints.
pin() {
	sed -nE "$1" "$2"
}

# name current latest; an empty one is a failed lookup.
hint() {
	if [[ -z $2 || -z $3 ]]; then
		echo "  $1: lookup failed" >&2
		fail=1
	elif [[ ${2#v} != "${3#v}" ]]; then
		echo "  $1: $2 -> $3"
	fi
}

pypi_latest() {
	curl -fsS "https://pypi.org/pypi/$1/json" | jq -r .info.version
}

# The v3 collection endpoint redirects; -L is the API, not a nicety.
galaxy_latest() {
	curl -fsSL "https://galaxy.ansible.com/api/v3/plugin/ansible/content/\
published/collections/index/$1/versions/?limit=1&ordering=-version" |
		jq -r '.data[0].version'
}

# dprint takes mise's age as an ISO-8601 duration.
age=$(pin 's/^minimum_release_age = "([0-9]+)d".*/\1/p' mise.toml)
if [[ -z $age ]]; then
	echo 'upgrade-tooling: no minimum_release_age in days in mise.toml' >&2
	exit 1
fi
age=P${age}D

# The diff is the bumps: untracked files are in no diff.
if [[ -n $apply ]] &&
	[[ -n $(git status --porcelain --untracked-files=no) ]]; then
	echo 'upgrade-tooling: tracked files are dirty; commit first' >&2
	exit 1
fi

echo '==> mise'
if [[ -n $apply ]]; then
	mise upgrade --bump --local || fail=1
	# Global: every version no tracked config pins goes, not after grace.
	mise prune -y -q || fail=1
else
	mise outdated --bump --local || fail=1
fi

echo '==> dprint'
if [[ -n $apply ]]; then
	dprint config update --yes --reload=plugins \
		--minimum-dependency-age "$age" || fail=1
elif out=$(NO_COLOR=1 dprint config update --dry-run \
	--minimum-dependency-age "$age" 2>&1); then
	out=$(sed -n '/^Would update/p' <<<"$out")
	echo "${out:-All plugins are up to date}"
else
	echo "$out" >&2
	fail=1
fi

echo '==> by hand (hints only)'
# kind label file sed target extra-file extra-sed. `-` is an unused column.
while IFS=$'\t' read -r kind label file script target xfile xscript; do
	[[ -z $kind || $kind == '#'* ]] && continue
	case $kind in
		pypi)
			hint "$label" "$(pin "$script" "$file")" \
				"$(pypi_latest "$target")"
			;;
		galaxy)
			hint "$label" "$(pin "$script" "$file")" \
				"$(galaxy_latest "$target")"
			;;
		# The floor must not outrun the core the gate runs; only a violation
		# speaks, or every run would report the same gap.
		floor)
			cur=$(pin "$script" "$file")
			core=$(pin "$xscript" "$xfile")
			if [[ -z $cur || -z $core ]]; then
				echo "  $label: lookup failed" >&2
				fail=1
			elif [[ $cur != "$(printf '%s\n%s\n' "$cur" "$core" |
				sort -V | head -1)" ]]; then
				echo "  $label: $cur outruns core $core" >&2
				fail=1
			fi
			;;
		# Two hand-kept copies of one range, the pair that must move together.
		same)
			a=$(pin "$script" "$file")
			b=$(pin "$xscript" "$xfile")
			if [[ -z $a || -z $b ]]; then
				echo "  $label: lookup failed" >&2
				fail=1
			elif [[ $a != "$b" ]]; then
				echo "  $label: $file has $a, $xfile has $b" >&2
				fail=1
			fi
			;;
		*)
			echo "upgrade-tooling: $pins: unknown kind '$kind'" >&2
			exit 1
			;;
	esac
done <"$pins"

# A bump that breaks the tree is caught before the diff is offered.
if [[ -n $apply && $fail == 0 ]]; then
	make fmt check || fail=1
	if ((fail == 0)); then
		echo 'review the diff; then make deps'
	fi
fi

exit "$fail"
