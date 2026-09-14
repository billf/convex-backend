---
title: Skip's Core Incremental Engine
type: research-note
status: active
direction: foundation
date: 2026-09-11
---

# Skip's Core Incremental Engine: Research Findings

## Executive Summary

Skip is a reactive services framework that combines a domain-specific language (Skip language) with a TypeScript-based incremental runtime engine. The incremental engine implements a **reactive dataflow graph** model where collections (vertices) are transformed by mappers and reducers (edges), with automatic change propagation ensuring that only affected nodes recompute when inputs change.

---

## 1. What is Skip? Language vs. Runtime/Engine

### Short Answer
Skip is **both a language and a runtime**:
- **Language**: Skip (in `skiplang/` directory) is a compiled language (to WebAssembly or native binaries) that provides static analysis and type safety for reactive computation definitions.
- **Runtime/Engine**: Skip Runtime (in `skipruntime-ts/`) is the incremental computation engine, implemented in TypeScript with WebAssembly/native bindings, that executes reactive computations.

### Repository Structure

**Top-level directories:**
- `/Users/bill/src/skip/skiplang/` — The Skip language compiler (written in Skip itself)
  - `compiler/` — Core compiler with lexer, parser, IR generation, optimization, LLVM output
  - `prelude/` — Standard library
  - `skjson/`, `skdate/` — Language libraries for JSON/dates
  
- `/Users/bill/src/skip/skipruntime-ts/` — TypeScript runtime for reactive services
  - `core/` — Public API for reactive collections (Mapper, Reducer, LazyCompute interfaces)
  - `server/` — HTTP/SSE server layer to expose Skip services
  - `wasm/`, `addon/` — WebAssembly bindings and native Node.js bindings to the runtime engine
  - `adapters/` — External service integrations (Convex, PostgreSQL, Kafka)
  - `helpers/` — PolledExternalService, REST utilities

- `/Users/bill/src/skip/sql/` — SQL compatibility layer
- `/Users/bill/src/skip/examples/` — Example reactive services
- `/Users/bill/src/skip/rfc/` — Design RFCs (especially RFC 008 on reactive services)

### Core Incremental Mechanism

Skip implements incremental computation through a **reactive collection graph** with these key principles:

1. **Collections as Vertices**: Data is organized into named collections, each associating keys to multiple values
   - **EagerCollections**: "reactively kept up-to-date" — automatically recomputed whenever dependencies change
   - **LazyCollections**: computed on-demand when queried, then memoized

2. **Mappers & Reducers as Edges**: Deterministic, side-effect-free functions that transform data
   - **Mapper**: transforms key-value pairs from one collection to another (`mapEntry(key, values) → Iterable<[K2, V2]>`)
   - **Reducer**: accumulates values for each key over time (`add()`, `remove()` operations)

3. **Dependency Tracking & Propagation**:
   - When `collection.map(MapperClass, params)` is called, the runtime records a dependency edge
   - When an input collection receives an update (via `PATCH /v1/inputs/:collection`), the runtime:
     - Identifies affected downstream collections
     - Incrementally re-evaluates only the changed entries (not the entire collection)
     - Propagates updates through the graph reactively
   - **Watermarks** track progress through updates, enabling partial results and subscriptions to intermediate states

4. **Memoization & Incremental Deltas**:
   - Lazy collections cache computed results per key so repeated queries on the same key avoid recomputation
   - For eager collections, the reducer's `remove()` function can perform inverse operations (e.g., subtract in a sum reducer) instead of full recomputation
   - When `remove()` is uncertain, it returns `null` and the runtime falls back to full recomputation of that key's accumulation

**Evidence from code:**

From `/Users/bill/src/skip/skipruntime-ts/core/src/api.ts`:
```typescript
interface Mapper<K1, V1, K2, V2> {
  mapEntry(key: K1, values: Values<V1>, context: Context): Iterable<[K2, V2]>;
}

interface Reducer<V, A> {
  initial: A | null;
  add(accum: A | null, value: V): A;
  remove(accum: A, value: V): A | null;  // Returns null to trigger full recomputation
}
```

From RFC 008 (`/Users/bill/src/skip/rfc/008-reactive-services.org`):
> "A reactive service defines a compute graph made of skip runtime reactive collections"
> The service exposes "resources (analogous to REST resources), which are parameterized, dynamically generated, read-only, skip runtime reactive collections"

---

## 2. Reactive Collections: Representation, Composition, and Change Detection

### Data Representation

**Collections** are the fundamental data structure:
- Each collection is a multi-map: `key → value[]` (a key maps to multiple values)
- Collections are named and typed as `EagerCollection<K, V>` or `LazyCollection<K, V>`
- Data flows through **Entries**: `[K, V[]]` tuples (from RFC/api.ts: `export type Entry<K, V> = [K, V[]]`)
- Updates are bundled into **CollectionUpdate** objects with a watermark (abstract time) and a flag indicating initial vs. incremental data

From `/Users/bill/src/skip/skipruntime-ts/core/src/api.ts`:
```typescript
export type Entry<K extends Json, V extends Json> = [K, V[]];

export type CollectionUpdate<K extends Json, V extends Json> = {
  values: Entry<K, V>[];      // Keys and their new values
  watermark: Watermark;        // Abstract time marker for this update
  isInitial?: boolean;         // true if this is the first chunk of data
};
```

### Transformation Composition

**Eager Collections** support composable transformations:

1. **map()** — Apply a Mapper to each entry:
   ```typescript
   collection.map(MapperClass, ...params): EagerCollection<K2, V2>
   ```
   - The mapper receives each `[key, values[]]` entry and produces new `[key2, value2]` pairs
   - This records a dependency edge in the graph (critical for propagation)

2. **reduce()** — Accumulate values per key using a Reducer:
   ```typescript
   collection.reduce(ReducerClass, ...params): EagerCollection<K, Accum>
   ```
   - For each key, applies `reducer.add()` for each value (or `reducer.remove()` when a value leaves)
   - Enables efficient aggregations (sum, count, etc.) without full recomputation

3. **mapReduce()** — Fused map + reduce for efficiency:
   ```typescript
   collection.mapReduce(MapperClass, ...mapperParams)(ReducerClass, ...reducerParams)
   ```
   - Avoids materializing the intermediate collection

4. **merge()** — Combine multiple collections:
   ```typescript
   collection.merge(...otherCollections): EagerCollection<K, V>
   ```

5. **slice()/slices()/take()** — Range-based filtering

**Lazy Collections** are computed on-demand:
```typescript
interface LazyCollection<K, V> {
  getArray(key: K): V[];
  getUnique(key: K, defaults?): V;
}

interface LazyCompute<K, V> {
  compute(self: LazyCollection<K, V>, key: K, context: Context): Iterable<V>;
}
```
- `compute()` can recursively query the same lazy collection (memoized) or create new collections
- Intermediate lazy collections used by eager computations are memoized per computation cycle

### Change Detection & Minimal Recomputation

When an input collection is updated via `PATCH /v1/inputs/:collection`:

1. **Entry-Level Granularity**:
   - Only changed keys are re-processed
   - For each changed `[key, newValues]`, the runtime:
     - Calls the downstream mapper's `mapEntry(key, newValues)` if the collection was formed by a map
     - For a downstream reducer-based collection, the runtime calls `add()` for each new value and `remove()` for each old value

2. **Reducer Optimization** (critical for incremental efficiency):
   - If values `[v1, v2, v3]` become `[v2, v3, v4]`:
     - Call `remove(accum, v1)` to subtract v1 from the accumulated value
     - Call `add(accum, v4)` to add v4
   - If the reducer's `remove()` is uncertain (returns `null`), the runtime falls back to recomputing the accumulation from scratch using `initial` and `add()`
   - This allows **incremental aggregations**: a sum reducer only needs to subtract the old value and add the new value, not rescan all values

**Evidence from api.ts:**
```typescript
// Reducer's remove function:
/**
 * Exclude a previously added value from the accumulated value.
 * It is always valid for `remove` to return `null`, in which case the correct 
 * accumulated value will be computed using `initial` and `add` on each of the key's values.
 */
remove(accum: A, value: V & DepSafe): A | null;
```

### Example: Incremental Sum

From `/Users/bill/src/skip/skipruntime-ts/examples/sum.ts`:
```typescript
class Plus implements Mapper<string, number, string, number> {
  mapEntry(key: string, values: Values<number>): Iterable<[string, number]> {
    return [[key, values.toArray().reduce((p, c) => p + c, 0)]];
  }
}
// Usage: collection.map(Plus)
```

For a reducer-based sum:
- `initial = 0`
- `add(accum, value) = accum + value`
- `remove(accum, value) = accum - value`
- When a value is added/removed, only O(1) arithmetic is needed, not O(n) rescanning

---

## 3. Codebase Structure & Separation of Language and Runtime

### Language vs. Runtime Separation

**Skip Language (Compiler)**: `/Users/bill/src/skip/skiplang/compiler/src/`
- Written in Skip itself (self-hosted compiler)
- Compiles `.sk` programs to LLVM IR → native binaries or WebAssembly
- Provides:
  - Type checking and inference
  - Optimization (inlining, dead code elimination, etc.)
  - Code generation

**Skip Runtime**: `/Users/bill/src/skip/skipruntime-ts/`
- TypeScript implementation (with WebAssembly bindings)
- Executes reactive computations at runtime
- Manages:
  - Collection storage and querying
  - Dependency graph tracking
  - Change propagation
  - External service subscriptions

### Directory Layout Overview

```
/Users/bill/src/skip/
├── skiplang/                           # Skip Language & Compiler
│   ├── compiler/
│   │   ├── src/                        # ~2.9MB of .sk compiler source
│   │   │   ├── compile.sk              # Entry point
│   │   │   ├── IR.sk                   # Intermediate representation
│   │   │   ├── lower.sk                # Lower to machine code
│   │   │   ├── optimize.sk             # Optimizations
│   │   │   ├── AsmOutput.sk            # Assembly/LLVM output
│   │   │   └── ... ~100 more .sk files
│   │   ├── tests/                      # Compiler test suite
│   │   └── Makefile
│   ├── prelude/                        # Standard library
│   └── skjson/, skdate/, etc.          # Language-specific libraries
│
├── skipruntime-ts/                     # Skip Runtime Engine
│   ├── core/                           # Public API surface (api.ts)
│   │   ├── src/
│   │   │   ├── api.ts                  # EagerCollection, LazyCollection, Mapper, Reducer
│   │   │   ├── internal.ts             # Type-erased internals
│   │   │   ├── errors.ts               # Runtime errors
│   │   │   └── binding.ts              # FFI to WASM/native
│   │   └── README.md
│   ├── server/                         # HTTP/SSE Server
│   │   ├── src/
│   │   │   ├── server.ts               # runService() - starts HTTP servers
│   │   │   └── rest.ts                 # Control/Streaming API routes
│   │   └── README.md
│   ├── wasm/                           # WebAssembly bindings
│   │   └── README.md (points to @skipruntime/wasm npm package)
│   ├── addon/                          # Native Node.js bindings
│   ├── adapters/                       # External service integrations
│   │   ├── convex/
│   │   ├── postgres/
│   │   └── kafka/
│   ├── helpers/                        # Utilities
│   │   ├── external.ts                 # PolledExternalService
│   │   ├── rest.ts
│   │   └── remote.ts
│   ├── examples/                       # Example services (sum, departures, groups, etc.)
│   └── tests/
│
├── rfc/                                # Design RFCs
│   ├── 006-incremental-constraints.org # Reactive views with constraints
│   └── 008-reactive-services.org       # Architecture & APIs
│
└── sql/                                # SQL layer (compatibility)
```

### Clear API Boundary

The separation is enforced by the **public API** in `skipruntime-ts/core/src/api.ts`:
- **Clients** (user services) implement `SkipService`, `Resource`, `Mapper`, `Reducer`, `LazyCompute` interfaces
- **Runtime** (internal) executes these interfaces
- The runtime itself is packaged as `@skipruntime/wasm` or `@skipruntime/native` (C++ bindings), which are opaque modules imported by `runService()`

This means:
- **Language layer** is independent—it compiles Skip code to binaries
- **Runtime layer** is independent—it executes reactive graphs defined via TypeScript classes (or any language that can call the FFI)
- They are **orthogonal**: you can write reactive services in TypeScript without using the Skip language compiler

---

## 4. Skip's Incremental Engine vs. Traditional Database Reactivity

### What Skip Provides That Databases Don't

Traditional databases (PostgreSQL, etc.) re-run entire queries when inputs change:

```sql
-- Traditional: Every time a row changes, the ENTIRE query re-executes
SELECT user_id, COUNT(*) as tweet_count
FROM tweets
GROUP BY user_id
-- If user 123 tweets once, re-scan ALL tweets and recompute ALL group counts
```

**Skip's incremental engine is fundamentally different:**

1. **Operator-Level Delta Propagation**
   - Skip doesn't re-run the entire query graph
   - When a single value is added/removed from an input collection, only the **affected computations** recompute
   - For a count reducer, adding one tweet just increments the counter (O(1)), not rescanning all tweets

   **Example incremental path**:
   ```
   tweets collection: {user_123: [tweet1, tweet2]} → {user_123: [tweet1, tweet2, tweet3]}
   
   Downstream count reducer:
   - Old state: count(user_123) = 2
   - Receives: add(2, tweet3) → returns 3
   - No re-scan of all tweets for user 123
   ```

2. **Memoization of Expensive Computations**
   - Lazy collections cache per-key results
   - Recursive computations (e.g., graph traversal) in `LazyCompute.compute()` avoid redundant paths
   - If a large computation depends on changed keys, only those keys' computations rerun; unaffected keys' results are reused

   **Example**:
   ```
   LazyCompute: compute paths from node A to all reachable nodes
   If node A's outgoing edges change, recompute just node A's path
   If node Z (unreachable from A) changes, no recomputation for A's paths
   ```

3. **Structured Transformations Enable Operator Optimization**
   - Every map/reduce/mapReduce operation is **recorded as a graph edge**
   - The runtime knows the exact structure of the computation
   - It can optimize globally: fuse operations, reorder, prune unchanged subgraphs
   - Databases use query optimizers, but the result is still a single query execution; Skip optimizes the **entire dependency graph**

   **Example fusion** (`mapReduce` vs. separate `map` + `reduce`):
   ```typescript
   // Separate (materialized intermediate):
   collection.map(Mapper).reduce(Reducer)  // Produces intermediate collection
   
   // Fused (no intermediate):
   collection.mapReduce(Mapper)(Reducer)   // Skips intermediate materialization
   ```

4. **Hierarchical Propagation & Watermarks**
   - Updates flow through the dependency graph with **watermarks** (abstract time markers)
   - Clients can subscribe to partial results at any watermark
   - This enables **streaming architectures**: clients see results as they're incrementally computed, not all-at-once

   **Example**:
   ```
   Input collection receives 1000-entry update
   Watermark 1: First 100 entries processed → client sees partial result
   Watermark 2: Next 100 entries processed → client sees new update
   ...
   (vs. database: client waits for all 1000 entries to be re-indexed, then gets one result)
   ```

5. **Reducer Contracts Enable Correctness Guarantees**
   - A `Reducer.remove()` function **must** satisfy: if you remove a value and re-add it, you get the original accumulated value
   - This enables safe incremental updates with the confidence that results are **always correct**, not just approximately fast
   - Databases provide ACID guarantees on data; Skip provides **equivalence guarantees on computation results**

   **Evidence from api.ts**:
   ```typescript
   /**
    * WARNING: If `remove` returns a non-`null` value, then it **must** be equal to 
    * calling `add` on each of the values associated to the key, starting from `initial`.
    * That is, `accum`, `add(remove(accum, value), value)`, and 
    * `remove(add(accum, value), value)` must all be equal.
    */
   ```

### Concrete Comparison: Counting Tweets by User

**Database approach** (PostgreSQL):
```sql
SELECT user_id, COUNT(*) as tweet_count
FROM tweets
GROUP BY user_id;

-- User 123 posts a new tweet
-- Database: Re-scan the entire tweets table, recompute all groups, return new result
-- Cost: O(n) where n = total tweets in database
```

**Skip approach**:
```typescript
class CountTweets implements Reducer<Tweet, number> {
  initial = 0;
  add(accum: number, tweet: Tweet): number {
    return accum + 1;
  }
  remove(accum: number, tweet: Tweet): number {
    return accum - 1;
  }
}

tweets.reduce(CountTweets);

// User 123 posts a new tweet
// Skip: 
//   1. Upstream identifies that user_123's entry changed
//   2. Calls CountTweets.add(old_accum, new_tweet)
//   3. Propagates the new count downstream
// Cost: O(1) constant time, independent of database size
```

### Why This Matters for Convex Integration

If Skip is integrated into convex-backend, it could enable:
- **Real-time reactive views**: a dashboard that updates instantly as data changes, with minimal server-side recomputation
- **Subscription-based APIs**: clients subscribe to computed results and receive deltas, not polling
- **Aggregate efficiency**: computations like "users with unread messages" could be maintained in real-time at O(1) cost per message, not O(n) where n = user count
- **Constraint enforcement**: reactive views that validate invariants (as shown in RFC 006) at the cost of incremental computation, not full re-evaluation

---

## Bibliography & Key Files

### Core Runtime API
- `/Users/bill/src/skip/skipruntime-ts/core/src/api.ts` — Public types: `EagerCollection`, `LazyCollection`, `Mapper`, `Reducer`, `SkipService`, `Resource`
- `/Users/bill/src/skip/skipruntime-ts/core/src/internal.ts` — Internal type-erased definitions

### Examples
- `/Users/bill/src/skip/skipruntime-ts/examples/sum.ts` — Simple sum/subtraction example with mappers
- `/Users/bill/src/skip/skipruntime-ts/examples/departures.ts` — External service polling example
- `/Users/bill/src/skip/skipruntime-ts/examples/groups.ts` — More complex reactive resource example

### Server & HTTP Layer
- `/Users/bill/src/skip/skipruntime-ts/server/src/server.ts` — `runService()` implementation; HTTP API definition (POST /v1/snapshot/:resource, PATCH /v1/inputs/:collection, POST /v1/streams/:resource to create + GET /v1/streams/:uuid to read)

### Design & Architecture
- `/Users/bill/src/skip/rfc/008-reactive-services.org` — Full reactive services architecture RFC
- `/Users/bill/src/skip/rfc/006-incremental-constraints.org` — Incremental constraint checking in reactive views

### Language
- `/Users/bill/src/skip/skiplang/compiler/src/compile.sk` — Compiler entry point
- `/Users/bill/src/skip/skiplang/compiler/src/IR.sk` — Intermediate representation

### External Services Integration
- `/Users/bill/src/skip/skipruntime-ts/helpers/src/external.ts` — `PolledExternalService` for time-based polling
- `/Users/bill/src/skip/skipruntime-ts/adapters/` — Integrations with Convex, PostgreSQL, Kafka

### Official Documentation
- https://skiplabs.io/docs — Main documentation site
- https://skiplabs.io/docs/introduction — Introduction
- https://skiplabs.io/docs/api/core — Core API docs
