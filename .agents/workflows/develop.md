---
description: Execute the developer persona to implement a feature described in a tech plan
---

## When to apply
Apply when the user provides a tech plan and asks to implement a feature, or says "implement this", "build this feature", or "develop from this plan".

## Knowledge
Read `.agents/knowledges/project-structure.md` and `.agents/knowledges/app-layers.md` (all sections) before writing any code.

## Workflow

### 1 Workspace Preparation
- Run `git pull origin master`
- Determine branch name: `{intent}/{usecase}` where intent is `feature`, `bugfix`, or `hotfix`
- Run `git checkout -b {branch-name}`

### 2 Specification Design
Analyze the tech plan and define interfaces for all layers before writing code:
- Identify the target microservice from `app/go.mod` (`module github.com/tanookiai/{microservice}-svc`) — ignore endpoints belonging to other microservices
- **Entity** — request/response struct names, fields, validation rules
- **Presentation** — surface (`svc|public|...`), handler name, method, path (`/ms/{microservice}/{surface}/v{n}/{endpoint}`), headers, body, response
- **Usecase** — use case name, method signatures, business logic summary
- **Repository** — interface methods, SQL operation type, table name

### 3 Entity Layer
- Create/update structs in `app/entity/{usecase name}`
- No API/HTTP imports in entity files

### 4 Presentation Layer
- Handler responsibilities: bind + validate request
- No business logic in handlers; depend on service interfaces only

### 5 Usecase Layer
- Define interface in `app/service/{feature}svc/{feature}svc.go`
- Implement use case in `app/service/{feature}svc/{action}.go`
- Pure business logic only — no HTTP/API imports
- Use `BeginScopedTrx` only when partial commits are needed before an external API call
- Wrap errors with `apierror`; use `log.Error` for unexpected errors only

### 6 Repository Layer
- Define interface in `app/repository/db/{feature}/{feature}.go`
- Implement operation in a dedicated file (`insert.go`, `select.go`, `update.go`, etc.)
- Parameterized args only — no string interpolation
- Get DB executor: `r.db.GetExecutor(ctx)`

### 7 Dependency Injection
- Edit `app/api/{surface}/v1/container/container.go` (build tag `wireinject`)
- Add new providers to `wire.Build(...)` — never edit `wire_gen.go` manually
- Run `make wire` to regenerate

### 8 Route Registration
- Register handler in `app/api/{surface}/v1/router/{feature}.go`
- Path format: `/ms/payment/{surface}/v{n}/{endpoint}`
- Register the router group in `app/api/{surface}/v1/routes.go`

### 9 Unit Test Checking
- Run `make test` to make sure the changes not affected current state of unit test
- If show an error, fix the unit test first until no return error in the existing unit test

### Final Check
Run `cd app && go build ./...` to confirm the full build passes.