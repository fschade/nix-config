# go-service (copier template)

Minimal Go service where mise is the only prerequisite: it brings
go/lefthook/committed, so contributors need no nix. Ships mise tasks, lefthook
hooks (gofmt, go vet, conventional commits), `.editorconfig` and a CI workflow.

```sh
copier copy ~/.local/share/copier/templates/go-service ./my-service
cd my-service
git init && mise install && lefthook install
```

Copier asks for `project_name`, `module_path`, `go_version`, `description`.

`copier update` needs the template in its own tagged git repo. This one lives
inside nix-config, so only `copier copy` works. Generated projects carry a
`.copier-answers.yml`, so an update works once the template is reachable.

The template runs a task, which copier only allows for trusted templates. The
trust entry comes from `home/cli/dev.nix`, so a fresh machine needs a deploy
first; from anywhere else use `copier copy --trust`.
