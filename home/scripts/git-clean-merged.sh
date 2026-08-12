#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

usage() {
  cat >&2 <<'EOF'
Usage: git-clean-merged [--no-fetch] [--local] [base-branch]

Interactively delete local branches that are already merged into the base
branch (default: main). Detects squash- and rebase-merged branches in
addition to true merges.

  --no-fetch  skip the initial `git fetch --prune`
  --local     compare against the local base branch instead of its remote
EOF
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not inside a Git repository." >&2
  exit 1
fi

do_fetch=true
use_local=false
base_branch=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-fetch) do_fetch=false ;;
    --local) use_local=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "Error: unknown option '$1'." >&2
      usage
      exit 2
      ;;
    *)
      if [[ -n $base_branch ]]; then
        echo "Error: too many arguments." >&2
        usage
        exit 2
      fi
      base_branch=$1
      ;;
  esac
  shift
done

current_branch=$(git branch --show-current)

if [[ -z $base_branch ]]; then
  if git show-ref --verify --quiet refs/heads/main; then
    base_branch=main
  elif git show-ref --verify --quiet refs/heads/master; then
    base_branch=master
  else
    remote_head=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
    base_branch=${remote_head#origin/}
  fi

  if [[ -z $base_branch ]]; then
    echo "Error: could not detect the default branch." >&2
    echo "Pass it explicitly: git-clean-merged <base-branch>" >&2
    exit 1
  fi
fi

if ! git show-ref --verify --quiet "refs/heads/$base_branch"; then
  echo "Error: local base branch '$base_branch' does not exist." >&2
  exit 1
fi

# Prefer the remote's view of the base branch: a stale local base branch is the
# most common reason merged branches go undetected.
remote=$(git config --get "branch.$base_branch.remote" || echo origin)
base_ref="$base_branch"

if [[ $use_local == false ]] && git show-ref --verify --quiet "refs/remotes/$remote/$base_branch"; then
  if [[ $do_fetch == true ]]; then
    echo "Fetching $remote..."
    git fetch --prune "$remote"
  fi
  base_ref="$remote/$base_branch"
fi

echo "Comparing against '$base_ref'."

merged_branches=()
merged_kinds=()

while IFS= read -r branch; do
  [[ $branch == "$base_branch" || $branch == "$current_branch" ]] && continue

  if git merge-base --is-ancestor "$branch" "$base_ref"; then
    merged_branches+=("$branch")
    merged_kinds+=(merged)
    continue
  fi

  # Squash/rebase detection: replay the branch's tree as a single commit on top
  # of the merge base and ask whether that change is already in the base ref.
  merge_base=$(git merge-base "$base_ref" "$branch")
  tree=$(git rev-parse "$branch^{tree}")

  if [[ $tree == "$(git rev-parse "$merge_base^{tree}")" ]]; then
    # No content difference from the merge base at all.
    merged_branches+=("$branch")
    merged_kinds+=(squashed)
    continue
  fi

  probe=$(git commit-tree "$tree" -p "$merge_base" -m "probe: $branch")

  if [[ $(git cherry "$base_ref" "$probe") == -* ]]; then
    merged_branches+=("$branch")
    merged_kinds+=(squashed)
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

if [[ ${#merged_branches[@]} -eq 0 ]]; then
  echo "No local branches are merged into '$base_ref'."
  exit 0
fi

echo "Found ${#merged_branches[@]} local branch(es) merged into '$base_ref'."

delete_all=false
deleted=0
skipped=0

for i in "${!merged_branches[@]}"; do
  branch=${merged_branches[i]}
  kind=${merged_kinds[i]}

  printf '\n\033[1;36mBranch: %s\033[0m\n' "$branch"
  git for-each-ref \
    --format='Tip: %(objectname:short) | %(authordate:short) (%(authordate:relative)) | %(authorname) | %(subject)' \
    "refs/heads/$branch"

  if [[ $kind == merged ]]; then
    merge_info=$(git log "$base_ref" \
      --first-parent --merges --ancestry-path --reverse \
      --format='%h | %ad (%ar) | %an | %s' --date=short \
      "$branch..$base_ref" | head -n 1 || true)

    if [[ -n $merge_info ]]; then
      echo "Merge: $merge_info"
    else
      echo "Merge: fully contained in '$base_ref' (fast-forwarded or merged indirectly)"
    fi
  else
    echo "Merge: squash- or rebase-merged (its changes are already in '$base_ref')"
  fi

  echo "Recent commits reachable from the branch tip:"
  git log -n 3 --color=always \
    --pretty=format:'  %C(auto)%h%Creset %ad (%ar) | %an | %s' \
    --date=short "$branch"
  printf '\n'

  if [[ $delete_all == true ]]; then
    response=y
  elif ! read -r -p "Delete '$branch'? [y]es/[N]o/[a]ll/[q]uit: " response; then
    printf '\n'
    echo "Stopped. Deleted $deleted; skipped $skipped."
    exit 0
  fi

  case $response in
    a | A | all | ALL)
      delete_all=true
      response=y
      ;;
    q | Q | quit | QUIT)
      echo "Stopped. Deleted $deleted; skipped $skipped."
      exit 0
      ;;
  esac

  case $response in
    y | Y | yes | YES)
      # -d refuses squash-merged branches, since they are not ancestors of the
      # base ref; we already verified their contents landed, so force those.
      if [[ $kind == merged ]]; then
        delete_flag=-d
      else
        delete_flag=-D
      fi

      if git branch "$delete_flag" -- "$branch"; then
        deleted=$((deleted + 1))
      else
        echo "Failed to delete '$branch'; skipping."
        skipped=$((skipped + 1))
      fi
      ;;
    *)
      echo "Skipped."
      skipped=$((skipped + 1))
      ;;
  esac
done

echo
echo "Done. Deleted $deleted; skipped $skipped."
