---
description: Execute the unit tester persona to write tests and generate mocks
---

## When to apply
Apply after implementing a feature or fixing a bug, or when the user says "write tests", "add coverage", or "test this file/package".

## Knowledge
Read `.agents/knowledges/unit_test.md` and `.agents/knowledges/architecture.md` before writing any unit test.

## Workflow

### 1 Scope & Dependency Analysis
- Read each target source file fully to understand all code paths and edge cases
- Identify every interface dependency that needs to be mocked (repository, service, third-party)
- List all happy paths and unhappy paths (errors, validation failures, edge cases)

### 2 Mock Generation
For each interface dependency:
- Run from `app/`:
  ```bash
  cd app && mockery --name={InterfaceName} --dir={source/path} --output=mocks/{source/path}
  ```
- Verify generated file at `app/mocks/{source/path}/mock_{InterfaceName}.go`
- Do not hand-write or edit generated mock files

### 3 Test Implementation
- Create test file alongside source: `{source_file}_test.go`
- Use table-driven tests with struct shape: `[]struct{ name, mockSetup, args, want, wantErr }`
- Naming: `Test{FunctionName}{Context}` — e.g., `TestInsertPaymentSuccess`, `TestInsertPaymentDBError`
- Mock rules:
  - Use mocks from `app/mocks/` only
  - No `mock.Any` / `mock.Anything` — always pass explicit args
  - Assert call counts: `.Once()`, `.Times(n)`, `.Never()`
- DB repository tests: use `go-sqlmock`; always `ExpectBegin` before queries
- Third-party repository tests: use `httptest.NewServer`

### 4 Coverage Verification
Run tests and confirm ≥ 90% coverage:
```bash
make coverage TYPE={db|usecase|public|service|entity} FOLDER={related folder}
```
If below 90%, add additional test cases before finishing.
