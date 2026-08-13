#!/usr/bin/env bash

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
SOURCE_ROOT="$REPO/skills"
BACKUP_ROOT="$REPO/plugins/gwyn-space-skills/skills"

source_skill_files=()
while IFS= read -r skill_md; do
	source_skill_files+=("$skill_md")
done < <(find "$SOURCE_ROOT" -name SKILL.md -not -path '*/node_modules/*' -print | LC_ALL=C sort)

backup_skill_files=()
while IFS= read -r skill_md; do
	backup_skill_files+=("$skill_md")
done < <(find "$BACKUP_ROOT" -name SKILL.md -not -path '*/node_modules/*' -print | LC_ALL=C sort)

contains_name() {
	local sought="$1"
	shift
	local candidate

	for candidate in "$@"; do
		if [ "$candidate" = "$sought" ]; then
			return 0
		fi
	done
	return 1
}

if [ "${#source_skill_files[@]}" -gt 0 ]; then
	for skill_md in "${source_skill_files[@]}"; do
		echo "${skill_md#"$REPO"/}"
	done
fi

echo
echo "Backup audit:"
echo "  source skills: ${#source_skill_files[@]}"
echo "  backup skills: ${#backup_skill_files[@]}"

source_names=()
backup_names=()
audit_failed=0

if [ "${#source_skill_files[@]}" -gt 0 ]; then
	for skill_md in "${source_skill_files[@]}"; do
		source_dir="${skill_md%/SKILL.md}"
		name="${source_dir##*/}"
		if [ "${#source_names[@]}" -gt 0 ] && contains_name "$name" "${source_names[@]}"; then
			echo "  duplicate source skill: $name"
			audit_failed=1
		else
			source_names+=("$name")
		fi
	done
fi

if [ "${#backup_skill_files[@]}" -gt 0 ]; then
	for skill_md in "${backup_skill_files[@]}"; do
		backup_dir="${skill_md%/SKILL.md}"
		name="${backup_dir##*/}"
		if [ "${backup_dir%/*}" != "$BACKUP_ROOT" ]; then
			echo "  unexpected backup path: ${skill_md#"$REPO"/}"
			audit_failed=1
		fi
		if [ "${#backup_names[@]}" -gt 0 ] && contains_name "$name" "${backup_names[@]}"; then
			echo "  duplicate backup skill: $name"
			audit_failed=1
		else
			backup_names+=("$name")
		fi
	done
fi

if [ "${#source_skill_files[@]}" -ne "${#backup_skill_files[@]}" ]; then
	echo "  skill count mismatch"
	audit_failed=1
fi

if [ "${#source_skill_files[@]}" -gt 0 ]; then
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
fi

if [ "${#backup_skill_files[@]}" -gt 0 ]; then
	for skill_md in "${backup_skill_files[@]}"; do
		backup_dir="${skill_md%/SKILL.md}"
		name="${backup_dir##*/}"
		if [ "${#source_names[@]}" -eq 0 ] || ! contains_name "$name" "${source_names[@]}"; then
			echo "  extra backup skill: $name"
			audit_failed=1
		fi
	done
fi

if [ "$audit_failed" -ne 0 ]; then
	echo "  status: FAILED"
	exit 1
fi

echo "  status: synchronized"
