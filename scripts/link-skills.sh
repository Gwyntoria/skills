#!/usr/bin/env bash

set -euo pipefail
# NOTE: This is a dev-only script, intended for use by maintainers of this repo.
# It is not a supported installer. Modifications to it — or requests for
# modifications — will not be approved.
#
# Links all skills in the repository into ~/.agents/skills by default.
# Pass --claude to also link them into ~/.claude/skills, or --codex to link
# them only into ~/.codex/skills and remove matching entries from ~/.agents.
# Each entry is a symlink into this repo, so a `git pull` is all that's needed
# to keep installed skills up to date.

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
# Tests can isolate link destinations without changing the maintainer's home.
LINK_HOME="${SKILLS_LINK_HOME:-$HOME}"
AGENTS_DEST="$LINK_HOME/.agents/skills"
mode="agents"
for arg in "$@"; do
	case "$arg" in
	--claude)
		if [ "$mode" = "codex" ]; then
			echo "error: --claude and --codex cannot be used together." >&2
			exit 2
		fi
		mode="claude"
		;;
	--codex)
		if [ "$mode" = "claude" ]; then
			echo "error: --claude and --codex cannot be used together." >&2
			exit 2
		fi
		mode="codex"
		;;
	*)
		echo "usage: $0 [--claude | --codex]" >&2
		exit 2
		;;
	esac
done

case "$mode" in
claude)
	DESTS=("$AGENTS_DEST" "$LINK_HOME/.claude/skills")
	;;
codex)
	DESTS=("$LINK_HOME/.codex/skills")
	;;
*)
	DESTS=("$AGENTS_DEST")
	;;
esac

ensure_destination_is_safe() {
	local dest="$1"
	local resolved

	if [ ! -L "$dest" ]; then
		return
	fi

	if ! resolved="$(cd -P "$dest" 2>/dev/null && pwd -P)"; then
		echo "error: cannot resolve destination symlink: $dest" >&2
		exit 1
	fi
	case "$resolved" in
	"$REPO"|"$REPO"/*)
		echo "error: $dest is a symlink into this repo ($resolved)." >&2
		echo "Remove it (rm \"$dest\") and re-run." >&2
		exit 1
		;;
	esac
}

# Collect the repo's skills once, link into every destination.
names=()
srcs=()
while IFS= read -r -d '' skill_md; do
	src="$(dirname "$skill_md")"
	names+=("$(basename "$src")")
	srcs+=("$src")
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -print0)

if [ "$mode" = "codex" ]; then
	# Validate the cleanup destination before creating any Codex links.
	ensure_destination_is_safe "$AGENTS_DEST"
fi

for DEST in "${DESTS[@]}"; do
	# If $DEST is a symlink that resolves into this repo, we'd end up writing the
	# per-skill symlinks back into the repo's own skills/ tree. Detect and bail
	# out instead of polluting the working copy.
	ensure_destination_is_safe "$DEST"

	mkdir -p "$DEST"
	for i in "${!names[@]}"; do
		name="${names[$i]}"
		src="${srcs[$i]}"
		target="$DEST/$name"
		if [ -e "$target" ] && [ ! -L "$target" ]; then
			rm -rf "$target"
		fi
		ln -sfn "$src" "$target"
		echo "linked $name -> $src ($DEST)"
	done
done

if [ "$mode" = "codex" ]; then
	# Codex uses its own skill directory, so remove matching shared skill entries.
	for name in "${names[@]}"; do
		target="$AGENTS_DEST/$name"
		if [ -e "$target" ] || [ -L "$target" ]; then
			rm -rf -- "$target"
			echo "removed $target"
		fi
	done
fi
