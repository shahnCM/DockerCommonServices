---
name: workstation-image
description: How the workstation container is built and what persists — edit docker_files/workstation (Dockerfile, entrypoint, mise config, bootstrap, android-sdk-setup), add PHP extensions or runtimes, rebuild and verify.
---

# The workstation image

Files: `docker_files/workstation/`
- `Dockerfile` — layers in this order: base apt → Docker CLI + Claude Code apt repos → PHP (Sury PPA, per version) → composer + `composerX.Y` shims → opcache/swoole → FrankenPHP (arch-detected) → Chromium OS libs (via Playwright's `install-deps`) → mise → R (CRAN repo) + build libs for Ruby / R packages / Flutter → `dev` user → scripts → `USER dev`. New apt packages go in the R layer, not the base one, so the PHP and Chromium layers stay cached.
- `entrypoint.sh` — runs as `dev` every start (sudo for root steps): owns bind mounts, creates the cache folders, seeds `/opt/caches/gradle/gradle.properties` (3 GB heap, 10-min daemon timeout — user-level beats project-level), maps the docker socket group, seeds `~/.bashrc`, sets the default `php`, kicks off `runtime-bootstrap` in the background once.
- `runtime-bootstrap` — `mise install` of `/etc/mise/config.toml` (node, go, java, kotlin, maven, gradle, rust, ruby, python, flutter, lazydocker) + `npx playwright install chromium` (machine-level default, run outside any project, so it is the *newest* build; a project pinning a Playwright version installs its own into the same shared cache and that install PRUNES builds its version does not reference, deleting the machine-level one — verified 2026-09-12, a project postinstall evicted chromium-1243. `chromium`/`$CHROME_BIN` then resolve to whatever build remains) + `android-sdk-setup` + `flutter precache`. Everything lands in bind mounts, so it runs once per machine, not per rebuild. Ruby compiles from source (minutes); everything else is a download.
- `android-sdk-setup` — pinned Android command-line tools (build number + sha256 at the top of the script) into `/opt/caches/android-sdk`, accepts licenses, installs `platform-tools` (adb) + one `platforms;android-NN` / `build-tools;NN` pair. Gradle/AGP downloads other SDK parts itself. Bump the pin from https://developer.android.com/studio#command-line-tools-only.
- `mise-config.toml` — the runtime list. Add tools here (`mise registry` for names).
- `profile.d-workstation.sh` / `bashrc.seed` — env for login/interactive shells. The same PATH and cache variables are also `ENV` in the Dockerfile so VS Code's extension host (a non-login process) sees them. Change one → change both.
- `chromium` — wrapper that execs the newest Chromium from `/opt/caches/ms-playwright`, prepending `--no-sandbox` (no unprivileged user namespaces here: hosts set `kernel.apparmor_restrict_unprivileged_userns=1` and the bundled `chrome_sandbox` is not setuid-root, so a sandboxed launch dumps core) and `--disable-dev-shm-usage` (`/dev/shm` is Docker's default 64 MB). `CHROMIUM_NO_DEFAULT_FLAGS=1` gives the bare binary. Anything that launches the binary by path skips all of this and must pass the flags itself — Playwright does, Puppeteer does not. `CHROME_BIN`/`CHROME_PATH`/`CHROME_EXECUTABLE` (Flutter web) point at the wrapper.
- `php-default` — switches the `php`/`composer` symlinks in `~/.local/bin` (persisted).
- `adb-emu` — attaches the `android-emulator` service: adb connect, `adb root` + `setprop metro.host workstation` (React Native on a stock emulator otherwise looks for Metro at 10.0.2.2), `adb reverse 8081`. Must be re-run after every emulator start.

What persists across `dev rebuild` (bind mounts): `/home/dev` (also `~/.cargo`, `~/.rustup`), `/opt/mise`, `/opt/caches` (composer, npm, go, m2, gradle, pub, R, android-sdk, ms-playwright), `/projects`. Anything installed ad hoc with `sudo apt` inside the container does **not** — bake it into the Dockerfile instead.

## Common edits
- **PHP extension for every version**: add `php${v}-<ext>` to the install loop. Guard optional ones with `|| echo "!! skipping"` like swoole, because the PPA does not build every extension for 7.x.
- **New runtime**: add to `mise-config.toml`, then `docker compose exec workstation runtime-bootstrap` (no rebuild needed).
- **New system package**: add to the R/build-libs `apt-get install` list (late layer, cheap rebuild); keep `--no-install-recommends`.
- **More Android SDK packages**: `android-sdk-setup "platforms;android-34"` inside, or change `BASE_PKGS` in the script.
- **Ports**: `WS_PORTS_*` in `.env` and `services/workstation.yml`; each range costs one docker-proxy per port, so keep ranges modest.

## Rebuild & verify
```bash
docker build --check docker_files/workstation            # lint, no build
bin/dev rebuild                                          # build --pull + restart
bin/dev 'whoami; php -v | head -1; frankenphp version; claude --version; docker --version'
bin/dev 'tail -5 /opt/caches/bootstrap.log; mise ls; chromium --version'
bin/dev 'kotlinc -version; cargo --version; ruby -v; python --version; R --version | head -1'
bin/dev 'flutter --version | head -1; adb --version | head -1; sdkmanager --list_installed'
```
The first start after a fresh clone runs the bootstrap; `bin/dev logs workstation` and `/opt/caches/bootstrap.log` show progress. After a rebuild the bootstrap does not re-run by itself (the `.bootstrapped` marker is in `/opt/mise`): run `bin/dev runtime-bootstrap` when `mise-config.toml` changed.
