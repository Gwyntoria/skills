#!/usr/bin/env bash

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_ROOT="$REPO/skills"
PLUGIN_ROOT="$REPO/plugins/gwyn-space-skills"
BACKUP_ROOT="$PLUGIN_ROOT/skills"

mapfile -d '' source_skill_files < <(
	find "$SOURCE_ROOT" -name SKILL.md -not -path '*/node_modules/*' -print0 | sort -z
)

if [ "${#source_skill_files[@]}" -eq 0 ]; then
	echo "error: no source skills found in $SOURCE_ROOT." >&2
	exit 1
fi

declare -A source_names=()
for skill_md in "${source_skill_files[@]}"; do
	source_dir="${skill_md%/SKILL.md}"
	name="${source_dir##*/}"
	if [[ -v "source_names[$name]" ]]; then
		echo "error: duplicate source skill name cannot be flattened: $name." >&2
		exit 1
	fi
	source_names["$name"]="$source_dir"
done

if [ ! -d "$PLUGIN_ROOT" ]; then
	echo "error: plugin directory does not exist: $PLUGIN_ROOT." >&2
	exit 1
fi

stage_root="$(mktemp -d "$PLUGIN_ROOT/.skills-sync.XXXXXX")"
previous_root="$stage_root.previous"
replacement_started=0
replacement_committed=0

cleanup() {
	status=$?
	trap - EXIT INT TERM
	set +e

	if [ "$status" -ne 0 ] && [ "$replacement_started" -eq 1 ] && [ "$replacement_committed" -eq 0 ]; then
		if [ -e "$previous_root" ] || [ -L "$previous_root" ]; then
			rm -rf -- "$BACKUP_ROOT"
			if mv -- "$previous_root" "$BACKUP_ROOT"; then
				echo "restored previous plugin skills after sync failure." >&2
			else
				echo "error: rollback failed; previous skills remain at $previous_root." >&2
			fi
		elif { [ ! -e "$stage_root" ] && [ ! -L "$stage_root" ]; } && { [ -e "$BACKUP_ROOT" ] || [ -L "$BACKUP_ROOT" ]; }; then
			# The staged directory became the target and there was no previous backup.
			rm -rf -- "$BACKUP_ROOT"
		fi
	fi

	if [ -e "$stage_root" ] || [ -L "$stage_root" ]; then
		rm -rf -- "$stage_root"
	fi
	if [ "$replacement_committed" -eq 1 ] && { [ -e "$previous_root" ] || [ -L "$previous_root" ]; }; then
		rm -rf -- "$previous_root"
	fi

	exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Build and verify the flattened mirror before replacing the current backup.
for skill_md in "${source_skill_files[@]}"; do
	source_dir="${skill_md%/SKILL.md}"
	name="${source_dir##*/}"
	cp -a -- "$source_dir" "$stage_root/$name"
	if ! diff -qr "$source_dir" "$stage_root/$name"; then
		echo "error: staged copy verification failed for $name." >&2
		exit 1
	fi
done

replacement_started=1
if [ -e "$BACKUP_ROOT" ] || [ -L "$BACKUP_ROOT" ]; then
	mv -- "$BACKUP_ROOT" "$previous_root"
fi

mv -- "$stage_root" "$BACKUP_ROOT"

# Reuse the repository audit as the final synchronization contract.
if ! "$REPO/scripts/list-skills.sh"; then
	echo "error: synchronized plugin skills failed the backup audit." >&2
	exit 1
fi

replacement_committed=1
if [ -e "$previous_root" ] || [ -L "$previous_root" ]; then
	rm -rf -- "$previous_root"
fi

echo "synced ${#source_skill_files[@]} skills to ${BACKUP_ROOT#"$REPO"/}"
