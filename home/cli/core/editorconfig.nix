{...}: {
  # global ~/.editorconfig baseline. the module adds `root = true` itself.
  # editorconfig searches upward and stops at nearest match, so a project-local
  # .editorconfig always wins. this only applies when a project ships none.
  # formatters (gofmt, alejandra) do the real work, this is just the safety net.
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
      # markdown use trailing spaces for hard line breaks, dont strip them.
      "*.md" = {
        trim_trailing_whitespace = false;
      };
    };
  };
}
