# Testing

- A green run is pristine: warnings and stack traces are findings.
- Never test mocks. No mock modes in application code, e2e runs against real
  things.
- A failing test means fix the code, unless the test is provably wrong. Never
  weaken or delete an assertion.
- A bug fix ships with the test that would have caught it.
