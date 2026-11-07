{
  pkgs,
  lib,
  inputs,
  ...
}: let
  herdrHook = pkgs.runCommand "herdr-agent-state.sh" {} ''
    export HOME=$(mktemp -d)
    mkdir -p "$HOME/.claude" # the installer bails out without it
    ${lib.getExe pkgs.herdr} integration install claude
    install -Dm755 "$HOME/.claude/hooks/herdr-agent-state.sh" $out
  '';

  ccSafetyNet = pkgs.writeShellScriptBin "cc-safety-net" ''
    export CC_SAFETY_NET_NO_UPDATE_CHECK=1
    # a repo's own policy can only add rules, never switch ours off
    export CC_SAFETY_NET_PROJECT_TIGHTEN_ONLY=1
    exec ${pkgs.nodejs}/bin/node ${inputs.cc-safety-net}/dist/bin/cc-safety-net.js "$@"
  '';

  claudeLauncher =
    pkgs.writeShellScriptBin "claude"
    (builtins.replaceStrings ["@claude@" "@jq@"] ["${pkgs.claude-code}/bin/claude" "${lib.getExe pkgs.jq}"] (builtins.readFile ./claude-launcher.sh));

  hooks = pkgs.runCommand "claude-hooks" {} ''
    cp -r ${./hooks} $out
    chmod -R u+w $out
    install -Dm755 ${herdrHook} $out/herdr-agent-state.sh
    ln -s ${ccSafetyNet}/bin/cc-safety-net $out/cc-safety-net
  '';

  # empty read-only store dirs, nothing installs skills, agents, commands or plugins behind nix's back
  locked = name: pkgs.runCommand "${name}-dir-locked" {} "mkdir -p $out";
in {
  # rtk compresses bash output for the model, its hook in settings.json keeps deny/ask rules in charge
  # claude-code from nixpkgs, pinned by flake.lock: the settings here rely on version-specific keys
  # bubblewrap and socat are what the sandbox runs on under linux, macos brings seatbelt
  home.packages =
    [claudeLauncher ccSafetyNet pkgs.rtk]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.bubblewrap pkgs.socat];

  # loads the plugin in place from the store, a marketplace install would need a writable ~/.claude/plugins
  home.sessionVariables.CLAUDE_CODE_PLUGIN_DIRS = "${inputs.plugin-egm}/distributions/claude";

  home.file = {
    ".claude/hooks".source = hooks;
    ".cc-safety-net/policy.json".source = ./cc-safety-net/policy.json;
    ".claude/rules".source = ./rules;
    ".claude/skills".source = locked "skills";
    ".claude/agents".source = locked "agents";
    ".claude/commands".source = locked "commands";
    ".agents".source = pkgs.runCommand "agents-dir-locked" {} "mkdir -p $out/skills";
    ".claude/plugins".source = locked "plugins";
    # `rtk ssh host` would miss the sandbox's excludedCommands patterns and the ask rules
    "${
      if pkgs.stdenv.hostPlatform.isDarwin
      then "Library/Application Support"
      else ".config"
    }/rtk/config.toml".text = ''
      [hooks]
      exclude_commands = ["ssh", "autossh", "mosh", "sftp", "scp", "rsync", "gh"]
    '';
  };

  home.activation.claudeSurfacesTakeover = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    for dir in "$HOME/.agents" "$HOME/.claude/skills" "$HOME/.claude/agents" \
      "$HOME/.claude/commands" "$HOME/.claude/plugins"; do
      if [ -d "$dir" ] && [ ! -L "$dir" ]; then
        $VERBOSE_ECHO "claude: removing foreign dir $dir"
        $DRY_RUN_CMD rm -rf "$dir"
      fi
    done
  '';

  home.activation.claudeConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD install -Dm644 ${./CLAUDE.md} "$HOME/.claude/CLAUDE.md"
    $DRY_RUN_CMD install -Dm644 ${./settings.json} "$HOME/.claude/settings.json"
    $DRY_RUN_CMD install -Dm755 ${./statusline-command.sh} "$HOME/.claude/statusline-command.sh"
    # copies, cc-safety-net drops symlinked rule files without a word
    $DRY_RUN_CMD install -Dm644 ${./cc-safety-net/rules/rule.json} "$HOME/.cc-safety-net/rules/rule.json"
    $DRY_RUN_CMD install -Dm644 ${./cc-safety-net/rules/guardrails/rulebook.json} "$HOME/.cc-safety-net/rules/guardrails/rulebook.json"
  '';
}
