#!/usr/bin/env bash
# sync.sh — update this guide to the latest upstream.
#
# Preview what changed, stash any local edits, fast-forward-only pull, restore edits.
# Never force-merges; if upstream diverged from your local commits it stops and tells
# you, so your changes are never silently clobbered.
#
#   ./sync.sh             # preview the incoming diff, confirm, then pull
#   ./sync.sh --dry-run   # just show what WOULD change, do nothing
#   ./sync.sh --yes       # skip the confirmation prompt
set -euo pipefail

DRY=0; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift;;
    --yes|-y)  YES=1; shift;;
    -h|--help) sed -n '2,12p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

cd "$(dirname "$0")"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo"; exit 1; }

branch="$(git branch --show-current)"
echo "Fetching origin/$branch …"
git fetch --quiet origin "$branch"

if git diff --quiet HEAD "origin/$branch" --; then
  echo "Already up to date."
  exit 0
fi

echo
echo "Incoming changes (origin/$branch):"
git --no-pager log --oneline --no-decorate "HEAD..origin/$branch" | sed 's/^/  /'
echo
git --no-pager diff --stat "HEAD..origin/$branch" | sed 's/^/  /'
echo

if [ "$DRY" = 1 ]; then
  echo "(--dry-run: nothing changed)"
  exit 0
fi

if [ "$YES" != 1 ]; then
  printf "Apply these updates? [y/N] "
  read -r ans
  case "$ans" in y|Y|yes|YES) ;; *) echo "aborted."; exit 0;; esac
fi

stashed=0
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Stashing your local edits …"
  git stash push -u -m "sync.sh auto-stash" >/dev/null
  stashed=1
fi

echo "Fast-forward pull …"
if git merge --ff-only "origin/$branch"; then
  echo "Updated to $(git rev-parse --short HEAD)."
else
  echo "✗ Cannot fast-forward — your branch has diverged from upstream."
  echo "  Resolve manually (git rebase origin/$branch) — nothing was overwritten."
  [ "$stashed" = 1 ] && { echo "  Restoring your stash …"; git stash pop || true; }
  exit 1
fi

if [ "$stashed" = 1 ]; then
  echo "Restoring your local edits …"
  git stash pop || { echo "  Stash conflicted — resolve, then 'git stash drop'."; exit 1; }
fi

echo "Done. (If templates changed, re-check any personas you scaffolded earlier.)"
