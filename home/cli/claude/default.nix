{
  pkgs,
  lib,
  inputs,
  ...
}: let
  serena = pkgs.writeShellScriptBin "serena" ''
    exec ${pkgs.uv}/bin/uvx --python 3.13 --from serena-agent serena "$@"
  '';

  herdrHook = pkgs.runCommand "herdr-agent-state.sh" {} ''
    export HOME=$(mktemp -d)
    mkdir -p "$HOME/.claude" # the installer bails out without it
    ${lib.getExe pkgs.herdr} integration install claude
    install -Dm755 "$HOME/.claude/hooks/herdr-agent-state.sh" $out
  '';

  ccSafetyNet = pkgs.writeShellScriptBin "cc-safety-net" ''
    export CC_SAFETY_NET_NO_UPDATE_CHECK=1
    exec ${pkgs.nodejs}/bin/node ${inputs.cc-safety-net}/dist/bin/cc-safety-net.js "$@"
  '';

  hooks = pkgs.runCommand "claude-hooks" {} ''
    cp -r ${./hooks} $out
    chmod -R u+w $out
    install -Dm755 ${herdrHook} $out/herdr-agent-state.sh
    ln -s ${ccSafetyNet}/bin/cc-safety-net $out/cc-safety-net
  '';

  pack = inputs.skills-addyosmani;

  # its own. license travels with it (MIT).
  humanizerSkill = pkgs.runCommand "humanizer-skill" {} ''
    install -Dm644 ${inputs.skills-humanizer}/SKILL.md $out/SKILL.md
    install -Dm644 ${inputs.skills-humanizer}/LICENSE $out/LICENSE
  '';

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
  home.packages = [serena ccSafetyNet];

  home.file = {
    ".claude/hooks".source = hooks;
    ".cc-safety-net/policy.json".source = ./cc-safety-net/policy.json;
    ".claude/rules".source = ./rules;
    ".claude/skills".source = skills;
    ".claude/agents".source = "${pack}/agents";
    ".claude/commands".source = "${pack}/.claude/commands";
    ".agents".source = pkgs.runCommand "agents-dir-locked" {} "mkdir -p $out/skills";
    ".claude/plugins".source = pkgs.runCommand "plugins-dir-locked" {} "mkdir -p $out";
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
  '';
}
