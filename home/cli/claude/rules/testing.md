# Testing

- Test output must be pristine to pass: warnings and stack traces in a green
  run are findings, not noise.
- Never test mocked behavior. A test that asserts on its own mocks proves
  nothing. No mock modes in application code, e2e runs against real things.
- A failing test means fix the implementation, not the test, unless the test
  itself is provably wrong. Never weaken or delete an assertion to get green.
- A bug fix ships with the test that would have caught it, in the same change.
  "Tests later" does not exist.
