# go-service (copier template)

Minimal Go service where mise is the only prerequisite. It brings
go/lefthook/committed, so nobody needs nix and contributors can just clone. Ships
mise tasks, lefthook hooks (gofmt, go vet, conventional commits via `committed`),
an `.editorconfig` and a CI workflow.

```sh
copier copy ~/.local/share/copier/templates/go-service ./my-service
cd my-service
git init && mise install && lefthook install
```

Copier asks for `project_name`, `module_path`, `go_version`, `description`.

`copier update` (pull later template changes into a generated project) needs the
template to be its own git repo with version tags. This one lives inside
nix-config, so only `copier copy` works. For updates, extract this directory
into a tagged repo and point copier there.

The template runs a task (see `copier.yml`), which copier only allows for
templates you trust. The trust entry for the path above comes from
`home/cli/dev.nix`, so a fresh machine needs a `mise run deploy` first; from
anywhere else you need `copier copy --trust`.
