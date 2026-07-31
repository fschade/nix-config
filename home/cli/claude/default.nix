{
  pkgs,
  lib,
  inputs,
  ...
}: let
  # serena (semantic code tools via LSP, github.com/oraios/serena). no imperative
  # install: uvx pulls latest on every run, so `serena` bumps by itself. used for
  # the CLI (`serena init`, ...) and to opt a single project into the MCP server:
  #   claude mcp add serena -- serena start-mcp-server --context claude-code --project-from-cwd
  serena = pkgs.writeShellScriptBin "serena" ''
    exec ${pkgs.uv}/bin/uvx --python 3.13 --from serena-agent serena "$@"
  '';

  # herdr sidebar hook. on SessionStart it reports claude's session id to the
  # herdr pane over its socket. that is how herdr knows which agent runs where.
  # `herdr integration install claude` would write it into ~/.claude and fight
  # the nix copy. the package emits it at build time instead, pinned to the
  # herdr version we ship.
  herdrHook = pkgs.runCommand "herdr-agent-state.sh" {} ''
    export HOME=$(mktemp -d)
    mkdir -p "$HOME/.claude" # the installer bails out without it
    ${lib.getExe pkgs.herdr} integration install claude
    install -Dm755 "$HOME/.claude/hooks/herdr-agent-state.sh" $out
  '';

  # ~/.claude/hooks is one store symlink, so the generated hook has to be
  # merged into the dir here instead of being its own home.file entry.
  # the wiring is in hooks/README.md, what a rule blocks sits next to the rule.
  hooks = pkgs.runCommand "claude-hooks" {} ''
    cp -r ${./hooks} $out
    chmod -R u+w $out
    install -Dm755 ${herdrHook} $out/herdr-agent-state.sh
  '';

  # one skill pack: addy osmani's lifecycle skills, taken whole. skills, review
  # personas and slash commands all come from this tree, so there is no
  # curation list to maintain and `mise run update` is the whole upkeep.
  pack = inputs.skills-addyosmani;

  # blader/humanizer keeps its SKILL.md at the repo root, so it needs a dir of
  # its own. license travels with it (MIT).
  humanizerSkill = pkgs.runCommand "humanizer-skill" {} ''
    install -Dm644 ${inputs.skills-humanizer}/SKILL.md $out/SKILL.md
    install -Dm644 ${inputs.skills-humanizer}/LICENSE $out/LICENSE
  '';

  # the pack's skills name shared checklists as `references/<file>.md`, a path
  # that only resolves under a plugin install (upstream issue #361). copying
  # each skill and linking the dir in fixes that. `ln -s` fails loudly if a
  # skill ever ships its own references dir, which is the right time to look.
  skills = pkgs.runCommand "claude-skills" {} ''
    mkdir -p $out
    for dir in ${pack}/skills/*/; do
      name=$(basename "$dir")
      cp -r "$dir" "$out/$name"
      chmod -R u+w "$out/$name"
      ln -s ${pack}/references "$out/$name/references"
    done
    install -m644 ${pack}/LICENSE $out/LICENSE
    ln -s ${humanizerSkill} $out/humanizer
  '';
in {
  # global claude code config. one rule: files claude code writes itself
  # (settings.json, CLAUDE.md, statusline-command.sh) are writable copies,
  # reinstalled on every switch so this repo stays the source of truth. files it
  # only reads (rules, hooks, skills, agents, commands) are store symlinks.
  #
  # per project extras go into the projects own .claude/settings.json, allow
  # rules merge on top, a global deny always wins.
  home.packages = [serena];

  home.file = {
    ".claude/hooks".source = hooks;
    ".claude/rules".source = ./rules;
    ".claude/skills".source = skills;
    ".claude/agents".source = "${pack}/agents";
    ".claude/commands".source = "${pack}/.claude/commands";
    # the remaining config surfaces claude code reads get an empty store path,
    # so no cli can collect imperative installs there. writes fail on the
    # read-only store, whoever tries.
    #
    # .agents/skills: where the `skills` cli keeps its canonical copies. per
    # repo installs (<repo>/.agents/skills) still work.
    # .claude/plugins: marketplace clones and plugin caches. we run no plugins,
    # the swift lsp is a settings.json entry (see lspServers).
    ".agents".source = pkgs.runCommand "agents-dir-locked" {} "mkdir -p $out/skills";
    ".claude/plugins".source = pkgs.runCommand "plugins-dir-locked" {} "mkdir -p $out";
  };

  # these paths belong to this module. a real dir at one of them is foreign: a
  # cli that dropped its own copies there, or a marketplace clone. it holds
  # installed copies only. home-manager refuses to link over a real dir, so
  # clear it. store symlinks stay.
  home.activation.claudeSurfacesTakeover = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    for dir in "$HOME/.agents" "$HOME/.claude/skills" "$HOME/.claude/agents" \
      "$HOME/.claude/commands" "$HOME/.claude/plugins"; do
      if [ -d "$dir" ] && [ ! -L "$dir" ]; then
        $VERBOSE_ECHO "claude: removing foreign dir $dir"
        $DRY_RUN_CMD rm -rf "$dir"
      fi
    done
  '';

  # claude code writes these three itself (`#` into CLAUDE.md, /config,
  # /statusline), so they are real files and not store links. every switch
  # installs the repo copy back over them: whatever ~/.claude collected since
  # is gone. change them here, never there.
  home.activation.claudeConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD install -Dm644 ${./CLAUDE.md} "$HOME/.claude/CLAUDE.md"
    $DRY_RUN_CMD install -Dm644 ${./settings.json} "$HOME/.claude/settings.json"
    $DRY_RUN_CMD install -Dm755 ${./statusline-command.sh} "$HOME/.claude/statusline-command.sh"
  '';
}
