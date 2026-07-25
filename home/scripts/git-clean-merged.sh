#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not inside a Git repository." >&2
  exit 1
fi

current_branch=$(git branch --show-current)

if [[ $# -gt 1 ]]; then
  echo "Usage: git-clean-merged [base-branch]" >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  base_branch=$1
else
  remote_head=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  base_branch=${remote_head#origin/}

  if [[ -z $base_branch ]]; then
    if git show-ref --verify --quiet refs/heads/main; then
      base_branch=main
    elif git show-ref --verify --quiet refs/heads/master; then
      base_branch=master
    else
      echo "Error: could not detect the default branch." >&2
      echo "Pass it explicitly: git-clean-merged <base-branch>" >&2
      exit 1
    fi
  fi
fi

if ! git show-ref --verify --quiet "refs/heads/$base_branch"; then
  echo "Error: local base branch '$base_branch' does not exist." >&2
  exit 1
fi

mapfile -t merged_branches < <(
  git for-each-ref \
    --format='%(refname:short)' \
    --merged="$base_branch" \
    refs/heads/ |
    while IFS= read -r branch; do
      if [[ $branch != "$base_branch" && $branch != "$current_branch" ]]; then
        printf '%s\n' "$branch"
      fi
    done
)

if [[ ${#merged_branches[@]} -eq 0 ]]; then
  echo "No local branches are merged into '$base_branch'."
  exit 0
fi

echo "Found ${#merged_branches[@]} local branch(es) merged into '$base_branch'."
echo "This uses your local '$base_branch'; update it first if needed."

delete_all=false
deleted=0
skipped=0

for branch in "${merged_branches[@]}"; do
  printf '\n\033[1;36mBranch: %s\033[0m\n' "$branch"
  git for-each-ref \
    --format='Tip: %(objectname:short) | %(authordate:short) (%(authordate:relative)) | %(authorname) | %(subject)' \
    "refs/heads/$branch"

  merge_info=$(git log "$base_branch" \
    --first-parent --merges --ancestry-path --reverse \
    --format='%h | %ad (%ar) | %an | %s' --date=short \
    "$branch..$base_branch" | head -n 1 || true)

  if [[ -n $merge_info ]]; then
    echo "Merge: $merge_info"
  else
    echo "Merge: no merge commit found (likely fast-forwarded or merged indirectly)"
  fi

  echo "Recent commits reachable from the branch tip:"
  git log -n 3 --color=always \
    --pretty=format:'  %C(auto)%h%Creset %ad (%ar) | %an | %s' \
    --date=short "$branch"
  printf '\n'

  if [[ $delete_all == true ]]; then
    response=y
  else
    read -r -p "Delete '$branch'? [y]es/[N]o/[a]ll/[q]uit: " response
  fi

  case $response in
    y | Y | yes | YES)
      git branch -d -- "$branch"
      ((deleted += 1))
      ;;
    a | A | all | ALL)
      delete_all=true
      git branch -d -- "$branch"
      ((deleted += 1))
      ;;
    q | Q | quit | QUIT)
      echo "Stopped. Deleted $deleted; skipped $skipped."
      exit 0
      ;;
    *)
      echo "Skipped."
      ((skipped += 1))
      ;;
  esac
done

echo
echo "Done. Deleted $deleted; skipped $skipped."
