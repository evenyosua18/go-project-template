---
trigger: model_decision
description: Applies whenever writing or modifying Go error handling logic, business validations, or defining new error codes
---

# Error Handling Rule

**1. General Principle**
All returned errors in the usecase or handler layers **must** be wrapped with `sp.LogError()` before they are returned. This ensures the error is recorded into the structured observability context (e.g., tracing span) so that unexpected failures can be properly monitored and debugged.

**2. Scenarios and Usage**

* **Direct Error Propagation:**
  When passing along an error that you receive from another internal function or repository without changing its context, call `sp.LogError(err)` directly.
  ```go
  if err != nil {
      return entity.Response{}, sp.LogError(err)
  }
  ```

* **Returning Predefined Business Errors:**
  When a specific business logic rule or validation fails, use `code.Get(<ErrorCode>)` to instantiate the predefined error, and wrap it before returning. Use constants defined in `entity` or `code` packages.
  ```go
  if token == "" {
      return entity.Response{}, sp.LogError(code.Get(entity.InvalidAccessToken))
  }
  ```

* **Wrapping Existing Errors with Business Context:**
  When an external library or infrastructural operation returns an error (e.g., an encryption function or DB layer), and you want to map it to a specific predefined error code, use `code.Wrap()`. This preserves the original error while returning the correct status to the client.
  ```go
  if err != nil {
      // Wraps the raw encryption err with the code.EncryptionError standard
      return entity.Response{}, sp.LogError(code.Wrap(err, code.EncryptionError))
  }
  ```

* **Customizing Predefined Error Messages:**
  If you need to return a generic error code but with a context-specific message, chain `.SetMessage("...")` to `code.Get()`.
  ```go
  if expired {
      return entity.Response{}, sp.LogError(code.Get(code.UnauthorizedError).SetMessage("refresh token expired"))
  }
  ```

**3. Anti-Patterns (What NOT to do)**
* ❌ Returning an error raw without logging it to the span: `return response, err`
* ❌ Creating unmanaged errors using `errors.New` or `fmt.Errorf` at the usecase boundary without passing them through the `code` package logic. Make sure all domain errors are mapped to consistent error format values using `code.Get` or `code.Wrap`.

**4. AI Assistant Rules**
* The AI agent is explicitly allowed to add any new error codes inside `config/codes.yml` as needed when implementing or handling new error cases.