#!/usr/bin/env bash

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_ROOT="$REPO/skills"
BACKUP_ROOT="$REPO/plugins/gwyn-space-skills/skills"

mapfile -d '' source_skill_files < <(
	find "$SOURCE_ROOT" -name SKILL.md -not -path '*/node_modules/*' -print0 | sort -z
)
mapfile -d '' backup_skill_files < <(
	find "$BACKUP_ROOT" -name SKILL.md -not -path '*/node_modules/*' -print0 | sort -z
)

for skill_md in "${source_skill_files[@]}"; do
	echo "${skill_md#"$REPO"/}"
done

echo
echo "Backup audit:"
echo "  source skills: ${#source_skill_files[@]}"
echo "  backup skills: ${#backup_skill_files[@]}"

declare -A source_dirs=()
declare -A backup_dirs=()
audit_failed=0

for skill_md in "${source_skill_files[@]}"; do
	source_dir="${skill_md%/SKILL.md}"
	name="${source_dir##*/}"
	if [[ -v "source_dirs[$name]" ]]; then
		echo "  duplicate source skill: $name"
		audit_failed=1
	else
		source_dirs["$name"]="$source_dir"
	fi
done

for skill_md in "${backup_skill_files[@]}"; do
	backup_dir="${skill_md%/SKILL.md}"
	name="${backup_dir##*/}"
	if [ "${backup_dir%/*}" != "$BACKUP_ROOT" ]; then
		echo "  unexpected backup path: ${skill_md#"$REPO"/}"
		audit_failed=1
	fi
	if [[ -v "backup_dirs[$name]" ]]; then
		echo "  duplicate backup skill: $name"
		audit_failed=1
	else
		backup_dirs["$name"]="$backup_dir"
	fi
done

if [ "${#source_skill_files[@]}" -ne "${#backup_skill_files[@]}" ]; then
	echo "  skill count mismatch"
	audit_failed=1
fi

for skill_md in "${source_skill_files[@]}"; do
	source_dir="${skill_md%/SKILL.md}"
	name="${source_dir##*/}"
	backup_dir="$BACKUP_ROOT/$name"
	if [ ! -f "$backup_dir/SKILL.md" ]; then
		echo "  missing backup skill: $name"
		audit_failed=1
		continue
	fi
	if ! diff_output="$(diff -qr "$source_dir" "$backup_dir" 2>&1)"; then
		echo "  content mismatch: $name"
		while IFS= read -r line; do
			echo "    $line"
		done <<< "$diff_output"
		audit_failed=1
	fi
done

for skill_md in "${backup_skill_files[@]}"; do
	backup_dir="${skill_md%/SKILL.md}"
	name="${backup_dir##*/}"
	if [[ ! -v "source_dirs[$name]" ]]; then
		echo "  extra backup skill: $name"
		audit_failed=1
	fi
done

if [ "$audit_failed" -ne 0 ]; then
	echo "  status: FAILED"
	exit 1
fi

echo "  status: synchronized"
