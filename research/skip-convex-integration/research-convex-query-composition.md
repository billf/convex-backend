---
title: Convex Query Composition Research
type: research-note
status: active
direction: foundation
date: 2026-09-11
---

# Convex Query Composition Research

## Executive Summary

Convex today supports a **limited composable query pipeline** consisting of:
1. A **source** (FullTableScan, IndexRange, or Search)
2. **Operators** chained on top (currently only Filter and Limit)

All filtering, mapping, and transformation is done in user-authored JavaScript/TypeScript functions. There is no built-in server-side composition model for filters/mappers/reducers beyond the basic filter + limit operators. This makes Skip integration an opportunity to introduce a richer composable query language while leveraging the existing syscall infrastructure.

---

## 1. Query Definition & Execution

### 1.1 TypeScript Client API

**File:** `npm-packages/convex/src/server/query.ts` (interface definitions)
**File:** `npm-packages/convex/src/server/impl/query_impl.ts` (implementation)

#### Query Builder Interface
Users build queries via the `QueryInitializer` interface:

```typescript
// From query.ts:29-68
export interface QueryInitializer<TableInfo extends GenericTableInfo> extends Query<TableInfo> {
  fullTableScan(): Query<TableInfo>;
  withIndex<IndexName extends IndexNames<TableInfo>>(
    indexName: IndexName,
    indexRange?: (q: IndexRangeBuilder<...>) => IndexRange,
  ): Query<TableInfo>;
  withSearchIndex<IndexName extends SearchIndexNames<TableInfo>>(
    indexName: IndexName,
    searchFilter: (q: SearchFilterBuilder<...>) => SearchFilter,
  ): OrderedQuery<TableInfo>;
}

export interface Query<TableInfo extends GenericTableInfo> extends OrderedQuery<TableInfo> {
  order(order: "asc" | "desc"): OrderedQuery<TableInfo>;
}

export interface OrderedQuery<TableInfo extends GenericTableInfo> extends AsyncIterable<...> {
  filter(predicate: (q: FilterBuilder<TableInfo>) => ExpressionOrValue<boolean>): this;
  limit(n: number): this;
  collect(): Promise<Array<...>>;
  take(n: number): Promise<Array<...>>;
  first(): Promise<... | null>;
  unique(): Promise<... | null>;
  paginate(paginationOpts: PaginationOptions): Promise<PaginationResult<...>>;
}
```

#### Query Serialization
Queries are serialized to a simple JSON descriptor (from query_impl.ts:24-42):

```typescript
type QueryOperator = { filter: JSONValue } | { limit: number };
type Source =
  | { type: "FullTableScan"; tableName: string; order: "asc" | "desc" | null }
  | { type: "IndexRange"; indexName: string; range: ReadonlyArray<SerializedRangeExpression>; order: "asc" | "desc" | null }
  | { type: "Search"; indexName: string; filters: ReadonlyArray<SerializedSearchFilter> };

type SerializedQuery = {
  source: Source;
  operators: Array<QueryOperator>;
};
```

**Example:** 
```typescript
ctx.db.query("tasks")
  .withIndex("by_user", q => q.eq("userId", userId))
  .filter(q => q.lte("createdAt", now))
  .limit(10)
```
becomes:
```json
{
  "source": {
    "type": "IndexRange",
    "indexName": "tasks.by_user",
    "range": [{"type": "eq", "field": "userId", "value": userId}],
    "order": null
  },
  "operators": [
    {"filter": {"type": "lte", "left": {"type": "field", "path": "createdAt"}, "right": {"type": "literal", "value": now}}},
    {"limit": 10}
  ]
}
```

### 1.2 Rust Backend Execution Path

**Files:**
- `crates/database/src/query/mod.rs` — Query compilation and execution
- `crates/database/src/query/index_range.rs` — IndexRange source
- `crates/database/src/query/filter.rs` — Filter operator
- `crates/database/src/query/limit.rs` — Limit operator
- `crates/database/src/query/search_query.rs` — Search source
- `crates/common/src/query.rs` — Query type definitions

#### Query Construction (mod.rs:295-469)
When a user calls `db.query()`, the JS syscall `"1.0/queryStream"` arrives at the Rust backend. It constructs a `DeveloperQuery` by:

1. **Parsing the source** into an initial `QueryNode`:
   ```rust
   // mod.rs:412-448
   let mut cur_node = match query.source {
       QuerySource::FullTableScan(full_table_scan) => 
           QueryNode::IndexRange(IndexRange::new(...)),
       QuerySource::IndexRange(index_range) => 
           QueryNode::IndexRange(IndexRange::new(...)),
       QuerySource::Search(search) => 
           QueryNode::Search(SearchQuery::new(...)),
   };
   ```

2. **Chaining operators** into a pipeline (mod.rs:450-462):
   ```rust
   for operator in query.operators {
       let next_node = match operator {
           QueryOperator::Filter(expr) => {
               let filter = Filter::new(cur_node, expr);
               QueryNode::Filter(Box::new(filter))
           },
           QueryOperator::Limit(n) => {
               let limit = Limit::new(cur_node, n);
               QueryNode::Limit(Box::new(limit))
           },
       };
       cur_node = next_node;
   }
   ```

#### QueryNode Enum (mod.rs:693-698)
The pipeline is represented as a tree of composable nodes:

```rust
enum QueryNode {
    IndexRange(IndexRange),
    Search(SearchQuery),
    Filter(Box<Filter>),
    Limit(Box<Limit>),
}
```

Each variant implements the `QueryStream` trait (async_trait):

```rust
#[async_trait]
trait QueryStream: Send {
    fn cursor_position(&self) -> &Option<CursorPosition>;
    fn split_cursor_position(&self) -> Option<&CursorPosition>;
    fn is_approaching_data_limit(&self) -> bool;
    async fn next<RT: Runtime>(...) -> anyhow::Result<QueryStreamNext>;
    fn feed(&mut self, index_range_response: IndexRangeResponse) -> anyhow::Result<()>;
    fn tablet_index_name(&self) -> Option<&TabletIndexName>;
    fn printable_index_name(&self) -> &IndexName;
}
```

#### Filter Implementation (filter.rs)
The `Filter` operator is a composable wrapper:

```rust
pub(super) struct Filter {
    inner: QueryNode,
    expr: Expression,
}

#[async_trait]
impl QueryStream for Filter {
    async fn next<RT: Runtime>(...) -> anyhow::Result<QueryStreamNext> {
        loop {
            let (document, write_timestamp) =
                match self.inner.next(tx, Some(FILTER_QUERY_PREFETCH)).await? {
                    QueryStreamNext::Ready(Some(v)) => v,
                    QueryStreamNext::Ready(None) => return Ok(QueryStreamNext::Ready(None)),
                    QueryStreamNext::WaitingOn(request) => 
                        return Ok(QueryStreamNext::WaitingOn(request))
                };
            let value = document.value().0.clone();
            if self.expr.eval(&value)?.into_boolean()? {
                return Ok(QueryStreamNext::Ready(Some((document, write_timestamp))));
            }
        }
    }
    fn feed(&mut self, index_range_response: IndexRangeResponse) -> anyhow::Result<()> {
        self.inner.feed(index_range_response)
    }
}
```

#### Limit Implementation (limit.rs)
Similar composable wrapper that terminates after N results:

```rust
pub(super) struct Limit {
    inner: QueryNode,
    limit: usize,
    rows_emitted: usize,
}

#[async_trait]
impl QueryStream for Limit {
    async fn next<RT: Runtime>(...) -> anyhow::Result<QueryStreamNext> {
        if self.rows_emitted >= self.limit {
            return Ok(QueryStreamNext::Ready(None));
        }
        // ... delegate to inner, increment counter
    }
}
```

#### QuerySource Types (common/src/query.rs:662-669)

```rust
pub enum QuerySource {
    FullTableScan(FullTableScan),
    IndexRange(IndexRange),
    Search(Search),
}

pub enum QueryOperator {
    Filter(Expression),
    Limit(usize),
}
```

---

## 2. UDF Execution Model

### 2.1 Isolate & V8 Execution

**Files:**
- `crates/isolate/src/isolate.rs` — Main isolate host
- `crates/isolate/src/environment/udf/mod.rs` — UDF environment setup
- `crates/isolate/src/environment/udf/syscall.rs` — Syscall dispatch
- `crates/udf/src/lib.rs` — UDF framework

User JavaScript code runs in a V8 isolate (Deno runtime). When user code calls `db.query()`:

1. **JS execution:** The JS code constructs a query and calls internal syscalls
2. **Syscall dispatch:** JS calls become syscalls routed through `SyscallProviderInternal<RT>`
3. **Rust side execution:** Syscalls return control to Rust for database operations

### 2.2 Query Syscall Interface (isolate/src/environment/udf/syscall.rs)

#### Main Syscall Dispatch (syscall.rs:127-151, sync syscalls only)

```rust
pub fn syscall_impl<RT: Runtime, P: SyscallProviderInternal<RT>>(
    provider: &mut P,
    name: &str,
    args: JsonValue,
) -> anyhow::Result<JsonValue> {
    match name {
        "1.0/queryCleanup" => syscall_query_cleanup(provider, args),
        "1.0/queryStream" => syscall_query_stream(provider, args),
        // ... other sync syscalls (normalizeId, componentArgument, ...)
        // NOTE: "1.0/queryStreamNext" and "1.0/queryPage" are NOT here —
        // they are async/batched syscalls dispatched in async_syscall.rs
        // ("1.0/queryStreamNext" joins the Reads batch, "1.0/queryPage"
        // goes through the Unbatched query_page path).
    }
}
```

#### Query Stream Initiation (syscall.rs:221-246)

```rust
fn syscall_query_stream<RT: Runtime, P: SyscallProviderInternal<RT>>(
    provider: &mut P,
    args: JsonValue,
) -> anyhow::Result<JsonValue> {
    #[derive(Deserialize)]
    struct QueryStreamArgs {
        query: JsonValue,
        version: Option<String>,
    }
    let (parsed_query, version) = with_argument_error("queryStream", || {
        let args: QueryStreamArgs = serde_json::from_value(args)?;
        let parsed_query = Query::try_from(args.query)?;  // Deserialize the serialized query
        let version = parse_version(args.version)?;
        Ok((parsed_query, version))
    })?;
    let query_id = provider.start_query(parsed_query, version)?;
    Ok(serde_json::to_value(QueryStreamResult { query_id })?)
}
```

#### Query Compilation (syscall.rs:96-107)

```rust
fn start_query(&mut self, query: Query, version: Option<Version>) -> anyhow::Result<u32> {
    let table_filter = SyscallProviderInternal::<RT>::table_filter(self);
    let component = self.phase.component()?;
    let tx = self.phase.tx()?;
    let compiled_query = {
        DeveloperQuery::new_with_version(tx, component.into(), query, version, table_filter)?
    };
    let query_id = self.query_manager.put_developer(compiled_query);
    Ok(query_id)
}
```

This is where the `DeveloperQuery` is constructed (via `crates/database/src/query/mod.rs:295-469`), building the QueryNode pipeline.

### 2.3 Query Consumption (isolate/src/environment/udf/query_impl.ts)

JS code calls `.next()` on a query, which maps to `"1.0/queryStreamNext"` syscall:

```typescript
// From query_impl.ts:264-272
async next(): Promise<IteratorResult<any>> {
    const queryId = this.state.type === "preparing" ? this.startQuery() : this.state.queryId;
    const { value, done } = await performAsyncSyscall("1.0/queryStreamNext", {
        queryId,
    });
    if (done) {
        this.closeQuery();
    }
    const convexValue = jsonToConvex(value);
    return { value: convexValue, done };
}
```

---

## 3. Composability: Current State

### 3.1 Server-Side Composable Operators

Today, Convex has a **limited composable query pipeline** that supports:

1. **Sources** (mutually exclusive):
   - `FullTableScan` — scan entire table by creation order
   - `IndexRange` — scan a range of an index efficiently
   - `Search` — full-text search

2. **Operators** (chainable, applied sequentially):
   - `Filter(Expression)` — evaluate a boolean expression for each row, keep only matches
   - `Limit(usize)` — stop after N rows

**No built-in server-side map, reduce, or custom operators exist today.** All transformation logic runs in user-authored JavaScript.

### 3.2 Why Limited Composition?

1. **Expressions are evaluated server-side** (filter.rs:68):
   ```rust
   if self.expr.eval(&value)?.into_boolean()? {
       return Ok(QueryStreamNext::Ready(Some((document, write_timestamp))));
   }
   ```
   But expressions are simple AST nodes (Eq, Lt, And, Or, Field, Literal) — no function calls or arbitrary computation.

2. **All other logic runs in user JS:**
   - Group-by operations
   - Aggregations (sum, count, avg)
   - Transformations (map, projection)
   - Sorting (after initial index order)
   - Deduplication

3. **Batching & prefetch hints** are available at the operator level (e.g., `FILTER_QUERY_PREFETCH = 100` in filter.rs), but users can't extend this.

### 3.3 Extension Point: QueryOperator Enum

To add new composable operators (like Skip-authored mappers or reducers), the system would need to extend:

**File:** `crates/common/src/query.rs:899-904`

```rust
pub enum QueryOperator {
    Filter(Expression),
    Limit(usize),
    // Could add:
    // Map(MapperDescriptor),
    // Reduce(ReducerDescriptor),
    // etc.
}
```

And add corresponding `QueryNode` variants and `QueryStream` implementations.

---

## 4. UDF Types & API Boundaries

### 4.1 Current UDF Types

**File:** `npm-packages/convex/src/server/impl/registration_impl.ts`

Convex defines three UDF types:

#### Query Functions (registration_impl.ts:355-430)
- Read-only, reactive, cached on client
- Runs in V8 isolate with `GenericQueryCtx`
- Can call `ctx.db.query()`, `ctx.runQuery()`, access auth/storage (read-only)

```typescript
export const queryGeneric: QueryBuilder<any, "public"> = ((
  functionDefinition: FunctionDefinition,
) => {
  const handler = (...) as (ctx: GenericQueryCtx<any>, args: any) => any;
  const func = dontCallDirectly("query", handler) as RegisteredQuery<"public", any, any>;
  func.isQuery = true;
  func.isPublic = true;
  func.invokeQuery = (argsStr) => invokeQuery(handler, argsStr, "public");
  // ... args/returns validators
  return func;
}) as QueryBuilder<any, "public">;
```

#### Mutation Functions (registration_impl.ts:198-265)
- Read-write, transactional, not cached
- Runs in V8 isolate with `GenericMutationCtx`
- Can call `ctx.db.query()`, `ctx.db.insert/patch/delete()`, `ctx.runQuery()`, `ctx.runMutation()`, schedule functions

#### Action Functions (registration_impl.ts:500+)
- HTTP callouts, external side effects
- Runs in V8 isolate with `GenericActionCtx`
- Can call external APIs, run mutations/queries via `ctx.runMutation()`, `ctx.runQuery()`

### 4.2 Function Registration Mechanism

All three types use a common pattern:

```typescript
type FunctionDefinition =
  | ((ctx: any, args: DefaultFunctionArgs) => any)
  | {
      args?: GenericValidator | Record<string, GenericValidator>;
      returns?: GenericValidator | Record<string, GenericValidator>;
      handler: (ctx: any, args: DefaultFunctionArgs) => any;
    };

function exportArgs(functionDefinition: FunctionDefinition) {
  return () => JSON.stringify(args.json, strictReplacer);
}

function exportReturns(functionDefinition: FunctionDefinition) {
  return () => JSON.stringify(returns ? returns.json : null, strictReplacer);
}
```

Functions are wrapped with:
- `.invokeQuery()`, `.invokeMutation()`, or `.invokeAction()` — entry points for the backend
- `.exportArgs()` / `.exportReturns()` — validators for schema codegen
- Metadata flags: `.isQuery`, `.isPublic`, `.isInternal`, etc.

### 4.3 Potential API Boundaries for Skip Integration

#### Option A: Extend QueryOperator (In-Place Composition)
Add new query operator types to the pipeline:

```rust
pub enum QueryOperator {
    Filter(Expression),
    Limit(usize),
    SkipMap(SkipMapperDescriptor),      // New operator type
    SkipFilter(SkipFilterDescriptor),    // New operator type
}
```

**Pros:**
- Seamless integration with existing query pipeline
- No new syscall types needed
- Can compose with index ranges and existing filters
- Results in fully composable, server-side execution

**Cons:**
- Requires changes to query serialization format (npm-packages)
- Requires changes to QueryOperator enum (common/crates)
- Requires QueryNode variants and QueryStream impls

#### Option B: New UDF Type (Skip Function)
Register Skip-authored functions as a new kind of UDF:

```typescript
export const skipQuery = skipQueryBuilder<any, "public">((
  definition: SkipFunctionDefinition
) => {
  // Register a Skip-authored query function
  func.isSkipQuery = true;
  func.invokeSkipQuery = (...) => invokeSkipQuery(handler, ...);
  return func;
});
```

**Pros:**
- No changes to existing query pipeline
- Can be added in isolation in npm-packages/convex
- Can use Skip's own execution engine

**Cons:**
- Not composable with client-side `.filter()`, `.limit()`
- Separate execution path; can't combine with index ranges
- Queries would need to explicitly opt-in to Skip

#### Option C: Extend db.query() to Accept Skip Filters (Hybrid)
Add Skip filters at the JS API level:

```typescript
ctx.db.query("tasks")
  .withIndex("by_user", q => q.eq("userId", userId))
  .withSkipFilter(skipFilterCode)  // New method
  .collect()
```

This would serialize the Skip filter code and add it to the QueryOperator chain.

**Pros:**
- Familiar API extension
- Can compose with existing filters

**Cons:**
- Skip code still needs to be serialized and interpreted server-side
- Requires query format changes
- Adds complexity to TypeScript query builder

---

## 5. Key Files & Line References

### TypeScript Client (npm-packages/convex/src/server/)
| File | Purpose | Key Sections |
|------|---------|--------------|
| `query.ts` | Query interface definitions | 14-283: QueryInitializer, Query, OrderedQuery interfaces |
| `impl/query_impl.ts` | Query implementation | 24-42: SerializedQuery type; 44-147: QueryInitializerImpl; 161-345: QueryImpl with .filter(), .limit(), .collect() |
| `database.ts` | Database reader/writer | 211-240: withIndex() usage examples |
| `impl/registration_impl.ts` | UDF registration | 329-353: invokeQuery(); 355-430: queryGeneric definition |

### Rust Backend (crates/)
| File | Purpose | Key Sections |
|------|---------|--------------|
| `database/src/query/mod.rs` | Query execution | 79-126: QueryStream trait; 295-469: DeveloperQuery construction; 693-698: QueryNode enum; 729-768: QueryNode dispatch |
| `database/src/query/filter.rs` | Filter operator | 28-85: Filter struct and QueryStream impl |
| `database/src/query/limit.rs` | Limit operator | 23-83: Limit struct and QueryStream impl |
| `database/src/query/index_range.rs` | IndexRange source | IndexRange implementation |
| `common/src/query.rs` | Query types | 662-669: QuerySource enum; 899-904: QueryOperator enum; 675-712: Expression enum |
| `isolate/src/environment/udf/syscall.rs` | Sync syscall dispatch | 127-151: syscall_impl dispatch (`queryCleanup`, `queryStream` only); 221-246: syscall_query_stream; 96-107: start_query |
| `isolate/src/environment/udf/async_syscall.rs` | Async/batched dispatch | `queryStreamNext` joins the Reads batch; `queryPage` via the Unbatched query_page path |

---

## 6. Integration Opportunities for Skip

### 6.1 Current Path (Recommended for MVP)
User JS code calls Skip-authored functions directly, without server-side composition:

```typescript
// In a Convex query
export const tasksByUserAndStatus = query({
  handler: async (ctx, args) => {
    const allTasks = await ctx.db.query("tasks")
      .withIndex("by_user", q => q.eq("userId", args.userId))
      .collect();
    return Skip.filter(allTasks, skipFilterCode);  // Skip filtering in JS
  }
});
```

**Pros:**
- No Rust changes needed
- Can ship immediately
- Full control over Skip execution

**Cons:**
- Not server-side; doesn't benefit from index prefetch, early termination
- All data loaded into JS memory first

### 6.2 Deep Integration (Future)
Extend QueryOperator and QueryNode to support Skip mappers/filters as first-class pipeline operators:

1. **Serialize Skip code** into the query descriptor (alongside Filter expressions)
2. **Add QueryOperator::SkipFilter(code)** to `crates/common/src/query.rs:899-904`
3. **Implement QueryStream for Skip filter** in `crates/database/src/query/skip_filter.rs`
4. **Update query builder** in `npm-packages/convex/src/server/impl/query_impl.ts` to add `.withSkipFilter()` or `.skipFilter()`

This would allow:

```typescript
ctx.db.query("tasks")
  .withIndex("by_user", q => q.eq("userId", userId))
  .limit(100)
  .withSkipFilter(skipFilterCode)  // Composed server-side!
  .collect()
```

With the Skip filter executing as part of the server-side pipeline, interleaved with prefetch and limit logic.

### 6.3 QueryNode Pipeline After Skip Integration

```
IndexRange (read index: by_user)
  ↓
SkipFilter (run Skip code on each row)
  ↓
Limit (stop after 100)
  ↓
Result
```

Each operator wraps the previous, calling `.next()` to pull from upstream, evaluating its logic, and returning results downstream.

---

## 7. Summary

| Aspect | Current State |
|--------|---------------|
| **Query Composition** | Limited: IndexRange source + Filter + Limit operators only |
| **Server-Side Transformation** | Only simple boolean expressions (Filter); everything else in user JS |
| **UDF Types** | query, mutation, action (three distinct types) |
| **Syscall Interface** | "1.0/queryStream", "1.0/queryStreamNext" → DB queries |
| **Pipeline Architecture** | QueryNode tree with QueryStream trait; extensible via new enum variants |
| **Extension Point** | Add QueryOperator types, QueryNode variants, and QueryStream impls |

**For Skip integration:**
- **MVP:** Use Skip in user JS functions (no infrastructure changes)
- **Long-term:** Extend QueryOperator and implement QueryStream for Skip filters to enable deep server-side composition

