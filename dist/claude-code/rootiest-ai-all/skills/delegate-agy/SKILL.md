---
name: delegate-agy
description: Delegates a subtask to the Antigravity CLI (agy) when the user wants a second opinion, external grounded research, or needs a large multi-file audit (>500 lines) processed without bloating the current context.
version: 1.0.0
user-invocable: true
author: Rootiest
---

# Antigravity Subagent Delegation (`delegate-agy`)

When the user asks for a second opinion, external grounded research, or when a task requires processing large multi-file audits (>500 lines) that would bloat context, delegate the subtask to `agy`.

## Execution Syntax
Run `agy` in headless, non-interactive mode using the bash tool:

```bash
agy --dangerously-skip-permissions -p "<detailed_task_prompt>"
```
