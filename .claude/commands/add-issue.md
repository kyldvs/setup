---
description: Create a beads issue from conversation context
argument-hint: <issue-description> (optional - infers from conversation if omitted)
allowed-tools:
  - Read
  - Bash
---

# Add Issue

## Context

- Current timestamp: !`date "+%Y-%m-%d %H:%M"`

## Instructions

1. Check for duplicates:
   - Run `bd list --status=open` to see existing issues
   - Extract key concept/action from the new issue
   - Search existing issues for similar titles or overlapping scope
   - If found, ask user: "A similar issue already exists: [title] ([id]). Would you like to:\n\n1. Skip adding (keep existing)\n2. Close existing and create new\n3. Add anyway as separate item\n\nReply with the number of your choice."
   - Wait for user response before proceeding

2. Extract issue content:
   - **With $ARGUMENTS**: Use as the title for the issue
   - **Without $ARGUMENTS**: Analyze recent conversation to extract:
     - Specific problem or task discussed
     - Relevant file paths that need attention
     - Technical details (line numbers, error messages, conflicting specifications)
     - Root cause if identified

3. Determine issue type and label:
   - **Types**: `bug` (something broken), `feature` (new functionality), `task` (work item), `chore` (maintenance)
   - **Labels**: `spike` (research task), `draft` (needs more info), `refined` (ready to start)
   - Default to `task` type with `draft` label if uncertain

4. Create the issue with `bd create`:
   ```bash
   bd create --title="[Action verb] [Component]" --type=[type] --label=[label]
   ```
   - Title should be concise (3-8 words)
   - The issue body will be prompted - include:
     - **Problem**: What's wrong or why this is needed
     - **Files**: Relevant paths with line numbers (e.g., `path/to/file.ts:123-145`)
     - **Solution**: Approach hints or constraints (if applicable)

5. Confirm and offer to continue with original work:
   - Identify what the user was working on before `/add-to-todos` was called
   - Confirm the issue was created: "Created issue [id]: [title]"
   - Ask if they want to continue with the original work: "Would you like to continue with [original task]?"
   - Wait for user response

## Example

```bash
bd create --title="Add structured format to add-to-todos" --type=task --label=draft
```

Issue body:
```
Standardize todo entries with Problem/Files/Solution pattern.

**Problem:** Current todos lack consistent structure, making it hard for Claude to have enough context when revisiting tasks later.

**Files:** `commands/add-to-todos.md:22-29`

**Solution:** Use inline bold labels with required Problem and Files fields, optional Solution field.
```
