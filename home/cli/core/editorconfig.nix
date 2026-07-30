{...}: {
  # global ~/.editorconfig safety net for projects that ship none. a
  # project-local .editorconfig always wins, editorconfig stops at the nearest
  # match. real formatting is still gofmt/alejandra's job.
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
