# Skip Externals/Resources and Convex Adapter Research

## Part A: Skip Externals/Resources and skipruntime-ts

### 1. What is a Skip "External" / "Resource"?

A Skip **external** (or **external resource**) is a mechanism for integrating external data sources into Skip's reactive system. It provides a bridge between the Skip runtime and non-reactive or partially-reactive external systems.

**Core concept:**
- The `ExternalService` type is a generic interface that can be implemented to wrap arbitrary external systems for use in a Skip service.
- Each Skip reactive service specifies zero or more `ExternalService` implementations.
- External data is brought into the reactive computation graph as an `EagerCollection` via the `Context#useExternalResource` method.
- Once imported this way, external data can be manipulated using the same reactive operations as native Skip collections (mapping, filtering, querying).

**How external data enters the reactive system:**

1. A Skip service definition includes an `externalServices` field mapping resource names to `ExternalService` implementations.
2. Within the `createGraph` function (or mapper/reducer/resource functions with access to `Context`), call `context.useExternalResource({ service: "serviceName", identifier: "resourceName", params: {...} })`.
3. This returns an `EagerCollection<K, V>` representing that external resource.
4. The collection is eagerly kept up-to-date whenever inputs change, and can participate in all Skip reactive operations.

**Built-in implementations:**
- `SkipExternalService`: Connects reactive Skip services together
- `PostgresExternalService`: Subscribes to reactive updates from a PostgreSQL database
- `KafkaExternalService`: Connects to and consumes messages from a Kafka cluster
- `PolledExternalService`: Polls non-reactive HTTP endpoints

**Custom implementations:**
- Users can extend the `ExternalService` interface to define arbitrary `subscribe`/`unsubscribe` logic for systems that don't fit the built-in patterns.

### 2. The Polling-Based Integration Model

**Concretely, `PolledExternalService` works as follows:**

```typescript
new PolledExternalService({
  my_resource: {
    // HTTP endpoint to poll
    url: "https://api.example.com/my_resource",
    // Polling interval in milliseconds
    interval: 5000,
    // Converter function: transforms HTTP response into Skip's key-value structure
    // Expected signature: (data: Json) => Entry<K, V>[]
    // where Entry<K, V> = [key, [value]]
    conv: (data: Json) => Array.from(data, (v, k) => [k, [v]])
  }
})
```

**How it operates:**

1. Skip periodically (every `interval` milliseconds) sends HTTP GET requests to the specified `url` with the `params` passed to `useExternalResource`.
2. The converter function (`conv`) transforms the response into Skip's entry structure: an array of `[key, [value]]` tuples.
3. These entries are fed into Skip's reactive system as updates to the external collection.
4. Skip recomputes any dependent maps/reduces when the collection changes.

**Key characteristic:**
- This approach works with non-reactive APIs that only support pull (request/response).
- The frequency of polls is a tuning parameter depending on latency requirements and external system load capacity.
- The entire result is polled each interval; Skip performs diffing to determine what actually changed.

### 3. skipruntime-ts: Architecture and Public API

**What is skipruntime-ts:**

`skipruntime-ts` is the TypeScript/JavaScript runtime for Skip, located at `/Users/bill/src/skip/skipruntime-ts`. It is the bridge allowing TS/JS applications to host and interact with Skip's incremental-computation engine via WASM bindings.

**Directory structure:**

```
skipruntime-ts/
├── core/              # Core runtime implementation (@skipruntime/core)
├── addon/             # WASM bindings
├── server/            # HTTP server for streaming & control APIs
├── helpers/           # Convenience exports (PolledExternalService, etc.)
├── adapters/          # External system adapters
│   ├── postgres/      # PostgreSQL adapter
│   ├── kafka/         # Kafka adapter
│   └── convex/        # Convex adapter (in billf/convex/adapter branch)
├── examples/          # Working examples
└── wasm/              # WASM compilation
```

**Public API shape (via @skipruntime/core and @skipruntime/helpers):**

**Collections:**
- `EagerCollection<K, V>`: Keyed values, eagerly kept up-to-date
  - Methods: `getArray(key)`, `getUnique(key, defaults)`, `map(MapperClass, ...params)`, `reduce(ReducerClass, ...params)`, `merge(...others)`, `slice()`, `take()`, etc.
- `LazyCollection<K, V>`: Computed on-demand, cached after first query
  - Methods: `getArray(key)`, `getUnique(key, defaults)`

**Mappers and Reducers:**

Mappers transform one collection into another:
```typescript
class MyMapper implements Mapper<K1, V1, K2, V2> {
  mapEntry(key: K1, values: Values<V1>, context: Context): Iterable<[K2, V2]> {
    // Transform each key-values entry into zero or more output pairs
  }
}
```

Reducers accumulate a key's values:
```typescript
class MyReducer implements Reducer<V, A> {
  initial: A | null;
  add(accum: A | null, value: V): A;
  remove(accum: A, value: V): A | null;
}
```

**Resources:**

A resource is a collection that is queryable and subscribable:
```typescript
class MyResource implements Resource<NamedEagerCollections> {
  instantiate(graph: NamedEagerCollections, context: Context): EagerCollection<K, V> {
    // Return a collection (usually from the graph, possibly transformed)
  }
}
```

**Service Definition:**
```typescript
const service: SkipService<Inputs, Resources, Graph> = {
  inputs: {
    // Named input collections with initial data
    "myInput": { initial: [...] }
  },
  resources: {
    // Named resource classes
    "myResource": MyResourceClass
  },
  externalServices: {
    // Named external service implementations
    "postgres": new PostgresExternalService(...)
  },
  createGraph(inputCollections: NamedEagerCollections, context: Context): Graph {
    // Build and return the reactive graph
    // Use context.useExternalResource to pull in external data
    // Use context.createLazyCollection to create on-demand collections
  }
};

const instance = await runService(service);
```

**ServiceInstance API:**
- `instantiateResource(id, resourceName, params)`: Create a new queryable instance
- `getAll<K, V>(resourceName, params)`: Get all current values
- `getArray<K, V>(resourceName, key, params)`: Get values for a specific key
- `subscribe(id, notifier, watermark)`: Subscribe to updates with callbacks
  - `notifier.subscribed()`: Called when subscription is ready
  - `notifier.notify(update)`: Called on each batch of updates (update contains `values[]`, `watermark`, `isInitial`)
  - `notifier.close()`: Called when subscription ends
- `unsubscribe(id)`: Cancel a subscription
- `update(collection, entries)`: Modify an input collection
- `close()`: Shut down the service

### 4. Integration Implications for TypeScript Applications

**Option A: Client Polling/Subscribing to Skip as an Observable Reactive Source**

A TS client (e.g., a browser or Convex client) would:

1. **Connect to a running Skip service** (hosted separately, or locally)
2. **Create a resource instance** via HTTP: `POST /skip-control/v1/streams/:resource`
3. **Subscribe to updates** via HTTP EventSource: `GET /skip-stream/v1/streams/:streamId`
4. **Receive streaming updates** as Server-Sent Events (SSE):
   - Initial snapshot: `event: init`, data contains `[[key, [value1, ...]], ...]`
   - Updates: `event: update`, data contains delta entries
5. **Apply updates locally** (React state, TanStack DB, etc.)
6. **Unsubscribe** via HTTP: `DELETE /skip-control/v1/streams/:streamId`

This is a **thin polling model**: the client is a reactive consumer of Skip's outputs, but writes still go to the original source (Convex mutations, Postgres inserts, etc.), not to Skip.

**Option B: Hosting/Embedding Skip's Engine Directly**

A TS application would:

1. **Import @skipruntime/core and helpers** into its Node.js process or bundled web app
2. **Define a SkipService** with mappers, reducers, resources, and external service subscriptions
3. **Call `runService(service)`** to initialize the in-memory Skip engine
4. **Query the engine directly** via `ServiceInstance` methods (no HTTP needed)
5. **Manually subscribe and apply updates** in-process

This is a **deep embedding model**: Skip runs in-process, can access local data and state directly, and is faster (no network roundtrip), but requires direct TS/JS dependency and cannot easily be shared across processes or languages.

**Key architectural trade-off:**

- **Polling/HTTP model** (Option A): Loose coupling, works across languages and processes, but incurs network latency and complexity of HTTP lifecycle management (reconnection, backoff, etc.).
- **Direct embedding** (Option B): Tight coupling, lower latency, simpler code, but one service instance per process, harder to scale horizontally.

A real system might use **Option A for user-facing clients** (browser/mobile) and **Option B for backend services** that need tight Skip integration with other systems.

---

## Part B: The billf/convex/adapter Branch

### 1. Branch Location and Status

**Found in:** `/Users/bill/src/skip` repository

**Available as:**
- Local branch: `billf/convex/adapter` (HEAD)
- Remote-tracking: `origin/billf/convex/adapter`
- Also `origin/billf/convex/adapter-2` (experimental variant)

**Not found in:** `/Users/bill/src/convex-backend` (no billf branches with convex/adapter)

### 2. What the Adapter Branch Does

**New code added:**

1. **`skipruntime-ts/adapters/convex/`** (~1000 lines)
   - Package: `@skip-adapter/convex`
   - Main export: `ConvexExternalService<Row>`
   - Helper: `defineConvexReactiveResource<Row, Query>()`
   - Utilities: `diffSnapshot()`, `assertSkipJson()`, `createAuthenticatedConvexClient()`

2. **`examples/convex_reactive/`** (~400 lines of application code + config)
   - Demonstrates Skip + Convex integration
   - Includes TypeScript service, React UI, HTTP server setup
   - Has a detailed `DESIGN.md` explaining the architecture and limitations

3. **`examples/convex_tanstack/`**
   - Similar integration example using TanStack Query/DB

**Commit history (in chronological order):**
- Initial work on fixing subscription recovery and ownership boundaries
- "Extract shared adapter" commit: moves reusable adapter logic into the `@skip-adapter/convex` package
- Various fixes: bootstrap snapshot retry, lifecycle management, caller-vs-service ownership
- Example integration building

### 3. The ConvexExternalService: How It Works

**Core idea:**

The adapter bridges Convex's reactive query snapshots into Skip's delta-based collections. It implements the `ExternalService` interface so that a Skip service can subscribe to Convex queries and reactively update its graph.

**Architecture:**

```typescript
export class ConvexExternalService<Row extends Json>
  implements ExternalService {
  
  constructor(
    convex: string | ConvexSubscriber,  // URL or ConvexClient instance
    resources: {
      [resourceName: string]: ConvexReactiveResource<Row>
    },
    options: ConvexExternalServiceOptions
  ) { ... }
  
  async subscribe(
    instance: string,
    resourceName: string,
    params: Json,
    callbacks: { update(...), error(...) }
  ): Promise<void>
}
```

**Resource definition:**

```typescript
type ConvexReactiveResource<Row> = {
  query: FunctionReference<"query">;  // e.g., api.workspace.snapshot
  getKey: (row: Row) => string;       // Extract string key from each row
  argsFromParams: (params: Json, scope: ConvexServiceScope) => unknown;  
                                      // Map Skip params to Convex query args
};
```

**Subscription flow:**

1. Skip calls `ConvexExternalService.subscribe()` for a resource
2. The adapter attaches to the Convex query via `ConvexClient.onUpdate(query, args, callback, errorCallback)`
3. When Convex re-evaluates the query, it delivers the **full result** (a new array of rows)
4. The adapter:
   - Compares the new snapshot with the previous one
   - Diffs to detect added, modified, and deleted rows
   - Converts rows to Skip's `Entry<string, Row>[]` format
   - Delivers updates to Skip via `callbacks.update(entries, isInitial)`
5. Skip recomputes maps/reduces that depend on that external collection

**Snapshot diffing strategy:**

```typescript
function diffSnapshot<Row>(
  previous: Map<string, Row>,
  rows: Row[],
  getKey: (row: Row) => string
): { next: Map<string, Row>, updates: Entry<string, Row>[] }
```

- For each row in the new result: check if key exists and if value changed
- Emit `[key, [newValue]]` for additions/updates
- Emit `[key, []]` (empty value) for deletions
- This delta is fed into Skip as one batch

**Error handling & recovery:**

- On subscription failure or Convex delivery error: automatically attempts to re-establish the subscription with exponential backoff
- Configurable `maxResubscribeAttempts` (default 5) and `resubscribeBackoffMs` (default 100ms)
- After max attempts, the subscription goes inert (must be unsubscribed and re-created to retry)

**Scope and tenant isolation:**

- Each adapter instance is bound to a `ConvexServiceScope` (currently just `{ tenantId: string }`)
- This allows multiple adapters to serve different tenants without cross-contamination

### 4. Example Integration: convex_reactive

**Data flow:**

```
Convex mutations → Database updates
     ↓
Convex query (workspace.snapshot)
     ↓
ConvexClient.onUpdate → full-snapshot delivery
     ↓
Full-snapshot keyed diff
     ↓
Skip external resource updates
     ↓
Skip map/reduce (ProjectsOnly, TasksOnly, TasksByProject, AttachTotals)
     ↓
EagerCollection<string, ProjectSummary>
     ↓
Skip HTTP server (SSE streaming)
     ↓
React browser client (useProjectSummaries hook)
```

**Skip service structure:**

```typescript
new ConvexExternalService<WorkspaceRow>(convexUrl, {
  workspace: defineConvexReactiveResource({
    query: api.workspace.snapshot,  // Convex query
    getKey: (row) => row.key,
    argsFromParams: (params, scope) => {
      // Map Skip params to Convex query args (usually empty)
      return {};
    }
  })
}, { scope: { tenantId: "demo" } })

// In createGraph:
const workspace = context.useExternalResource({
  service: "convex",
  identifier: "workspace",
  params: {}
});

// Apply mappers to extract projects, tasks, and compute totals
const projects = workspace.map(ProjectsOnly);
const tasks = workspace.map(TasksOnly);
const totals = tasks.map(TasksByProject).reduce(AddTaskTotals);
const summaries = projects.map(AttachTotals(totals));
```

**Browser integration (React):**

```typescript
// HTTP-based client streaming
function useProjectSummaries() {
  // 1. Create a stream: POST /skip-control/v1/streams/projectSummaries
  // 2. Open EventSource: GET /skip-stream/v1/streams/{streamId}
  // 3. Listen for "init" (full snapshot) and "update" (deltas)
  // 4. Apply to React state
  // 5. Clean up stream on unmount: DELETE /skip-control/v1/streams/{streamId}
}
```

### 5. Integration Strategy & Architectural Approach

**What kind of adapter is this?**

**Classification: Snapshot-based polling adapter with reactive diffing**

- **Not a direct streaming/cursor-based integration**: The Convex sync protocol delivers whole query results (`QueryUpdated` messages carry `value: JSONValue` – the entire snapshot), not row-level change events. There is no lower-level delta protocol exposed by the Convex TypeScript client.
- **Not an at-rest polling adapter**: Unlike `PolledExternalService`, the Convex adapter uses the live `onUpdate` subscription, so updates are pushed as soon as Convex recomputes the query.
- **Efficient diffing**: Leverages JavaScript's `isDeepStrictEqual` to detect which rows changed, avoiding Skip re-computation for unchanged data.

**Integration boundary:**

- **Data source**: Convex (mutable source of truth)
- **Derived computations**: Skip (read-only reactive projection)
- **Write path**: Mutations go to Convex; Skip is never written to (no input collections filled from client writes)
- **Consistency model**: Updates are eventually consistent. A Convex mutation commits → query reruns → adapter receives snapshot → Skip recomputes → SSE reaches browser. There is a lag between Convex and Skip state, visible in the example.

**Design principles stated in DESIGN.md:**

1. Use Skip only when maintaining a shared incremental projection that is expensive to reproduce per client, combines multiple sources, or already serves non-Convex consumers. For a simple view over only Convex data, use a Convex query instead.

2. The integration is at the TypeScript client level, not a lower layer (database cursor, streaming export API, etc.). Any client protocol that speaks the same snapshot-based sync would have the same constraints.

3. Convex operations:
   - **Reads**: Via the reactive snapshot subscription in the adapter
   - **Writes**: Via Convex mutations, never through Skip input collections

4. Optionally support **authenticated clients** via `createAuthenticatedConvexClient()`, which accepts an async token fetcher.

**Limitations acknowledged:**

- O(n) full-result diffing for every query reevaluation (fine for small queries, unsuitable for unbounded tables)
- Queries and mutations in examples are public/unauthenticated (production needs narrowly scoped service identity)
- Rejected updates tear down and re-establish the Convex subscription (snapshot recovery, not durable replay)
- Skip control port has no auth (must sit behind an API gateway in production)
- In-memory previous snapshot is rebuilt after Skip restart (no durable delta replay)

### 6. Why the Adapter Branch Approach Is Limited

**The adapter as currently implemented:**

- Handles only full-snapshot data from Convex's TypeScript client
- Requires periodic re-diffing on each update
- No row-level deltas or streaming cursors

**What a "better integration" would address:**

1. **Lower-level protocol**: Access Convex's internal streaming/cursor-based APIs (if available) to receive row-level changes rather than full snapshots
2. **Durable delta replay**: Store and replay change deltas so Skip restart doesn't require re-fetching full state
3. **Unified write/read**: Either allow Skip input collections to be the source of truth (with Convex eventually-consistent), or provide clearer mutation APIs
4. **Larger query support**: Optimize or parallelize diffing for very large result sets
5. **Built-in auth**: Move Convex auth handling into the adapter framework itself

The current adapter is a solid proof-of-concept and suitable for small-to-medium projections, but would need architectural changes for production use at scale.

---

## Summary: Three Integration Models

| Aspect | HTTP Polling (PolledExternalService) | Convex Adapter (billf/convex/adapter) | Direct Embedding |
|--------|--------------------------------------|---------------------------------------|-----------------|
| **Source** | Non-reactive HTTP endpoints | Convex live queries | Direct in-process data |
| **Pull mechanism** | Periodic HTTP GET | Convex `onUpdate` callback | Direct method calls |
| **Delta semantics** | Full-result polling, Skip diffs | Full-snapshot diffing, JS `isDeepStrictEqual` | Direct object references |
| **Write path** | Not in adapter (outside scope) | Convex mutations (not through Skip) | Can be in-process |
| **Deployment** | Separate Skip service + client | Separate Skip service + Convex backend + client | In-process only |
| **Latency** | Polling interval | ~milliseconds (live subscription) | Microseconds |
| **Consistency** | Stale between polls | Eventually consistent (multi-hop) | Immediate |
| **Scaling** | Horizontal (many Skip services) | Horizontal (multiple adapters, scoped tenants) | Vertical only (one process) |

