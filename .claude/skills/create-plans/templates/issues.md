# Deferred Enhancements with Beads

When Rule 5 (Log non-critical enhancements) is triggered during execution, use beads to track the enhancement.

## Creating Deferred Enhancement Issues

```bash
bd create --title="[Brief description]" --type=task --label=draft
```

When prompted for the issue body, include:
- **Discovered:** Phase [X] Plan [Y] Task [Z] (YYYY-MM-DD)
- **Type:** [Performance / Refactoring / UX / Testing / Documentation / Accessibility]
- **Description:** [What could be improved and why it would help]
- **Impact:** Low (works correctly, this would enhance)
- **Effort:** [Quick (<1hr) / Medium (1-4hr) / Substantial (>4hr)]
- **Suggested phase:** [Phase number where this makes sense, or "Future"]

## Example

```bash
bd create --title="Add connection pooling for Redis" --type=task --label=draft
```

Issue body:
```
**Discovered:** Phase 2 Plan 3 Task 6 (2025-11-23)
**Type:** Performance
**Description:** Redis client creates new connection per request. Connection pooling would reduce latency and handle connection failures better. Currently works but suboptimal under load.
**Impact:** Low (works correctly, ~20ms overhead per request)
**Effort:** Medium (2-3 hours - need to configure ioredis pool, test connection reuse)
**Suggested phase:** Phase 5 (Performance optimization)
```

## Finding Deferred Issues

```bash
# List all draft issues (deferred enhancements)
bd list --label=draft

# List all open tasks
bd list --type=task --status=open
```

## Closing Resolved Issues

When an enhancement is addressed in a later phase:

```bash
bd close <id> --reason="Resolved in Phase [X] Plan [Y]: [What was done]"
```

## Integration with Roadmap

When planning new phases, check for deferred enhancements:

```bash
bd list --label=draft --status=open
```

Can create phases specifically for addressing accumulated issues:
- Example: "Phase 8: Code Health - Address ISS-003, ISS-007, ISS-012"

## Prioritization

Use beads priority field:
- `0` Critical - Quick wins with visible benefit → Earlier phases
- `1` High - Substantial refactors with organizational benefit → Dedicated "code health" phases
- `2` Medium (default) - Nice-to-haves
- `3` Low - Low impact, high effort → "Future" or never
- `4` Backlog - Address as time permits

```bash
bd update <id> --priority=1
```

This creates traceability: enhancement discovered → beads issue created → planned → addressed → closed.
