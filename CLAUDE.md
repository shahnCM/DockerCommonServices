# CLAUDE.md — portable-workstation

A Docker Compose repo: one long-running "workstation" container (PHP 7.2–8.4, Node/Go/Java via mise,
headless Chromium, Docker CLI, Claude Code) plus ~35 optional services, one file each.
The README is the user manual; this file is the maintainer's contract.

## Layout
- `compose.yml` — the only root file. `include`s every `services/*.yml` (long syntax, `project_directory: .`) and names the default network `common`. No generator, no globbing: a service exists when its file is listed here.
- `services/<name>.yml` — standalone Compose file. Service name = `container_name` = profile name = filename. Optional extras carry `profiles: [<name>]` so they are inert unless enabled (`COMPOSE_PROFILES` in `.env`, or named explicitly on the command line).
- `docker_files/workstation/` — the workstation image (see `.claude/skills/workstation-image`).
- `bin/dev` — the user-facing CLI. It is the only place that knows about `.env` editing, folder pre-creation, VS Code attach, and cwd→`/projects` mapping. Keep it POSIX-bash, macOS-compatible (`sed -i.bak`, `od`), no jq/python.
- `vscode/attached-container.json` — copied to VS Code's `nameConfigs/workstation.json` by `dev setup`.
- `volumes/`, `projects/` — data and code; git-ignored; every bind mount lives here.

## Rules (why the repo stays simple)
1. Paths in service files are relative to the repo root (`./volumes/...`, `./docker_files/...`). No `${VOL_BASE}`-style indirection.
2. Ports: `"${BIND_IP:-127.0.0.1}:HOST:CONTAINER"`. Host ports never inside 8000-8099 / 3000-3010 / 5173-5180 (workstation ranges). Check duplicates with the command in `.claude/skills/add-service`.
3. Variables: `${VAR:-default}` only. Never `${VAR:?}` (interpolation runs for disabled profiles too and would break every command).
4. No `networks:` blocks in service files; the root default network is `common`.
5. Containers that run as a fixed non-root uid and write a bind mount either support `user: "${USER_UID:-1000}:${USER_GID:-1000}"` (grafana, ms-sql) or say in their header comment that the folder must be writable by that uid. `bin/dev` pre-creates all bind folders as the host user before any `up`. pgAdmin is the one exception: its image only runs as uid 5050, so it uses a Docker-managed named volume.
6. `depends_on` only where the service is meaningless alone (kibana, mongo-express, scylla-manager). Admin UIs never depend on databases.
7. Pin tags for anything with a data directory. Verify with `docker manifest inspect` before committing.
8. The workstation image's default user is `dev`; the entrypoint runs as `dev` and uses sudo for root-only steps. Do not add `USER root` back or `-u dev` flags.
9. Keep the README table, `.env.example`, and `compose.yml` in sync when adding or renaming a service.

## Verify before committing
```bash
docker compose --profile '*' config --quiet                     # model parses with no .env
bash -n bin/dev docker_files/workstation/*.sh docker_files/workstation/runtime-bootstrap
docker build --check docker_files/workstation                   # Dockerfile lint
docker compose up -d <changed-service> && docker compose ps     # and read its logs
docker compose --profile '*' down <changed-service>
```
A workstation image change needs a real `dev rebuild` and the smoke checks in `.claude/skills/workstation-image`.

## Skills in `.claude/skills/`
`add-service`, `troubleshoot-services`, `bump-images`, `workstation-image`. Use them; they encode the traps already hit.
