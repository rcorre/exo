---
name: commit
description: Create a git commit for currently staged changes with a single-line imperative summary. Use when asked to commit changes in this repo.
---

Create a git commit for the currently staged changes.

## Workflow

1. Run `git diff --cached` to see what's staged. If nothing is staged, tell the user and stop.
2. Run `git log --oneline -10` for recent style context.
3. Write a single-line imperative summary of the change — nothing else, no body.
4. Commit:

```
git commit -m "<summary>"
```

## Subject line rules

- Imperative mood: "Add", "Fix", "Remove", "Update", "Rename" (not past tense, not "-ing")
- One line only — no body, no bullet points, no explanation
- Keep under ~60 characters
- No period at the end
- No conventional-commit prefixes (`fix:`, `feat:`, `chore:`)
