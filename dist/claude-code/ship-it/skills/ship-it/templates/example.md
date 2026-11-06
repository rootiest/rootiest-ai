# Shipping this project

<!--
An example: the instructions a small web app might keep in `docs/ship-it.md`. The app is a Go
service with a Postgres database, tested on GitHub Actions and deployed with Docker Compose to a
staging host and a production host over SSH. Copy the parts that fit your project; `ship-it.md`
beside this file lists every section with no project in mind.
-->

Instructions for `/ship-it` and its steps. Each `##` section is read by the step of the same
name; anything left out uses that step's defaults.

## ship-it
- Add one `type:*` label (`type:feature`, `type:fix`, `type:docs`, `type:chore`) as soon as
  `push-it` opens the PR.
- A change under `migrations/` ships alone: never in the same PR as other work.

## doc-it
- `docs/` is the documentation root; `README.md` is the landing page and links into it.
- `docs/api.md` documents every HTTP endpoint in `internal/http/`. Keep the two in step.
- Never edit `docs/openapi.json` by hand: `make openapi` writes it.
- Breaking, beyond failing tests: a migration that drops or renames a column the running
  release still reads. Migrations must work with both the old and the new release.

## push-it
- Branch `<type>/<topic>`: `feat/`, `fix/`, `docs/`, `chore/`.
- Commit scopes in use: `api`, `web`, `db`, `deploy`.
- Before pushing, run `make lint test`. When the change touches `migrations/`, also run
  `make migrate-check` (applies every migration to an empty database and rolls it back).
- PR body: `## Summary` (ending with `Closes #N` when it resolves an issue) and `## Testing`,
  listing what was run.

## verify-it
- Two workflows on PRs: `test` (about 4 minutes) and `lint` (under a minute). Both must pass.
- `test / integration` is known to be flaky: re-run it once before reporting a failure.

## merge-it
- Merge method: squash.
- Merge without approval when the PR only changes `docs/` or Markdown files and CI passed.
  Everything else asks first.
- After a squash merge, stacked branches may be rebased and force-pushed without asking.

## sync-it
- After a merge that touches `web/`, CI pushes a `chore: rebuild web assets` commit to `main`.
  Wait for it before pulling.

## prune-it
- Keep `demo` (`--keep demo`): it backs the public demo site.

## deploy-it
Two environments: **staging** (the default) and **production**. Both run
`docker compose` in `/srv/app` on their host and pull the image CI builds on every push to
`main` (`ghcr.io/example/app:<short sha>`).

**Nothing to deploy** when the merge changed only `docs/`, `.github/` or Markdown files.

1. Wait for the `image` workflow on the merge commit, which publishes the image.
2. Deploy: `ssh staging.example.com 'cd /srv/app && APP_TAG=<short sha> docker compose up -d'`
   (production: `prod.example.com`). Compose runs the migrations before the new app starts.
3. Verify: `https://staging.example.com/healthz` (production: `https://example.com/healthz`)
   answers 200 with `"version": "<short sha>"` within two minutes, and
   `docker compose ps` shows every service healthy.

- Deploy to staging without approval. Production needs approval, and only after staging is
  verified with the same commit.
- **Rollback:** run step 2 again with the previous tag. On staging, roll back without asking
  when step 3 fails; on production, ask first. Never roll back past a migration: report it
  instead.
