---
name: troubleshoot-services
description: Runbook for a service or the workstation not starting, failing healthchecks, permission errors on volumes, port conflicts, or the runtime bootstrap hanging.
---

# Troubleshoot

Work top-down; stop at the first thing that explains the symptom.

1. **What is the state?**
```bash
bin/dev ps                                   # all containers, health column
docker compose logs --tail=100 <name>
docker inspect <name> --format '{{.State.Status}} {{.State.ExitCode}} OOM={{.State.OOMKilled}} {{.State.Error}}'
```

2. **Exit code / OOMKilled=true** → the `deploy.resources.limits.memory` in `services/<name>.yml` is too small. Raise it; JVM services (dynamodb, kafka, elasticsearch, cassandra) need 1G+.

3. **"permission denied" / "could not be opened" / "read-only" on a data path** → the bind folder under `volumes/` is root-owned (Docker created it before `bin/dev` could). Fix:
```bash
ls -ld volumes/vol-<name>*
sudo chown -R "$(id -u):$(id -g)" volumes/vol-<name>     # containers running as uid 1000
```
   Services that run as a *different* fixed uid carry a `user:` override so they run as the host user instead (grafana, ms-sql). pgAdmin cannot be re-mapped and uses the named volume `workstation_pgadmin-data`.

4. **"port is already allocated"** → `ss -ltnp | grep :<port>` on the host. Host ports must be outside 8000-8099 / 3000-3010 / 5173-5180 (the workstation owns those). Check duplicates across files:
```bash
docker compose --profile '*' config | grep -E '^\s+published: ' | awk '{print $2}' | tr -d '"' | sort | uniq -d
```

5. **Service is not started by `dev up`** → it is not in `COMPOSE_PROFILES` (`bin/dev list`). `dev enable <name>` or one-off `docker compose up -d <name>`.

6. **Workstation: node/go/java/kotlin/rust/ruby/python/flutter/adb/chromium missing** → the one-time bootstrap is still running or failed:
```bash
docker compose exec workstation tail -50 /opt/caches/bootstrap.log
docker compose exec workstation runtime-bootstrap         # re-run, idempotent
```
   `mise ls` shows installed runtimes; `mise reshim` if a shim is stale — also after `pip install` / `gem install` of a CLI (jupyter, rails) when a script cannot find it. `sdkmanager --list_installed` for the Android SDK; `android-sdk-setup` re-runs that part alone.

7. **VS Code attaches as root / wrong folder** → `bin/dev vscode --force`, then Developer: Reload Window. The image's default user is `dev`, so this only happens with a stale attach config.

8. **`docker` inside the workstation says permission denied** → the socket's group id changed (new host). Restart the container: `dev restart workstation` (the entrypoint re-maps the group).

9. **Config itself is broken** (`dev` prints YAML errors) → `docker compose --profile '*' config` names the file and line. Only files listed in `compose.yml` are parsed.

10. **android-emulator**
   - does not start, "error gathering device information" / `/dev/kvm` → Linux host with KVM only (off in most VMs, absent in Docker Desktop). README "Android emulator" has the host-side alternative.
   - up but no QEMU process, `adb connect` fails, supervisor shows `d_screen`/`device` FATAL → it was `docker stop`ped and `start`ed; stale lock files. `dev down android-emulator && dev up android-emulator` (never stop/start).
   - boots for minutes, "System UI isn't responding", 6 GB / 5 cores → a big screen profile is being software-rendered. Keep `ANDROID_EMULATOR_DEVICE=Nexus 5` (README has the measurements).
   - React Native red screen "Unable to load script" → run `adb-emu` inside the workstation after every emulator start (sets `metro.host=workstation`); Metro must be running (`npx react-native start`).
   - host swaps / freezes → emulator ≈ 4 GB + Gradle ≈ 3 GB; on a 12 GB host run one at a time, add swap.
