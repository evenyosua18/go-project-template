---
trigger: always_on
---

# Logger Usage Rules

Based on the usage of the `logger` function in this project, here is a list of rules and best practices for its usage:

### 1. Import Path
Always import the logger from your core library:
```go
import "github.com/evenyosua18/ego/logger"
```

### 2. Available Methods & Log Levels
Depending on the context, choose the appropriate logging method:
- **`logger.Debug(message string, fields ...logger.Field)`**: Use this for standard flow tracing, showing variable states, or indicating successful milestone executions (e.g., `"got an oauth client"`, `"success generate access access_token"`).
- **`logger.Info(message string, fields ...logger.Field)`**: Use this for logging significant business logical events or anomalies that aren't strict technical errors (e.g., `"different token expiration time"`).
- **`logger.DebugQuery(query string, args []any)`**: Use this exclusively in your repository layer (e.g., `app/repository/db/...`) right before executing a database query, to print the raw SQL and arguments.

### 3. Error Logging Distinction
- **Do not use `logger` for standard error returning.** Error-logging and error-wrapping are handled through the tracer span instance instead of the base logger.
- Log errors contextually on the span: `sp.LogError(err)` or `sp.LogError(code.Get(entity.InvalidAccessToken))`.

### 4. Event Messaging Structure
The first parameter for standard logging attributes should be a clear, descriptive string literal describing the action or state without string interpolation.
- **Good:** `logger.Debug("got a valid session", ...)`
- **Avoid:** `logger.Debug(fmt.Sprintf("session %s is valid", session.Id))`

### 5. Context Data Formatting (`logger.Field`)
Any dynamic variables or contextual data must be passed as variadic arguments using the `logger.Field` struct.
- Instantiate fields with `Key` (a readable string description) and `Value` (the actual variable).
- You can pass as many fields as necessary sequentially.
- There is no strict order required for `Key` and `Value` initialization within the struct itself (e.g., both `logger.Field{Value: x, Key: "x"}` and `logger.Field{Key: "x", Value: x}` are acceptable).

**Example Usage:**
```go
logger.Debug("redirect to login", 
    logger.Field{Key: "session id", Value: session.Id},
    logger.Field{Key: "expire at", Value: session.ExpiredAt},
    logger.Field{Key: "user id", Value: session.UserId},
)
```