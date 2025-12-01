{
  pkgs,
  lib,
  ...
}: let
  # deps for the vendored document skills (skills/, from anthropics/skills).
  docSkillsPython = pkgs.python3.withPackages (ps:
    with ps; [
      defusedxml
      lxml
      openpyxl
      pdf2image
      pdfplumber
      pillow
      pypdf
    ]);
  # nixpkgs libreoffice does not build on darwin, the app comes from the brew
  # cask. the skills call plain `soffice`, shim it onto PATH.
  soffice = pkgs.writeShellScriptBin "soffice" ''
    exec "/Applications/LibreOffice.app/Contents/MacOS/soffice" "$@"
  '';
in {
  # global claude code config. one rule: files claude code writes itself
  # (settings.json, CLAUDE.md) are writable copies, reinstalled on every switch
  # so this repo stays the source of truth. files it only reads (rules, hooks,
  # skills) are store symlinks.
  #
  # per project extras go into the projects own .claude/settings.json — allow
  # rules merge on top, a global deny always wins.
  home.packages = [
    docSkillsPython
    soffice
    pkgs.pandoc
    pkgs.poppler-utils
    pkgs.qpdf
  ];

  home.file = {
    ".claude/hooks".source = ./hooks;
    ".claude/rules".source = ./rules;
    ".claude/skills/docx".source = ./skills/docx;
    ".claude/skills/pdf".source = ./skills/pdf;
    ".claude/skills/pptx".source = ./skills/pptx;
    ".claude/skills/xlsx".source = ./skills/xlsx;
  };

  home.activation.claudeConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD install -Dm644 ${./CLAUDE.md} "$HOME/.claude/CLAUDE.md"
    $DRY_RUN_CMD install -Dm644 ${./settings.json} "$HOME/.claude/settings.json"
    $DRY_RUN_CMD install -Dm755 ${./statusline-command.sh} "$HOME/.claude/statusline-command.sh"
  '';
}
