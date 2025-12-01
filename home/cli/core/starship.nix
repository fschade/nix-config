{lib, ...}: {
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;

    # https://starship.rs/config/  colors come from the catppuccin terminal
    # palette, so standard names render in the theme.
    settings = {
      "$schema" = "https://starship.rs/config-schema.json";
      add_newline = true;

      format = lib.concatStrings [
        "$os"
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "$nodejs$golang$rust$python"
        "$kubernetes"
        "$docker_context"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      os = {
        disabled = false;
        style = "bold green";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "bold blue";
        read_only = " 󰌾";
      };

      git_branch = {
        symbol = " ";
        style = "bold mauve";
      };
      git_status.style = "bold peach";

      # know when you are inside a `nix develop` / nix-shell
      nix_shell = {
        symbol = " ";
        style = "bold sky";
        format = "via [$symbol$name]($style) ";
      };

      # kubernetes context, red on purpose so you never nuke the wrong cluster.
      # only shown in k8s/infra dirs.
      kubernetes = {
        disabled = false;
        symbol = "󱃾 ";
        style = "bold red";
        format = "on [$symbol$context( \\($namespace\\))]($style) ";
        detect_files = ["kustomization.yaml" "Chart.yaml" "skaffold.yaml" "Tiltfile" "helmfile.yaml" "talosconfig"];
        detect_folders = ["k8s" "kubernetes" "manifests" "helm" ".helm"];
      };

      docker_context = {
        symbol = " ";
        style = "bold blue";
      };

      cmd_duration = {
        min_time = 500;
        style = "bold yellow";
        format = "took [$duration]($style) ";
      };

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
        vimcmd_symbol = "[](bold green)";
      };
    };
  };
}
