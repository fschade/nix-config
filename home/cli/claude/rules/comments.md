# Code comments

Default is none. Comment only where the code can't speak for itself.

- One line, two at most. More belongs in a doc or a better name. A file header
  may run a few lines.
- Why, not what: the trap it avoids, the alternative that fails, the file
  holding the other half. Never restate the line below.
- What is true now. No history, no "we first tried".
- Plain and terse: lowercase start, fragments fine, no trailing period. No
  "This function is responsible for", no hedging, no dividers.

```python
# bad
# retry three times
for attempt in range(3):

# good
# the rate limit resets after 30s, three attempts cover one window
for attempt in range(3):
```
