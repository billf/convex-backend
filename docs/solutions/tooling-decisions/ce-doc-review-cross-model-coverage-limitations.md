---
module: compound-engineering ce-doc-review cross-model coverage
date: 2026-09-14
problem_type: tooling_limitation
component: tooling
severity: medium
applies_when:
  - "Running ce-doc-review's OpenCode cross-model judgment pass"
  - "Reporting cross-model reviewer coverage"
tags:
  - opencode
  - ce-doc-review
  - cross-model-review
  - validation
---

## Problem

The bundled `ce-doc-review` OpenCode cross-model adapter can fail before a
review is produced. In version 3.25 it constructs the command as
`opencode run --dir … --file …` and appends the review instruction as a later
positional argument. OpenCode then interprets that instruction as a filename.
The result is no schema-valid reviewer artifact, so the pass supplies no
independent coverage even if local reviewers complete.

This is distinct from a clean review with zero findings. Coverage must say
that the affected cross-model lens and whole-document sweep are unavailable.

## Evidence

The failed adapter run logged:

```
File not found: Follow the attached brief. Return only schema-shaped JSON.
```

Version 3.24 used the working argument order: the prompt immediately follows
`opencode run`, followed by `--dir`, `--format json`, and `--file=…`.
The 3.25 regression moved the prompt out of that position while attempting to
change the attachment form.

The repository's verified direct invocation is documented in
`opencode-ce-doc-review-external-provider.md`: put the prompt immediately
after `opencode run` and use `--file="$REVIEW_BRIEF"`.

## Required recovery

1. Run the documented no-document smoke test using the same route, model, and
   isolation flags.
2. If it succeeds, use the verified direct invocation shape on one reviewer at
   a time; do not treat the adapter's failure as reviewer agreement.
3. Attach one self-contained review brief. Because OpenCode uses an empty
   temporary workdir, embed the Markdown artifacts and rendered SVG content
   (or use provider-supported image attachments); filesystem paths alone are
   not reviewable context.
4. Validate the `text` event against the findings schema. Missing or invalid
   payloads mean the reviewer is unavailable.
5. Record the route, requested model, payload-validation result, and missing
   lenses in the review Coverage section.

## Follow-up

Repair the bundled adapter by restoring the working positional order:

```sh
opencode run "Follow the attached brief. Return only schema-shaped JSON." \
  --dir "$PEER_WORKDIR" --format json "--file=$PROMPT_FILE"
```

Add a regression test that asserts the prompt immediately follows
`opencode run` and precedes the attachment. Until then, the direct recovery
path is required for cross-model coverage.
