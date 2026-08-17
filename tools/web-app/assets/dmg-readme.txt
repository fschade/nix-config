Installing __NAME__
================

1. Drag __NAME__ onto the Applications shortcut.
2. First launch: macOS blocks the app once, because it is ad-hoc signed, not
   notarised. Double-click it, dismiss the warning, then open System Settings >
   Privacy & Security, scroll down and click "Open Anyway" next to the blocked
   app, and confirm. After that it opens normally.

Or once in Terminal:  xattr -dr com.apple.quarantine "/Applications/__NAME__.app"
