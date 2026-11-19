# The pages of a home whose settings are Home Manager's own options: the window makes each page from these
# declarations, as for a system (nix/modules/pages.nix).
_: let
  page = title: icon: order: options: {inherit title icon order options;};
in {
  config.socle.ui.pages = {
    shell = page "Shell" "monitor" 11 [
      "programs.bash.enable"
      "programs.zsh.enable"
      "programs.fish.enable"
      "programs.starship.enable"
      "programs.direnv.enable"
      "programs.fzf.enable"
      "programs.zoxide.enable"
    ];
    development = page "Development" "package" 12 [
      "programs.git.enable"
      "programs.gh.enable"
      "programs.helix.enable"
      "programs.neovim.enable"
      "programs.vscode.enable"
    ];
  };
}
