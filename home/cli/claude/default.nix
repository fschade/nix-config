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

  # blader/humanizer keeps its SKILL.md at the repo root, so it needs a dir of
  # its own. license travels with it (MIT).
  humanizerSkill = pkgs.runCommand "humanizer-skill" {} ''
    install -Dm644 ${inputs.skills-humanizer}/SKILL.md $out/SKILL.md
    install -Dm644 ${inputs.skills-humanizer}/LICENSE $out/LICENSE
  '';

  # the skills we take from other repos, by input and directory. names are
  # spelled out on purpose: when upstream renames or drops one, the build breaks
  # instead of the skill quietly disappearing.
  skillSources = [
    # grill-with-docs is a one-liner that runs /grilling with /domain-modeling,
    # so those two come along. alone it has nothing to call.
    {
      src = inputs.skills-mattpocock;
      dir = "skills/engineering";
      names = ["domain-modeling" "grill-with-docs"];
    }
    {
      src = inputs.skills-mattpocock;
      dir = "skills/productivity";
      names = ["grilling"];
    }
    # trail of bits ship one skill per plugin dir, hence the long path.
    {
      src = inputs.skills-trailofbits;
      dir = "plugins/ask-questions-if-underspecified/skills";
      names = ["ask-questions-if-underspecified"];
    }
  ];

  # review subagents from the pr-review-toolkit plugin. each one covers a rule
  # from CLAUDE.md that the built-in /code-review does not look at: comment rot,
  # swallowed errors, test coverage. same read-only deal as the skills.
  agents = pkgs.runCommand "claude-agents" {} (
    lib.concatMapStringsSep "\n"
    (name: ''
      install -Dm644 ${inputs.claude-plugins-official}/plugins/pr-review-toolkit/agents/${name}.md \
        $out/${name}.md
    '')
    ["comment-analyzer" "pr-test-analyzer" "silent-failure-hunter"]
  );

  # every skill as name -> source, the name being what you type after the slash
  # (claude code takes the command from the directory, not from the frontmatter).
  # ours carry an fs- prefix so `/fs` lists exactly the ones we wrote.
  skillEntries =
    lib.concatMap
    (s: map (name: lib.nameValuePair name "${s.src}/${s.dir}/${name}") s.names)
    skillSources
    ++ [
      (lib.nameValuePair "humanizer" humanizerSkill)
      (lib.nameValuePair "fs-qa" ./skills/fs-qa)
      (lib.nameValuePair "fs-writing-docs" ./skills/fs-writing-docs)
    ];

  skillNames = map (e: e.name) skillEntries;
  duplicateSkills = lib.filter (n: lib.count (m: m == n) skillNames > 1) (lib.unique skillNames);

  # the whole ~/.claude/skills tree is one store dir: read-only, so no cli can
  # add a skill behind the config's back. this repo is the only way in.
  #
  # two skills claiming one name are caught here rather than in the build: `ln
  # -s` onto an existing directory link puts the second link inside the first.
  # it only fails later, on the read-only store, with a message about
  # permissions.
  skills = assert lib.assertMsg (duplicateSkills == [])
  "claude skills: ${toString duplicateSkills} claimed twice, rename one";
    pkgs.runCommand "claude-skills" {} ''
      mkdir -p $out
      ${lib.concatMapStringsSep "\n" (e: "ln -s ${e.value} $out/${e.name}") skillEntries}
    '';
in {
  # global claude code config. one rule: files claude code writes itself
  # (settings.json, CLAUDE.md, statusline-command.sh) are writable copies,
  # reinstalled on every switch so this repo stays the source of truth. files it
  # only reads (rules, hooks, skills) are store symlinks.
  #
  # per project extras go into the projects own .claude/settings.json, allow
  # rules merge on top, a global deny always wins.
  home.packages = [serena];

  home.file = {
    ".claude/hooks".source = hooks;
    ".claude/rules".source = ./rules;
    ".claude/skills".source = skills;
    ".claude/agents".source = agents;
    # the config surfaces claude code reads are all store paths, so the three
    # that would otherwise collect imperative installs get an empty one.
    # writes fail on the read-only store, whoever tries.
    #
    # .agents/skills: where the `skills` cli keeps its canonical copies, with
    # every agent dir symlinking into it. per repo installs
    # (<repo>/.agents/skills) still work.
    # .claude/commands: a command is a skill with a different path, so anything
    # new goes into skills/.
    # .claude/plugins: marketplace clones and plugin caches. we run no plugins,
    # the swift lsp is a settings.json entry (see lspServers).
    ".agents".source = pkgs.runCommand "agents-dir-locked" {} "mkdir -p $out/skills";
    ".claude/commands".source = pkgs.runCommand "commands-dir-locked" {} "mkdir -p $out";
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
