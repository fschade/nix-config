{
  config,
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
    # a repo's .cc-safety-net/policy.json may tighten the global policy, never loosen it
    export CC_SAFETY_NET_PROJECT_TIGHTEN_ONLY=1
    exec ${pkgs.nodejs}/bin/node ${inputs.cc-safety-net}/dist/bin/cc-safety-net.js "$@"
  '';

  # the hook runs unsandboxed, so it only runs git in the project's own repos
  secretGuardSrc = pkgs.applyPatches {
    name = "claude-secret-guard";
    src = inputs.claude-secret-guard;
    patches = [./secret-guard-trust.patch];
  };

  # upstream skips the scan silently when a tool is missing from PATH, so pin them
  secretGuard = pkgs.writeShellScriptBin "secret-guard" ''
    export PATH=${lib.makeBinPath [pkgs.gitleaks pkgs.git pkgs.jq]}:$PATH
    exec ${pkgs.bash}/bin/sh ${secretGuardSrc}/deny-secret-commit.sh "$@"
  '';

  # ultra has only the weekly limit, the hud shows only five_hour, so the weekly window takes its place
  claudeHud = let
    hud = lib.getExe inputs.best-claude-hud.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in
    pkgs.writeShellScriptBin "best-claude-hud" ''
      [ -t 0 ] && exec ${hud} "$@" # --config and friends, no statusline payload
      ${lib.getExe pkgs.jq} -c 'if .rate_limits and .rate_limits.five_hour == null then .rate_limits.five_hour = .rate_limits.seven_day else . end' |
        exec ${hud} "$@"
    '';

  hooks = pkgs.runCommand "claude-hooks" {} ''
    install -Dm755 ${herdrHook} $out/herdr-agent-state.sh
    ln -s ${ccSafetyNet}/bin/cc-safety-net $out/cc-safety-net
    ln -s ${secretGuard}/bin/secret-guard $out/secret-guard
  '';

  # upstream ships the bundled plugin, it calls bare `node` and needs >= 24.15
  contextMode = pkgs.runCommand "context-mode-plugin" {} ''
    cp -r ${inputs.plugin-context-mode}/plugins/claude-code $out
    chmod -R u+w $out
    substituteInPlace $out/.claude-plugin/plugin.json $out/hooks/claude-code.json \
      --replace-fail '"node' '"${pkgs.nodejs}/bin/node'
  '';

  # lspServers only load from a plugin, not from settings.json
  lsp = pkgs.runCommand "lsp-plugin" {} ''
    mkdir -p $out/.claude-plugin
    cp ${pkgs.writeText "plugin.json" (builtins.toJSON {name = "lsp";})} $out/.claude-plugin/plugin.json
    cp ${pkgs.writeText "lsp.json" (builtins.toJSON {
      gopls = {
        command = lib.getExe pkgs.gopls;
        extensionToLanguage.".go" = "go";
      };
      typescript = {
        command = lib.getExe pkgs.typescript-language-server;
        args = ["--stdio"];
        extensionToLanguage = {
          ".ts" = "typescript";
          ".tsx" = "typescriptreact";
          ".mts" = "typescript";
          ".cts" = "typescript";
          ".js" = "javascript";
          ".jsx" = "javascriptreact";
          ".mjs" = "javascript";
          ".cjs" = "javascript";
        };
      };
      nixd = {
        command = lib.getExe pkgs.nixd;
        extensionToLanguage.".nix" = "nix";
      };
    })} $out/.lsp.json
  '';

  # upstream's skill runs `npx ctx7@latest`, ctx7 comes from nixpkgs instead
  context7 = pkgs.runCommand "context7-plugin" {} ''
    mkdir -p $out/.claude-plugin $out/skills
    cp ${pkgs.writeText "plugin.json" (builtins.toJSON {name = "context7";})} $out/.claude-plugin/plugin.json
    cp -r ${inputs.context7}/skills/find-docs $out/skills/
    cp ${inputs.context7}/LICENSE $out/
    chmod -R u+w $out
    substituteInPlace $out/skills/find-docs/SKILL.md \
      --replace-fail 'Run commands with `npx ctx7@latest` so setup always uses the latest CLI without a global install:' 'Run commands with `ctx7`:' \
      --replace-fail $'Optionally install globally if you prefer a bare `ctx7` command:\n\n```bash\nnpm install -g ctx7@latest\n```\n\n' "" \
      --replace-fail 'npx ctx7@latest' 'ctx7'
  '';

  # empty read-only store dirs, nothing installs skills, agents, commands or plugins behind nix's back
  locked = name: pkgs.runCommand "${name}-dir-locked" {} "mkdir -p $out";

  # plugin hooks get ${CLAUDE_PLUGIN_DATA} = ~/.claude/plugins/data/<id>, claude creates it before the hook runs
  pluginData = "${config.home.homeDirectory}/.local/share/claude/plugin-data";
  plugins = pkgs.runCommand "plugins-dir-locked" {} ''
    mkdir -p $out
    ln -s ${pluginData} $out/data
  '';
in {
  # claude-code from nixpkgs, pinned by flake.lock: the settings here rely on version-specific keys
  # bubblewrap and socat carry the sandbox on linux, macos brings seatbelt
  home.packages =
    [pkgs.claude-code pkgs.ctx7 ccSafetyNet claudeHud]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.bubblewrap pkgs.socat];

  # loads the plugins in place from the store, a marketplace install would need a writable ~/.claude/plugins
  home.sessionVariables.CLAUDE_CODE_PLUGIN_DIRS = lib.concatStringsSep ":" [
    "${inputs.plugin-egm}/distributions/claude"
    contextMode
    lsp
    context7
    "${inputs.plugins-official}/plugins/claude-security"
    "${inputs.plugins-official}/plugins/session-report"
    "${inputs.plugins-official}/plugins/skill-creator"
  ];

  home.file = {
    ".claude/hooks".source = hooks;
    ".claude/rules".source = ./rules;
    ".claude/skills".source = locked "skills";
    ".claude/agents".source = locked "agents";
    ".claude/commands".source = locked "commands";
    ".agents".source = pkgs.runCommand "agents-dir-locked" {} "mkdir -p $out/skills";
    ".claude/plugins".source = plugins;
    ".claude/best-claude-hud/config.toml".source = ./best-claude-hud.toml;
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
    $DRY_RUN_CMD install -d -m700 "${pluginData}"
    $DRY_RUN_CMD install -Dm644 ${./CLAUDE.md} "$HOME/.claude/CLAUDE.md"
    $DRY_RUN_CMD install -Dm644 ${./settings.json} "$HOME/.claude/settings.json"
    # cc-safety-net refuses a symlinked policy, so a copy instead of home.file
    $DRY_RUN_CMD install -d -m700 "$HOME/.cc-safety-net"
    $DRY_RUN_CMD install -m600 ${./cc-safety-net.json} "$HOME/.cc-safety-net/policy.json"
  '';
}
