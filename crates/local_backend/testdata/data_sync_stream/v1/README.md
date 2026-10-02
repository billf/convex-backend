# Data Sync stream wire fixtures, version 1

This is the canonical fixture corpus for the experimental `POST /api/data_sync_stream` route. The contract is KTD6 in `docs/plans/2026-09-10-1854-feat-skip-data-sync-push-source-spike-plan.md`.

The corpus was **written by hand from that contract** before the route existed, so nothing here was captured from a running backend. The Skip adapter vendors a byte-identical copy at `skipruntime-ts/adapters/convex/testdata/data_sync_stream/v1/`. `manifest.json` lists every file with its SHA-256 and byte count, and drift between the two copies is a test failure.

## Request

`{"version": 1, "selection": <selection.json>, "cursor": <string|null>}`. Scenario files write the selection as `"$selection"`, a placeholder for the contents of `selection.json`.

## Rendering

Each event renders as an SSE frame:

- `event: <type>\n`
- `data: <compact JSON, keys in source order>\n`
- `\n`

There is no `id:` field, and the cursor travels inside the `page` payload. A heartbeat is the comment frame `:\n\n`. All line endings are LF. `golden_render.sse` pins the exact bytes for scenario 01's single connection.

## Events

- **`page`**: `{version, status, truncates, values, syncId, pagination, diagnostics}`.
  - The key order follows `DataSyncResponse`, with `version` first and `diagnostics` last.
  - `status` is one of:
    - `{"type":"snapshotting"}`
    - `{"type":"stale","snapshotTs":"<decimal>"}`
    - `{"type":"upToDate","snapshotTs":"<decimal>"}`
  - Each `values` entry is `{component, table, ts, deleted, value}`. `value` holds the ConvexExportJSON document with sorted keys; a tombstone's `value` is exactly `{"_id": ...}`.
  - Every `ts` and `snapshotTs` is a canonical decimal string. This is the stream's lossless encoding; the existing `/api/v1/data/sync` JSON keeps numbers.
  - `truncates` are `{component, table}` sorted by (component, table). They apply before `values` on the same page. A table truncates on the page where it first enters the sync: its first cold page, when it is newly selected, or when it is replaced by an import.
  - `pagination` is `{"hasMore": true, "nextCursor": ...}`.
  - The first page of every response is always emitted, even when it is an empty established `upToDate` page.
- **`error`**: `{version, code, retryable, message}`, after which the stream closes.
- **`reconnect`**: `{version, reason: "connectionAge"}`, after which the stream closes without changing the client's applied cursor.

## Error codes

| Code | Where | Retryable |
|---|---|---|
| `DataSyncCursorExpired` | HTTP 400 before headers, or a terminal `error` event | no; restart without a cursor |
| `InvalidDataSyncCursor` | HTTP 400 before headers | no; restart without a cursor |
| `InvalidDataSyncSelection` | HTTP 400 before headers | no (fatal) |
| `DataSyncStreamUnsupportedVersion` | HTTP 400 before headers | no (fatal) |
| `DataSyncStreamSaturated` | HTTP 429 before headers | yes |
| `DataSyncStreamUnavailable` | terminal `error` event after headers | yes |

A disabled route returns a bare HTTP 404 (`http/404_disabled.json`). Malformed UTF-8 and malformed JSON are generated synthetically in the adapter's tests and are not stored here.

## Diagnostics

Every page carries `diagnostics`. They are optional on the wire, so an older producer still parses, but they are required output from the route:

- `scanDimension`: `"byId"` for snapshot traversal, `"ts"` for document-log CDC
- `rowsExamined`
- `candidateEntries`
- `selectedEntries`
- `emittedBytes`
- `timestampGroups`
- `truncations`
- `limitCause`: `"none"`, `"entryLimit"`, `"byteLimit"`, or `"rowLimit"`
- `stageDurationsMicros`: `{page, convert, encode, queue}`

Counts in corpus revision 1 are **authored, not measured**. Durations are placeholder zeros. A consumer must keep unknown extra diagnostic fields rather than reject them.

## Cursors

Cursors are placeholders of the form `fixture-cursor-<scenario>-<page>`. Real cursors are AES-GCM-SIV with a random nonce, so they are never deterministic. Scenarios marked `"after": "01_cold_multipage_uptodate"` start from 01's final checkpoint, `fixture-cursor-01-03`.

## Scenario files

```text
{contractVersion, id, description, after, connections: [
  {request, response: {httpStatus, events: [{event, data} | {comment}], end}}
]}
```

`end` is one of:

- `"close"`: clean end of stream
- `"eof"`: transport loss after the last event
- `{"eofMidEvent": "<partial frame>"}`: the connection drops mid-frame

## How U3 is checked against this corpus

The route cannot reproduce hand-written values byte for byte, so its output is compared structurally:

1. `pagination.nextCursor` becomes the fixture placeholder, in emission order.
2. `syncId`, every document `_id` and `_creationTime`, and every `ts` and `snapshotTs` map to the fixture's values by first appearance, preserving ts rank order.
3. Diagnostic durations become the placeholder zeros.
4. Counts derivable from the page compare exactly: `selectedEntries` equals the length of `values`, `timestampGroups` equals the number of distinct `ts` values, and `truncations` equals the length of `truncates`.
5. Backend-dependent counts (`rowsExamined`, `candidateEntries`, `emittedBytes`, `limitCause`) are checked for presence, type, and `selectedEntries <= candidateEntries <= rowsExamined`.

U3's first passing run regenerates the authored counts from real output, bumps `corpusRevision`, and re-vendors the corpus into the Skip adapter.
