---
trigger: always_on
---

**Use Parameter Objects for Function Signatures**
To maintain readability and prevent "long parameter" smells, prioritize passing a single object (the "Options Pattern") rather than multiple positional arguments. This ensures future-proof extensibility and clearer call sites.

**Standardize Function Signatures**
All functions within the repository and usecase layers must accept `context.Context` as the first parameter and return an error as the final return value. This ensures consistent propagation of cancellation signals and error handling across the architecture.

**Resource Cleanup**
Always use `defer` immediately after successfully acquiring a resource (e.g., `rows.Close()`, `resp.Body.Close()`, `file.Close()`, `mutex.Unlock()`) to prevent resource and memory leaks.

**Database Connection Management**
Leverage the database connection pool initialized at application startup. Keep database transactions as brief as possible to prevent connection starvation, and consistently pass `context.Context` to DB operations to enforce timeouts.

**Goroutine Management**
Prevent goroutine leaks by ensuring every spawned goroutine has a clear and guaranteed exit condition. Utilize `context.Context` for cancellation and `sync.WaitGroup` for proper synchronization.

**Nil Pointer Safety**
Always validate reference types (pointers, maps, slices) for `nil` before dereferencing or writing to them to avoid unexpected runtime panics.

**Memory Allocation**
Be mindful of large array or slice allocations. Pre-allocate slice capacity `make([]T, 0, capacity)` when the final size is known to reduce garbage collection overhead from reallocation.