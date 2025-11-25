---
description: List outstanding issues and select one to work on
allowed-tools:
  - Read
  - Bash
  - Glob
---

# Check Issues

## Instructions

1. Run `bd ready` to list issues ready to work on (no blockers):
   - If no issues returned, run `bd list --status=open` to show all open issues
   - If still no issues, say "No outstanding issues" and exit

2. Display issues in compact format:
   - Show issue ID, title, type, and priority
   - Prompt: "Reply with the issue ID you'd like to work on (e.g., beads-001)."
   - Wait for user to reply with an ID

3. Load full context for selected issue:
   - Run `bd show <id>` to display full issue details
   - Note any dependencies or blockers
   - Read and briefly summarize relevant files mentioned in the issue

4. Check for established workflows:
   - Read CLAUDE.md (if exists) to understand project-specific workflows and rules
   - Look for `.claude/skills/` directory
   - Match file paths in issue to domain patterns (`plugins/` → plugin workflow, `mcp-servers/` → MCP workflow)
   - Check CLAUDE.md for explicit workflow requirements for this type of work

5. Present action options to user:
   - **If matching skill/workflow found**: "This looks like [domain] work. Would you like to:\n\n1. Invoke [skill-name] skill and start\n2. Work on it directly\n3. Brainstorm approach first\n4. Put it back and browse other issues\n\nReply with the number of your choice."
   - **If no workflow match**: "Would you like to:\n\n1. Start working on it\n2. Brainstorm approach first\n3. Put it back and browse other issues\n\nReply with the number of your choice."
   - Wait for user response

6. Handle user choice:
   - **Option "Invoke skill" or "Start working"**: Run `bd update <id> --status=in_progress` to claim the issue, then begin work (invoke skill if applicable, or proceed directly)
   - **Option "Brainstorm approach"**: Keep issue status unchanged, invoke `/brainstorm` with the issue description as argument
   - **Option "Put it back"**: Keep issue status unchanged, return to step 2 to display the full list again

## Display Format

```
Ready Issues:

beads-001: Add structured format to add-to-todos (task, P2)
beads-002: Create check-todos command (task, P2)
beads-003: Fix cookie-extractor MCP workflow (bug, P1)

Reply with the issue ID you'd like to work on (e.g., beads-001).
```
