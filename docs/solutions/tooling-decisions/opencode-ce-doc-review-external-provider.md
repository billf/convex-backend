---
module: compound-engineering ce-doc-review external reviewer integration
date: 2026-09-14
problem_type: tooling_decision
component: tooling
severity: medium
applies_when:
  - "Configuring or invoking OpenCode for an external ce-doc-review judgment pass"
  - "Attaching a review brief or requirements document to opencode run"
  - "Running more than one OpenCode review in a session"
tags:
  - opencode
  - ce-doc-review
  - cross-model-review
  - external-review
---

## Context

`ce-doc-review` can use OpenCode for an external cross-model judgment pass. Its command-line interface has integration details that are easy to get wrong: a failed call can be an attachment-parsing failure, an incorrect requested model route, or contention in OpenCode's local state rather than a substantive reviewer result.

Use this route only after the user has explicitly authorized egress of the review material. The requested Muse route below was verified in the 2026-09-13 session, but the response event alone does not independently attest the model that served the request. Version 3.25 of the bundled adapter regressed this argument order by appending the prompt after the options and attachment; use the direct shape below until that adapter is repaired.

## Guidance

Run one reviewer with this command shape:

```sh
opencode run 'Return only schema-shaped JSON for the attached review brief.' \
  --dir "$EMPTY_TEMP_WORKDIR" \
  --format json \
  --file="$REVIEW_BRIEF" \
  --model opencode/muse-spark-1.3-contributor-free \
  --pure
```

- Put the message immediately after `opencode run`, before any attachment.
- Use `--file=<path>`, not a space-form attachment followed by the message. `--file` is array-valued; the wrong shape can make OpenCode treat the review prose as a filename.
- Use the fully qualified requested model ID `opencode/muse-spark-1.3-contributor-free`; in the 2026-09-13 session, unqualified `muse/spark-1.3-free` did not select the intended configured route.
- Use an empty temporary `--dir`, not the repository directory. If that workspace cannot be created, treat the review as blocked instead of falling back to the repository.
- Treat `--pure` as an isolation aid, then run a no-document smoke test against the installed CLI: it does not by itself prove that every ambient OpenCode setting is absent.
- Serialize peer calls. The 2026-09-13 session observed concurrent calls contending on OpenCode's shared SQLite database.
- Before document egress, run a harmless request with the same model and isolation flags. Confirm it produces JSON output.
- With `--format json`, validate the response carried in the JSON event whose `type` is `text` against the expected review schema. A missing or invalid payload means the reviewer is unavailable; it is not a clean review.
- Do not add `--variant` unless the installed CLI and selected route have been separately tested for it.

## Why This Matters

In the 2026-09-13 session, the earlier adapter placed the prompt after a space-form attachment, producing `File not found: Follow the attached brief. Return only schema-shaped JSON.` It also requested an unconfigured model ID and dispatched simultaneous reviewers. Those operational failures produced no usable judgment and could have been mistaken for no findings.

The verified command shape makes that boundary explicit: serial dispatch avoids intermittent database failures, and the smoke test catches local CLI or authentication failures before a plan leaves the machine. Authorization remains scoped to the particular document-review request; a working command does not authorize future egress.

## When to Apply

Use this pattern when `ce-doc-review` activates a conditional cross-model lens and OpenCode is the user-authorized external reviewer. It applies to security, adversarial, product, and broad whole-document passes.

Keep the local reviewer path as the fallback when egress is not authorized, the smoke test fails, the requested model route is unavailable, or the returned response does not validate. Record requested route, payload validation, and coverage separately; a text response does not independently prove serving-model identity.

## Examples

Smoke test before egress:

```sh
opencode run 'Reply with exactly: ready' \
  --dir "$EMPTY_TEMP_WORKDIR" \
  --format json \
  --model opencode/muse-spark-1.3-contributor-free \
  --pure
```

After explicit authorization, start one schema-directed reviewer, wait for and validate its JSON `text` response, then start the next reviewer. If the call exits without a valid response, record it as unavailable rather than treating silence as agreement.
