---
name: deploy-it
description: Deploys what is on the default branch using the project's own deploy steps, with user approval unless the project's rules allow deploying without it, then verifies the deploy. Reports cleanly when there is nothing to deploy.
version: 2.4.0
user-invocable: true
author: Rootiest
---

# /ship-it:deploy-it

Phase 6 of `/ship-it`. Also runs on its own.

## Project instructions
Projects can spell out how this step runs for them. Unless `/ship-it` already handed you this
step's section, look for the project's ship-it instructions and use the first file that exists:

1. `AGENTS_ship-it.md` in the repo root
2. `AGENTS/AGENTS_ship-it.md`
3. `docs/ship-it.md`

Read only the `## deploy-it` section. Where it conflicts with the defaults in this skill, the
section wins; anything it leaves out falls back to the defaults. No file, or no `## deploy-it`
section, means use the defaults. Say in your report which file and section you used, or that
there were none.

The section is the source of truth for how this project deploys: commands, order, environments,
how to verify, how to roll back, and when deploying needs no approval. Follow it exactly. If it
says there is nothing to deploy, report that and stop.

## Trigger Conditions
1. The user types `/ship-it:deploy-it`, or asks to deploy, release, or roll out the project.
2. `/ship-it` reaches Phase 6.

## Inputs
- **Environment**: the one the user or caller named. Otherwise the section's default. If the
  project has several and no default, ask.
- `<owner>/<repo>` and the platform come from `git remote get-url origin`.

## Step 1: Check what would be deployed
Deploy the default branch as it is on the remote, unless the section says otherwise.
- `git fetch origin`, then check that you are on the default branch, it matches
  `origin/<default>`, and tracked files have no uncommitted changes.
- If not, stop and report what differs. Under `/ship-it`, Phases 4b and 5 have already left
  `main` in sync, so this passes.

## Step 2: Work out the plan
**With a `## deploy-it` section:** the plan is what it says.

**Without one,** look for how the project deploys, cheapest first:
1. A CI workflow that deploys on push to the default branch (`.gitea/workflows/`,
   `.github/workflows/`: a deploy job, `environment:`, or steps that publish, upload, or ssh).
2. A deploy entry point: `just deploy`, `make deploy`, a `deploy` script in `package.json`, or
   `scripts/deploy*`.
3. Container and hosting config: `docker-compose*.yml`, `Dockerfile`, `fly.toml`,
   `netlify.toml`, `vercel.json`, `wrangler.toml`, and similar. If a skill for the user's own
   hosting or infrastructure is installed, use it to find where and how this project runs.
4. The README or `docs/` describing a deploy.

If none of these turn anything up, the project has nothing to deploy. Report "no deploy
configured" and stop. This is not a failure, and `/ship-it` still finishes successfully.

## Step 3: Approval
**CI deploys on merge:** nothing is run by you, so no approval is needed. Go to Step 4 and watch
that run.

**A plan you worked out** (no section): always show it and ask before running anything, even if
the user asked you to deploy, since they haven't seen what will run.

**A documented plan:** ask by default. Show the environment, the commands, and the commit being
deployed, and wait for the answer. Don't ask when either is true:
- The user already asked to deploy this, to this environment, in this conversation.
- The section says deploying needs no approval in this case (e.g. "deploy to staging without
  asking; production needs approval"), and the case matches. Say which rule matched. If it is
  unclear whether it applies, ask.

If the user declines, report that nothing was deployed and stop.

## Step 4: Deploy
- **Commands:** run them in order, from the repo root unless the plan says otherwise. Stop at the
  first failure.
- **CI deploy:** find the deploy run for the default branch's head commit and watch it with
  `/ship-it:verify-it`. If no deploy run started, report that rather than deploying by hand.
- Never print secrets or tokens, and don't copy them into commands from files; let the deploy
  tooling read them as it normally does.

## Step 5: Verify
Use the section's verification steps. Without any, check what the plan points to: the service's
URL answers successfully, the container or service is running and healthy, or the CI deploy job
passed. Say which checks you ran.

## On failure
Stop and report the failing command or job and its error. Roll back only if the section defines
how, and ask before doing it unless the section says to roll back automatically.

## Report
Environment, commit deployed, what ran, the verification result, and the URL when there is one.
If you had to work out the plan, offer to save it as a `## deploy-it` section in the project's
`docs/ship-it.md` so the next deploy uses it directly. Only offer; don't write it unasked.
