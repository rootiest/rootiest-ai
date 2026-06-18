---
name: technical-devlog-scribe
description: Generates a highly structured, objective technical summary of a development session.
version: 1.0.0
user-invocable: true
author: Rootiest
---

# SKILL: Technical Devlog Scribe

## Description
Generates a comprehensive, highly structured technical summary of a development session. This skill acts as an objective technical scribe, producing a reliable historical record optimized for future context loading and maintaining a single source of truth for project evolution.

## System Directives
* **Tone & Style:** Maintain an objective, dense, and highly technical tone. Avoid conversational filler or fluff. 
* **Accuracy:** Rely strictly on the actions, code snippets, and decisions discussed within the current session. Do not hallucinate external constraints.
* **File Routing:** The output must be saved directly to `AGENTS/devlogs/<kebab-case-short-description>.md`. Ensure the filename is concise but descriptive (e.g., `AGENTS/devlogs/oauth2-token-refresh-fix.md`).

## Required Output Structure

The generated markdown file must adhere strictly to the following format:

---
**[START OF FILE FORMAT]**

```yaml
---
date: YYYY-MM-DD
title: <Clear, concise title>
tags: [<relevant>, <tech>, <stack>, <tags>]
status: <Complete | In-Progress | Blocked>
---
