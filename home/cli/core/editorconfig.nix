{...}: {
  # Global ~/.editorconfig baseline. The module adds `root = true` itself.
  # EditorConfig searches upward from each file and stops at the nearest match,
  # so any project-local .editorconfig (with root = true) always wins — this only
  # applies where a project ships none. Formatters (gofmt, alejandra) still do the
  # real work; this is the editor/misc-file safety net.
  editorconfig = {
    enable = true;
    settings = {
      "*" = {
        charset = "utf-8";
        end_of_line = "lf";
        insert_final_newline = true;
        trim_trailing_whitespace = true;
        indent_style = "space";
        indent_size = 2;
      };
      "*.go" = {
        indent_style = "tab";
      };
      "Makefile" = {
        indent_style = "tab";
      };
      # Markdown uses trailing spaces for hard line breaks — don't strip them.
      "*.md" = {
        trim_trailing_whitespace = false;
      };
    };
  };
}
