# Research: Convex-Backend Reactivity and Triggers

## Overview
This document analyzes how convex-backend implements reactive query subscriptions, triggers (in the context of index maintenance), and invalidation mechanisms. It also assesses whether the reactivity model is based on fine-grained incremental computation or coarser invalidation/re-execution.

---

## 1. What "Trigger" Means in Convex-Backend

### Current Usage
In convex-backend, **"trigger" primarily refers to index maintenance activation**, not application-level functions:

- **Index Backfill Triggers**: When a database index is created with state `Backfilling`, the `IndexWorker` detects it and triggers backfill tasks.
  - File: `crates/database/src/database_index_workers/mod.rs`
  - The `IndexWorker::run()` loop checks the `_index` system table for indexes in `DatabaseIndexState::Backfilling` state and queues them for processing.
  - Lines 188-207 show the detection and queuing logic.

- **Subscription Invalidation Triggers**: Writes to the database trigger invalidation checks through the write log.
  - File: `crates/database/src/subscription.rs`
  - When `advance_log()` is called, it iterates through all index writes in the log and identifies subscriptions whose read-sets overlap with those writes.
  - The subscription is then marked invalid and the client is notified.

- **Write Source Tracking**: The system tracks which "source" triggered a write (user UDF, system UDF, or internal system operation).
  - File: `crates/database/src/write_log.rs:206-280`
  - `WriteSource` enum distinguishes between:
    - `Udf(Arc<UdfIdentifier>)`: User-defined function mutations
    - `SystemUdf(Arc<UdfIdentifier>)`: System UDFs (e.g., `_system/` operations)
    - `System(&'static str)`: Internal operations (e.g., "system_table_cleanup")

### When They Fire
- **Index backfill triggers** fire on startup when the system detects unfinished backfills.
- **Subscription invalidation triggers** fire asynchronously via the `SubscriptionManager` worker whenever writes are committed.
- The `IndexWorker` runs continuously and checks the `_index` table on each loop iteration.

### What They're Used For
1. **Index Backfilling**: Maintaining database indexes (populating them with historical data).
2. **Search Index Maintenance**: Text and vector search indexes are maintained via `SearchIndexWorkers` (see `crates/search_index_workers/src/search_worker.rs`).
3. **Subscription Invalidation**: Notifying clients that their subscribed query results may have changed.
4. **System Table Cleanup**: Internal operations that clean up system state.

---

## 2. How Convex-Backend Implements Reactive Query Subscriptions

### Architecture Overview

The subscription system is built on three key concepts:

#### A. Read-Set Tracking (OCC Foundation)
- **File**: `crates/database/src/reads.rs`
- Every query transaction records which index keys/ranges it read via a `ReadSet` structure.
- `ReadSet` contains:
  - `indexed`: BTreeMap of `TabletIndexName` → `IndexReads` (interval sets of accessed index keys)
  - `search`: BTreeMap of `TabletIndexName` → `SearchQueryReads` (text search filters)

**Example** (lines 88-92 of reads.rs):
```rust
pub struct ReadSet {
    indexed: WithHeapSize<BTreeMap<TabletIndexName, IndexReads>>,
    search: WithHeapSize<BTreeMap<TabletIndexName, SearchQueryReads>>,
}
```

The `overlaps_document()` method (lines 140-185) checks if a document update overlaps with the recorded read-set.

#### B. Token/Timestamp Versioning
- **File**: `crates/database/src/token.rs` (module in lib.rs)
- After a transaction completes, the client receives a `Token` that encapsulates:
  - The transaction's begin timestamp
  - The transaction's read-set
  - Used for subscription creation
- **Usage**: The client passes this token to `Database::subscribe()` to establish a subscription.

#### C. Subscription Manager (Write-Triggered Invalidation Detection)
- **File**: `crates/database/src/subscription.rs`
- The `SubscriptionManager` maintains a mapping of:
  - Subscriber ID → Read-set intervals
- When the write log advances, `advance_log()` is called with the latest timestamp range.
- The manager iterates through all writes in that range and checks for overlaps with registered subscriptions.

**Key Flow** (lines 492-660 of subscription.rs):
```
1. new write committed → write_log.append(ts, index_writes)
2. SubscriptionManager::advance_log(next_ts) is invoked
3. For each index write from (from_ts, next_ts]:
   - For each subscribed range on that index:
     - Query IntervalMap to find overlapping subscribers
     - Mark those subscribers as "to_notify"
4. For each subscriber to notify:
   - Mark subscription as invalid
   - Send invalidation signal to client
5. Update processed_ts to next_ts (allows query client to re-execute)
```

#### D. Write Log Integration
- **File**: `crates/database/src/write_log.rs`
- The write log stores all writes in index-key form (not full documents).
- Maintains two maps:
  - `by_database_index`: Indexed writes keyed by database index name
  - `by_text_index`: Text search writes keyed by search index name
- The log uses an `IntervalMap` for efficient range overlap queries (see `crates/interval_map/`).

**Critical Structure** (write_log.rs lines 125-128):
```rust
pub struct IndexKeyWrites {
    pub database: Vec<(TabletIndexName, Arc<WriteInIndex<DatabaseIndexWrite>>)>,
    pub text: Vec<(TabletIndexName, Arc<WriteInIndex<TextIndexWrite>>)>,
}
```

#### E. Subscription Lifecycle
1. **Creation**: Client calls `Database::subscribe(token)` after transaction completes.
   - `SubscriptionsClient::subscribe()` (subscription.rs:144-168)
   - Message is routed to a `SubscriptionManager` (round-robin across multiple managers)
2. **Active Monitoring**: Manager tracks the subscription's read-set in an `IntervalMap` per index.
3. **Invalidation**: When write log advances and overlapping writes are detected, subscription is invalidated.
4. **Cleanup**: When client connection closes or subscription is explicitly closed, it's removed from the manager's tracking.

---

## 3. Critical Comparison: Coarse Invalidation vs. Fine-Grained Incremental Computation

### Current Model: Coarse Re-Execution with OCC-Based Detection

**Verdict**: Convex-backend does **NOT** implement general incremental computation. Instead, it uses:

1. **Optimistic Concurrency Control (OCC)** for conflict detection
2. **Subscription invalidation** based on read-set overlap
3. **Full query re-execution** when invalidated

### Evidence

#### What Convex-Backend DOES Have:
- **Read-set tracking** (per-transaction, per-query): Captures which index ranges/keys were accessed
- **Write-set tracking** (per-commit): Captures which index keys were written
- **Overlap detection**: Boolean check: "Did a write overlap with a read?" (yes/no)
- **Coarse triggering**: "Query result may have changed, re-run it"

**Evidence File**: `crates/database/src/reads.rs:233-239`
```rust
/// writes_overlap_by_index is the core logic for
/// detecting whether a transaction or subscription intersects a commit.
/// If a write transaction intersects, it will be retried to maintain
/// serializability. If a subscription intersects, it will be rerun and the
/// result sent to all clients.
```

#### What Convex-Backend DOES NOT Have:
- **No fine-grained delta propagation**: Writes are not decomposed into deltas that flow through query pipeline stages.
- **No operator-level incrementality**: Each query stage (filter, map, sort) does not receive deltas; the entire query re-executes.
- **No dataflow graph**: No dependency graph of query operations with incremental update rules.
- **No partial recomputation**: When invalidated, the query function runs from start to finish again, reading from the database fresh.

**Evidence**: 
- `crates/database/src/database.rs:2084-2097`: `subscribe_and_wait_for_subscription_invalidation()` waits for the subscription to become invalid, then control returns to the caller (the application), implying the application must re-execute the query.
- `crates/database/src/query/mod.rs:139-200`: Query execution is a fresh traversal of indexes; there is no incremental computation logic.

#### The Subscription Mechanism is Not Incremental Computation
The subscription system is really:
1. **Staleness Detection**: "Does this query result need re-validation?"
2. **Invalidation Notification**: "Tell the client the result is stale."
3. **Client Re-Execution**: "Client re-runs the query to get fresh results."

**Not**:
- Incremental recomputation of intermediate results
- Fine-grained delta propagation
- Operator-level partial updates

---

## 4. Plug-In Points for an External Incremental Engine (Skip)

### Natural Abstraction Boundaries

#### A. Index Maintenance / Index Backfill Level
**Location**: `crates/database/src/database_index_workers/mod.rs`

- **Current**: Calls `IndexWriter::backfill_index()` to populate index entries by scanning the table and extracting index keys.
- **Plug-in Opportunity**: Insert an incremental index maintenance engine that:
  - Maintains a differential dataflow graph for index definitions
  - On new writes, computes only the delta of index entries
  - Updates indexes incrementally instead of full backfill

**Key interface** (database_index_workers/mod.rs):
```rust
pub struct IndexWorker<RT: Runtime> {
    database: Database<RT>,
    index_writer: IndexWriter<RT>,  // ← Could be abstracted to a trait
    // ...
}
```

#### B. Search Index Maintenance Level
**Location**: `crates/search_index_workers/src/search_worker.rs`

- **Current**: `TextIndexFlusher` and `VectorIndexFlusher` process batches of writes and update search indexes.
- **Plug-in Opportunity**: Replace flusher logic with an incremental search index engine that:
  - Incrementally builds search index segments
  - Reuses previous computations when documents are re-indexed
  - Computes deltas in tokenization and scoring

#### C. Query Execution / Result Invalidation Level
**Location**: `crates/database/src/subscription.rs` and `crates/database/src/database.rs`

- **Current**: `advance_log()` detects overlaps and marks subscriptions invalid. Client re-runs query from scratch.
- **Plug-in Opportunity**: Introduce an incremental query engine that:
  - Maintains a cache of query results with their read-sets
  - On invalidation, applies incremental updates to results instead of full re-execution
  - Leverages Skip or similar to track data dependencies within the query

**Key interface** (database.rs:2084-2097):
```rust
pub async fn subscribe(&self, token: Token) -> anyhow::Result<Subscription> {
    self.subscriptions.subscribe(token, false)
}

pub async fn subscribe_and_wait_for_invalidation(
    &self,
    current_ts: Token,
) -> Timestamp {
    let subscription = self.subscriptions.subscribe(token, true)?;
    let invalid_ts = subscription.wait_for_invalidation().await;
    // ← Here is where an incremental engine could update results
    // ...
}
```

#### D. Transaction Validation / OCC Loop Level
**Location**: `crates/database/src/committer.rs`

- **Current**: `pre_validate_batch()` checks read-set overlaps against the write log snapshot.
- **Plug-in Opportunity**: Replace simple overlap detection with:
  - Incremental validity checking (only re-validate affected reads)
  - Maintain a dependency graph of OCC conflicts
  - Predict which transactions will conflict and prioritize them

**Key function** (committer.rs:228-263):
```rust
fn pre_validate_batch(
    snapshot: &WriteLogSnapshot,
    batch: Vec<CommitRequest>,
) -> Vec<PreValidation> {
    // ← Conflict checking happens here
    // Could delegate to incremental validity engine
}
```

---

## 5. Summary of Key Files and Their Roles

| File | Role | Relevance to Reactivity |
|------|------|--------------------------|
| `crates/database/src/subscription.rs` | Subscription lifecycle, invalidation detection | Core; manages subscription state and read-set overlap queries |
| `crates/database/src/reads.rs` | Read-set tracking, overlap detection | Core; defines `ReadSet` and overlap logic for OCC + subscriptions |
| `crates/database/src/write_log.rs` | Write log storage, index key extraction | Core; stores writes and provides iteration for invalidation checks |
| `crates/database/src/committer.rs` | Commit coordination, OCC validation | Core; conflict detection loop |
| `crates/database/src/database.rs` | High-level API, subscription creation | Core; entry point for `subscribe()` and `subscribe_and_wait_for_invalidation()` |
| `crates/database/src/query/mod.rs` | Query execution | Peripheral; query pipeline has no incremental logic |
| `crates/database/src/database_index_workers/mod.rs` | Index backfill orchestration | Plug-in candidate; index maintenance worker |
| `crates/search_index_workers/src/search_worker.rs` | Search index maintenance | Plug-in candidate; text/vector index maintenance |
| `crates/async_lru/src/async_lru.rs` | General-purpose async cache | Utility; used for snapshot caching, not query result caching |
| `crates/interval_map/` | Efficient range overlap queries | Utility; used by subscriptions to find overlapping subscribers |

---

## 6. Architectural Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Client                                  │
│  (e.g., Convex-hosted frontend subscription listener)      │
└────────────────────────┬────────────────────────────────────┘
                         │ subscribe(token)
                         ▼
           ┌─────────────────────────────┐
           │   Database::subscribe()    │
           │  (database.rs:2084-2087)   │
           └──────────────┬──────────────┘
                          │ create subscription
                          ▼
        ┌──────────────────────────────────────┐
        │   SubscriptionsClient                │
        │   (subscription.rs:136-175)          │
        │   - Routes to SubscriptionManager    │
        │   - Round-robin load balancing       │
        └──────────────────────────────────────┘
                          │
                 ┌────────┴────────┐
                 ▼                 ▼
        ┌──────────────────┐  ┌──────────────────┐
        │ SubscriptionMgr0 │  │ SubscriptionMgr1 │
        │ (running async)  │  │ (running async)  │
        └──────────────────┘  └──────────────────┘
                 │                   │
        ┌────────┴────────────────────┴──────────┐
        │ Subscription Map (per manager)         │
        │ - by index: IntervalMap of subscribers │
        │ - by search: TextSearchSubscriptions   │
        └────────────────────┬───────────────────┘
                             │
                    (watches write log)
                             │
                             ▼
        ┌──────────────────────────────────────┐
        │      WriteLog (shared)                │
        │   (write_log.rs)                      │
        │   - by_database_index                 │
        │   - by_text_index                     │
        │   - max_ts, purged_ts                 │
        └──────────────────┬───────────────────┘
                           │
                  (written by Committer)
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │    Committer                         │
        │   (committer.rs)                     │
        │   - OCC conflict checking            │
        │   - Assigns timestamps               │
        │   - Writes to log & persistence      │
        └──────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │    Persistence (LSM/RocksDB)         │
        │   - Document store                   │
        │   - Index structures                 │
        └──────────────────────────────────────┘
```

**Invalidation Flow**:
```
1. Transaction T commits
2. Committer writes to WriteLog (index keys only)
3. SubscriptionManager::advance_log() is triggered
4. Manager iterates writes, queries IntervalMap for overlaps
5. Overlapping subscribers marked invalid
6. Subscription::wait_for_invalidation() resolves
7. Client re-executes query (fresh read from DB)
```

---

## 7. What Skip Integration Would Look Like

An incremental computation engine like Skip could be integrated at multiple layers:

### Layer 1: Index Maintenance (Highest Impact)
- **Maintain a dataflow graph** of index definitions
- On write: compute deltas in index keys, update index incrementally
- Skip tracks dependencies between document fields → index keys

### Layer 2: Query Result Caching
- **Cache query results** as a dataflow node
- On invalidation: update cached results by applying deltas from new writes
- Skip tracks which documents each query result depends on

### Layer 3: Subscription Invalidation Detection
- **Use Skip's dependency graph** to predict which subscriptions need re-validation
- Instead of checking all subscriptions, check only affected ones based on data lineage

### Non-Integration Points
- **Query parsing and compilation**: Skip is orthogonal to how Convex parses and compiles UDF queries.
- **Write validation (OCC)**: Skip could enhance it but isn't needed for basic correctness.
- **Persistence layer**: Skip operates at the logical level; persistence is orthogonal.

---

## Conclusion

**Current State**:
- Convex-backend uses **read-set-based subscription invalidation** with **OCC-based conflict detection**.
- When a subscription is invalidated, the **entire query is re-executed from scratch**.
- No fine-grained incremental computation engine exists.

**Opportunity for Skip**:
1. **Index maintenance**: Incremental index key extraction and maintenance
2. **Query result caching**: Incremental updates to cached results on invalidation
3. **Dependency tracking**: Skip's lineage tracking would replace/enhance Convex's simple overlap detection

**Natural Plug-In Points**:
- `IndexWorker` (index backfill)
- `SearchIndexWorkers` (search index maintenance)
- `SubscriptionManager::advance_log()` (result invalidation)
- `Committer::pre_validate_batch()` (OCC validation)
