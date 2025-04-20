{ pkgs, pog, ... }:
let
  direnv = "${pkgs.direnv}/bin/direnv";
  figlet = "${pkgs.figlet}/bin/figlet";
  clolcat = "${pkgs.clolcat}/bin/clolcat";
  _ = {
    git-worktrees = "git worktree list | awk '{print $1}'";
    fzfq = ''${pkgs.fzf}/bin/fzf -q "$1" --no-sort --header-first --reverse'';
  };
in
pog {
  name = "spelltree";
  description = "Add a git worktree, copy tracked files, and trust with direnv.";
  flags = [
    {
      name = "add";
      argument = "WORKTREE_PATH";
      description = "Add a new worktree at a specified path";
    }
    {
      name = "branch";
      argument = "BRANCH_NAME";
      description = "if specified, create a new branch with this name in the new worktree";
    }
    {
      name = "remove";
      argument = "WORKTREE_PATH";
      description = "Remove the specified worktree";
      completion = _.git-worktrees;
      # prompt = ''${_.git-worktrees} | ${_.fzfq} --header "WORKTREE"'';
      # promptError = "you must specify a worktree!";
    }
    {
      name = "list";
      description = "List all worktrees";
      bool = true;
    }
  ];
  script = helpers: with helpers; ''
    set -euo pipefail
    shopt -s globstar nullglob

    if ${flag "list"}; then
      echo "📜 Listing worktrees..."
      git worktree list
      exit 0
    fi

    if ${flag "remove"}; then
      ${confirm {
        prompt = "Are you sure you want to remove the worktree at '$remove'?";
        exit_code = 2;
      }}

      echo "🧹 Removing worktree at $remove..."
      git worktree remove "$remove" || die "❌ Failed to remove worktree." 1
      exit 0
    fi

    if [ -z "$branch" ] && [ -z "$add" ]; then
      die "Both branch and add are undefined! Run spelltree -h to see usages" 1
    fi
    if [ -z "$branch" ]; then
      BRANCH_NAME="$(basename "$add")"
    else
      BRANCH_NAME="$branch"
    fi

    TRACKED_FILE=".git-worktree-tracked"
    if [[ ! -f "$TRACKED_FILE" ]]; then
      die "❌ Missing $TRACKED_FILE" 1
    fi

    if git worktree list | grep -q "$add"; then
      die "Worktree at $add already exists." 1
    fi

    ${figlet} Spelltree | ${clolcat}
    echo "🪄  I solemnly swear I'm up to no good"

    echo "🌿 Creating worktree for branch '$BRANCH_NAME' at '$add'..."
    git worktree add "$add" -b "$BRANCH_NAME" || {
      echo "🔁 Branch already exists. Linking existing branch..."
      git worktree add "$add" "$BRANCH_NAME"
    }

    echo "📦 Copying files from $TRACKED_FILE..."
    while IFS= read -r pattern || [[ -n "$pattern" ]]; do
      [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue

      for src in $pattern; do
        if [[ ! -e "$src" ]]; then
          echo "⚠️  Skipping missing file or dir: $src"
          continue
        fi

        dest="$add/$src"
        mkdir -p "$(dirname "$dest")"

        if [[ -d "$src" ]]; then
          echo "📁 Copying directory: $src → $dest"
          cp -a "$src/" "$dest/"
        else
          echo "📄 Copying file: $src → $dest"
          cp "$src" "$dest"
        fi
      done
    done < "$TRACKED_FILE"

    echo "🪄  Trusting with direnv..."
    ${direnv} allow "$add" || echo "⚠️ Could not allow direnv in $add"

    echo "🪄  Mischief managed"
  '';
}
