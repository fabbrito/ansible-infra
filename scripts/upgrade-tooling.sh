#!/usr/bin/env bash
# Bump the pins: ./scripts/upgrade-tooling.sh [apply|major]
#
# mise and dprint bump their own pins, each skipping too-young releases;
# previews by default. Image tags follow their registry to the highest tag
# shaped like the pinned one, once its build is as old; a major bump is held
# (a 0.x minor counts) unless `major`. Other hand pins live in
# .config/upgrade-pins.tsv and only get a hint: a changelog to read first.
# `apply` refuses a dirty tree, bumps, then formats and gates. Needs curl, jq
# and crane.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

apply=${1:-}
fail=0
pins='.config/upgrade-pins.tsv'

case $apply in
	'' | apply | major) ;;
	*)
		echo 'usage: upgrade-tooling.sh [apply|major]' >&2
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

github_latest() {
	curl -fsS "https://api.github.com/repos/$1/releases/latest" |
		jq -r .tag_name
}

# A project whose registry tag carries no `v`, unlike its release tag.
github_nov_latest() {
	github_latest "$1" | sed 's/^v//'
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
age_days=$age
age=P${age}D
min_age_s=$((age_days * 86400))
now=$(date +%s)

# version: its breaking-change series - the leading number, or for 0.x the
# minor too, since 0.x minors break.
series() {
	local v=${1#v}
	if [[ ${v%%.*} == 0 ]]; then
		echo "${v%.*}"
	else
		echo "${v%%.*}"
	fi
}

# version...: the highest, by version sort.
newest() {
	printf '%s\n' "$@" | sort -V | tail -n 1
}

# tag: an anchored regex for tags of its shape. Digit runs vary, the rest is
# literal: `v` and `-alpine` stay, `latest` and `-rc1` fall out.
tag_regex() {
	local re=${1//./\\.}
	re=$(sed -E 's/[0-9]+/[0-9]+/g' <<<"$re")
	echo "^$re\$"
}

# repo tag: the highest tag of tag's shape.
latest_tag() {
	local re t tags=()
	re=$(tag_regex "$2")
	while IFS= read -r t; do
		[[ $t =~ $re ]] && tags+=("$t")
	done < <(crane ls "$1")
	((${#tags[@]})) || return 1
	newest "${tags[@]}"
}

# file var old new: the var's value in file. Matched by var, since the hub
# and the agent share a number.
set_var() {
	sed -i -E "s/^($2: \"?)$3(\"?)( |\$)/\1$4\2\3/" "$1"
}

# label repo cur file var: bump one image tag, or follow with `-` as repo.
# Prints the tag it settled on in `picked`.
declare -A picked
bump_image() {
	local label=$1 repo=$2 cur=$3 file=$4 var=$5 new=${6:-} config created ts src
	if [[ -z $new ]]; then
		if ! new=$(latest_tag "$repo" "$cur"); then
			echo "  $label: no tags shaped like $cur" >&2
			fail=1
			return
		fi
	fi
	picked[$label]=$cur
	[[ $(newest "$cur" "$new") != "$cur" ]] || return
	if ! config=$(crane config "$repo:$new"); then
		echo "  $label: $repo:$new has no config" >&2
		fail=1
		return
	fi
	created=$(jq -r '.created // empty' <<<"$config")
	src=$(jq -r '.config.Labels["org.opencontainers.image.source"] // empty' \
		<<<"$config")
	if ! ts=$(date -d "$created" +%s 2>/dev/null); then
		echo "  $label: $repo:$new unreadable build date '$created'" >&2
		fail=1
		return
	fi
	local note=''
	[[ $(series "$cur") != "$(series "$new")" ]] && note=' (major)'
	echo "  $label: $cur -> $new$note${src:+ $src}"
	picked[$label]=$new
	[[ -n $apply ]] || return
	if [[ -n $note && $apply != major ]]; then
		echo "  $label: major, held"
		picked[$label]=$cur
	elif ((now - ts < min_age_s)); then
		echo "  $label: younger than ${age_days}d, skipped"
		picked[$label]=$cur
	else
		set_var "$file" "$var" "$cur" "$new"
	fi
}

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

if [[ -n $(sed -n '/^\(image\|follow\)\t/p' "$pins") ]] &&
	! crane version >/dev/null 2>&1; then
	echo "upgrade-tooling: needs crane (mise's: make deps)" >&2
	exit 1
fi

echo '==> by hand and images'
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
		github)
			hint "$label" "$(pin "$script" "$file")" \
				"$(github_latest "$target")"
			;;
		github-nov)
			hint "$label" "$(pin "$script" "$file")" \
				"$(github_nov_latest "$target")"
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
		# Registry tags; xscript names the var to rewrite.
		image)
			bump_image "$label" "$target" "$(pin "$script" "$file")" \
				"$file" "$xscript"
			;;
		# Rides its leader's tag (xfile), held when it is held: one release.
		follow)
			cur=$(pin "$script" "$file")
			lead=${picked[$xfile]:-}
			if [[ -z $lead ]]; then
				echo "  $label: leader $xfile did not run" >&2
				fail=1
			elif [[ $lead != "$cur" ]] &&
				! crane manifest "$target:$lead" >/dev/null 2>&1; then
				echo "  $label: $target has no $lead, held" >&2
				fail=1
			else
				bump_image "$label" "$target" "$cur" "$file" "$xscript" "$lead"
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
