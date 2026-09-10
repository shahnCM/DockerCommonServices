---
name: workstation-image
description: How the workstation container is built and what persists — edit docker_files/workstation (Dockerfile, entrypoint, mise config, bootstrap), add PHP extensions or runtimes, rebuild and verify.
---

# The workstation image

Files: `docker_files/workstation/`
- `Dockerfile` — layers in this order: base apt → Docker CLI + Claude Code apt repos → PHP (Sury PPA, per version) → composer + `composerX.Y` shims → opcache/swoole → FrankenPHP (arch-detected) → Chromium OS libs (via Playwright's `install-deps`) → mise → `dev` user → scripts → `USER dev`.
- `entrypoint.sh` — runs as `dev` every start (sudo for root steps): owns bind mounts, maps the docker socket group, seeds `~/.bashrc`, sets the default `php`, kicks off `runtime-bootstrap` in the background once.
- `runtime-bootstrap` — `mise install` of `/etc/mise/config.toml` (node, go, java, maven, gradle, lazydocker) + `npx playwright install chromium`. Everything lands in bind mounts, so it runs once per machine, not per rebuild.
- `mise-config.toml` — the runtime list. Add tools here (`mise registry` for names).
- `profile.d-workstation.sh` / `bashrc.seed` — env for login/interactive shells. The same PATH and cache variables are also `ENV` in the Dockerfile so VS Code's extension host (a non-login process) sees them.
- `chromium` — wrapper that execs the newest Chromium from `/opt/caches/ms-playwright`. `CHROME_BIN`/`CHROME_PATH` point at it.
- `php-default` — switches the `php`/`composer` symlinks in `~/.local/bin` (persisted).

What persists across `dev rebuild` (bind mounts): `/home/dev`, `/opt/mise`, `/opt/caches`, `/projects`. Anything installed ad hoc with `sudo apt` inside the container does **not** — bake it into the Dockerfile instead.

## Common edits
- **PHP extension for every version**: add `php${v}-<ext>` to the install loop. Guard optional ones with `|| echo "!! skipping"` like swoole, because the PPA does not build every extension for 7.x.
- **New runtime**: add to `mise-config.toml`, then `docker compose exec workstation runtime-bootstrap` (no rebuild needed).
- **New system package**: add to the base `apt-get install` list; keep `--no-install-recommends`.
- **Ports**: `WS_PORTS_*` in `.env` and `services/workstation.yml`; each range costs one docker-proxy per port, so keep ranges modest.

## Rebuild & verify
```bash
docker build --check docker_files/workstation            # lint, no build
bin/dev rebuild                                          # build --pull + restart
bin/dev 'whoami; php -v | head -1; frankenphp version; claude --version; docker --version'
bin/dev 'tail -5 /opt/caches/bootstrap.log; mise ls; chromium --version'
```
The first start after a fresh clone runs the bootstrap; `bin/dev logs workstation` and `/opt/caches/bootstrap.log` show progress.
