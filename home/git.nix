{ pkgs, common, ... }:
let
  inherit (common) firstName lastName email authorizedKeysRec machineName digdugdevKey;
  signingKey = if machineName == "digdugdev" then digdugdevKey else authorizedKeysRec.${machineName};
in
{
  home.file.".ssh/allowed_signers".text = "* ${signingKey}";
  programs.git = {
    enable = true;
    # package = pkgs.gitAndTools.gitFull;
    userName = "${firstName} ${lastName}";
    userEmail = email;
    signing.signByDefault = true;
    signing.key = "~/.ssh/id_ed25519.pub";

    aliases = {
      co = "checkout";
      cam = "commit -am";
      ca = "commit -a";
      cm = "commit -m";
      st = "status";
      br = "branch -v";
      branch-name = "!git rev-parse --abbrev-ref HEAD";
      # Push current branch
      put = "!git push origin $(git branch-name)";
      # Pull without merging
      get = "!git pull origin $(git branch-name) --ff-only";
      getr = "!git pull origin $(git branch-name) --rebase";
      # Pull Master without switching branches
      got =
        "!f() { CURRENT_BRANCH=$(git branch-name) && git checkout $1 && git pull origin $1 --ff-only && git checkout $CURRENT_BRANCH;  }; f";
      lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
      lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";

      # delete local branch and pull from remote
      fetchout =
        "!f() { git co main; git branch -D $@; git fetch && git co $@; }; f";
      pufl = "!git push origin $(git branch-name) --force-with-lease";
      putf = "put --force-with-lease";
      shake = "remote prune origin";
    };
    difftastic = {
      enable = true;
      background = "dark";
    };
    extraConfig = {
      color.ui = true;
      push.default = "simple";
      pull.ff = "only";
      init.defaultBranch = "main";
      core = {
        editor = "nano";
        pager = "delta --dark";
      };
      commit.gpgsign = true;
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
    };
  };
}
