# go-service (copier template)

Scaffolds a minimal Go service where **mise is the only prerequisite** (it
provides go/lefthook/committed — no nix needed, contributor-friendly): mise
tasks, lefthook hooks (gofmt + go vet + conventional-commit linting via
`committed`), an `.editorconfig`, and a CI workflow (go test + committed).

## Use it

```sh
copier copy ~/.local/share/copier/templates/go-service ./my-service
cd my-service
git init && mise install && lefthook install
```

`copier` asks for `project_name`, `module_path`, `go_version`, `description`.

## Template updates

`copier update` re-applies later template changes to a generated project, but it
requires the **template** to be a git repo with version tags. This template
currently lives inside the nix-config repo, so `copier copy` works out of the
box; for `copier update`, extract this directory into its own tagged git repo
(e.g. `github.com/fschade/go-service-template`) and point copier at that.
