# Keyboard layout — Keebwerk Mega ANSI (Yiancar-Designs)

Board runs stock **QMK/VIA** firmware. Umlauts (ä ö ü) and `~` are handled in
macOS by Karabiner, not on the board — see `home/gui/karabiner/`. This folder
only version-controls the VIA keymap so it is not lost / is reproducible.

Note: nix does NOT apply this. VIA layouts live in the board flash; you re-import
by hand in the VIA app. This is just a stored copy under version control.

## Export (save current layout into the repo)
1. Open the **VIA** app, board gets detected.
2. Menu → export / the save icon → save as `keebwerk-mega.json`.
3. Put that file next to this README and commit it.

## Import (restore onto a board)
1. Open **VIA**, board detected.
2. Import → pick `keebwerk-mega.json`.

## Files
- `keebwerk-mega.json` — VIA keymap export (add after first export).

## If you ever switch to Vial
Needs Vial-QMK firmware flashed onto the board first (stock is VIA). Vial then
exports a `.vil` file — store it here the same way. Not needed for umlauts/tilde,
Karabiner covers that.
