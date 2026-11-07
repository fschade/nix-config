# manual steps

stuff nix cant do for you. do after a fresh `mise run deploy`.

## after a macOS major update
nix comes back on its own. permission grants do not: check karabiner, aerospace
and background items below. check one-liners are in the navi cheats under
`nix, macos`.

## rosetta (one-time, per apple silicon mac)
mysides, which sets the finder favorites in the deploy, ships x86_64 only. without
rosetta the deploy prints `Bad CPU type` and leaves the favorites as they are:

    softwareupdate --install-rosetta --agree-to-license

## gatekeeper quarantine (one-time cleanup)
an unmanaged `LSQuarantine` key nix-darwin will never delete:

    defaults delete com.apple.LaunchServices LSQuarantine

## stray pnpm rc (one-time cleanup)
an unmanaged `rc` next to the managed `config.yaml`, pnpm 11 never reads it:

    rm ~/.config/pnpm/rc

## keyboard shortcuts (one-time cleanup)
`com.apple.symbolichotkeys` holds only key 64 (spotlight), the rest is factory.
the switch merges with `-dict-add` and brings nothing back. aerospace wants the
mission control ones off: ctrl-1..9 space switching (118-127) and the
move-a-space arrows (79-82). current state:

    defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys

## macshot hotkey vs brave (⇧⌘T)
macshot takes ⇧⌘T globally and its hotkeys live in the app, not defaults. move it
in macshot > settings > shortcuts.

## claude code from nixpkgs (one-time, before the deploy that drops the cask)
the `claude-code@latest` cask zaps `~/.claude.json*` and brew cleanup runs with
`zap`. uninstall it plainly first, then deploy:

    brew uninstall --cask claude-code@latest

a mise-installed claude-code puts a shim ahead of the nix one on `PATH`:

    mise uninstall --all claude-code

after the deploy: start `claude` once so it rewrites
`~/.claude/chrome/chrome-native-host` to the store path, then run
`mise run claude-smoke`.

## jetbrains mcp server (user scope, one-time)
managed settings only take https servers, the ide's local one stays in
`~/.claude.json`:

    claude mcp add -s user -t http idea http://127.0.0.1:64342/stream

## claude code sandbox
after the first deploy with it: `mise run claude-smoke`, then `/sandbox` in a
session, its Config tab lists what applies.

linux: try one host first. `failIfUnavailable` keeps claude from starting where
bubblewrap or user namespaces are restricted, an lxc container for one.

what fails in the agent's shell, by design, run it yourself with `!`: deploys,
docker, the nix daemon (`nix build`, `nix flake metadata`), git over ssh remotes,
anything reading a real `.env`.

check `.claude/ssh-hosts` in a project with a real host, after the yes at session
start: `/sandbox` lists its patterns, a plain `ssh host true` brings a prompt titled
"Bash command (unsandboxed)" and works, the same to an unlisted host fails,
`ssh host -o ProxyCommand=x true` is denied.

linux: the backstop check in `home/cli/claude/hooks/README.md` shows whether the
launcher's `disableAllHooks: false` beats a project's `true`.

a tracked `.pem` or `.key` is unreadable in the agent's shell. if
`claude-smoke` reports git failing beside one, take the name out of `denyRead` in
`home/cli/claude/settings.json`.

an agent that needs a key for tests (openrouter, say) gets one of its own with a
spending limit, never the main key. put it in `.env.agent` and load only that
with `dotenv_if_exists .env.agent` in the project's `.envrc`; a plain `dotenv`
would hand every secret in `.env` to the session. start claude from a shell
where direnv ran, the sandbox passes the env through.

## ssh key per project (one-time, per server)
own key, own non-root user:

    ssh-keygen -t ed25519 -f ~/.ssh/app-prod -C app-prod

in that user's `authorized_keys` on the server:

    restrict,from="203.0.113.10",command="/usr/local/bin/deploy-app" ssh-ed25519 AAAA... app-prod

- `restrict` drops forwarding, pty and `~/.ssh/rc`, add `pty` back if a shell is
  the job
- `from=` only where the client ip is fixed
- `command=` runs that, whatever the client asked. the requested line is in
  `$SSH_ORIGINAL_COMMAND`, so a small script can allow-list. without `command=`
  the key is a full shell as that user. rsync only: rsync's `rrsync` wrapper, not
  every distro ships it

which key ssh takes for this host, in `home/cli/core/ssh.nix`:

    settings."prod.example.com" = {
      IdentityFile = "~/.ssh/app-prod";
      IdentitiesOnly = "yes";
    };

that the agent may reach it, one line in the project's `.claude/ssh-hosts`:

    prod.example.com

## ssh agent confirmation (per project that reaches production)
a dialog for every use of the key, in an agent holding only that key. macOS ships
no `ssh-askpass`, so `~/.ssh/askpass-confirm`, `chmod +x`:

    #!/bin/sh
    exec osascript -e 'on run argv' -e 'display dialog (item 1 of argv) buttons {"Deny", "Allow"} default button "Deny" cancel button "Deny"' -e 'end run' "$1" >/dev/null

start the agent, gone after a reboot. the host has to be in `known_hosts`, `-h`
looks its key up there:

    SSH_ASKPASS=~/.ssh/askpass-confirm SSH_ASKPASS_REQUIRE=force DISPLAY=:0 ssh-agent -a ~/.ssh/agent-prod.sock
    SSH_AUTH_SOCK=~/.ssh/agent-prod.sock ssh-add -c -h deploy@prod.example.com ~/.ssh/app-prod

the host entry points at the agent and at the public key, a private key there lets
ssh skip the agent. the key needs a passphrase that is not in the keychain, or
`ssh -i` skips the dialog:

    settings."prod.example.com" = {
      IdentityAgent = "~/.ssh/agent-prod.sock";
      IdentityFile = "~/.ssh/app-prod.pub";
      IdentitiesOnly = "yes";
    };

check: an `ssh` to the host has to bring up the dialog, Deny has to fail the login.

## claude in chrome: own profile (one-time, per machine)
no hook sees which page a tab shows, so the agent gets nothing to act as. new chrome
profile, logged in only to claude for the extension, the extension only there,
removed from the others in `chrome://extensions`:

    open -na "Google Chrome" --args --profile-directory=Claude

a page behind another login stays out of reach, log in there by hand when a task
needs it.

## intellij: claude code worktrees (one-time)
they sit inside the project and intellij would index them. settings, editor,
file types, "ignore files and folders": add `worktrees`.

## dell u4025qw hub (mac-studio)
the monitor hub links at usb 2.0, so dac, webcam and the 2.5g ethernet share 480
mbps and the adi-2 drops out under network load. connect via the tb4 upstream
with a real tb4/usb4 cable. a `simulated or deferred connection lost` on the top
hub is the kvm switching, not a fault.

## obsbot center
no cask, signed download urls only. install by hand from obsbot.com. the login
item is set, so it autostarts once installed.

## libation (audible account, one-time)
add the audible account in the app (accounts > add account, locale matters), set
library folder and export format before the first scan.

## vikunja (mac-studio, one-time)
desktop app: enter the server url on first start and log in. `vja` needs
`~/.config/vja/config.rc` with `api_url` and `frontend_url` under
`[application]`. `api_url` must end in `/v2`, vja only speaks the v2 api
(server >= 2.5). the first `vja ls` asks for the login and keeps the token.

## mac app store apps (one-time, per apple account)
`mas` only installs what the account owns. every `masApps` entry has to be
"bought" once by hand in the App Store.

## login items
the reconcile runs osascript against System Events. grant it once:
system settings > privacy & security > automation > allow your terminal (and
`darwin-rebuild`) to control **System Events**.

## background items ("allow in the background")
every nix plist runs `/bin/sh`, so macOS files them under *unknown developer* in
system settings > general > login items & extensions. one toggle there stops the
launchd agents and `org.nixos.activate-system`. symptom: ⌘Space dead after a
reboot, no sketchybar. current state:

    sfltool dumpbtm | grep -B4 disallowed

## obs virtual camera (browser streaming)
OBS mixes the cams and hands the result over as a webcam.

- system settings > general > login items & extensions, OBS, the ⓘ, camera
  extension on. restart OBS.
- privacy & security > camera and microphone for OBS, screen recording if a
  scene captures a window
- a camera belongs to one app at a time, so every cam goes into OBS

start the virtual camera in OBS *first*, then open the tab, else the browser
latches onto a wrong resolution. output 1080p30, 8 bit. brave and chrome are the
safe bet; if the camera stays missing, hardware acceleration off.

## web apps (dashboard, opentalk on this mac)
built into /Applications during `mise run deploy`. format and builder are in
**tools/web-app/README.md**. what needs a human:

- local overrides are `custom/web-apps/*/manifest.local.jsonc`
- one-time grants on first use: notifications, plus camera and mic for opentalk
  (screen recording if you share)
- `mise run web-app dmg` wants "control Finder" automation to style the
  installer window, without it the DMG is plain but works

## karabiner (umlauts + tilde)
else ä ö ü ~ stay dead:
- privacy & security > allow the karabiner system extension
- privacy & security > input monitoring > enable karabiner

check: `pgrep -f Karabiner-Core-Service`.

## aerospace (tiling wm)
- privacy & security > accessibility > enable AeroSpace

check: `aerospace list-workspaces --focused`. a config change takes after
`aerospace reload-config`.

## keyboard layout (keebwerk mega, optional)
export the VIA layout to custom/config/keyboard/keebwerk-mega.json.
