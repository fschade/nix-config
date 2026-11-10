{lib, ...}: {
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;

    settings = {
      "$schema" = "https://starship.rs/config-schema.json";
      add_newline = true;

      format = lib.concatStrings [
        "$os"
        "$directory"
        "$git_branch"
        "$git_commit"
        "\${custom.git_repo}"
        "$git_state"
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
        format = "on [$symbol$branch]($style)( [$remote_name/$remote_branch](bold lavender)) ";
        # default hides the remote whenever both branch names match, so nearly always
        always_show_remote = true;
        only_attached = true;
      };

      git_commit = {
        style = "bold mauve";
        format = "on [$hash$tag]($style) ";
        tag_disabled = false;
        tag_symbol = " #";
      };

      custom.git_repo = {
        description = "owner/repo behind the remote of the current branch";
        # a repo without a remote is normal here, the empty output hides the module
        command = "git remote get-url \"$(git config \"branch.$(git branch --show-current).remote\" || echo origin)\" 2>/dev/null | sed -E 's#\\.git$##; s#^.*[:/]([^/:]+/[^/]+)$#\\1#'";
        when = true;
        require_repo = true;
        shell = ["bash" "--noprofile" "--norc"];
        style = "subtext0";
        format = "([@$output]($style) )";
      };

      git_state.style = "bold red";

      git_status = {
        style = "bold peach";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
      };

      nix_shell = {
        symbol = " ";
        style = "bold sky";
        format = "via [$symbol$name]($style) ";
      };

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
