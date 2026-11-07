{
  lib,
  pkgs,
  ...
}: let
  # a project settings.json can set disableAllHooks, managed settings it cannot
  managed = pkgs.runCommand "claude-managed-settings.json" {nativeBuildInputs = [pkgs.jq];} ''
    jq '{permissions: (.permissions | {ask, deny, disableBypassPermissionsMode}), hooks: {PreToolUse: .hooks.PreToolUse}, sandbox}' \
      ${../../home/cli/claude/settings.json} >$out
  '';
in {
  system.activationScripts.postActivation.text = lib.mkAfter ''
    install -d -m755 "/Library/Application Support/ClaudeCode"
    install -m644 ${managed} "/Library/Application Support/ClaudeCode/managed-settings.json"
  '';
}
