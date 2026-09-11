# Portable Workstation

One Docker container that behaves like your dev machine — PHP 7.2 → 8.4 side by side, Node, Go,
Java + Kotlin, Rust, Ruby, Python, R, Flutter + the Android SDK, headless Chromium (Playwright),
Docker CLI, lazydocker and Claude Code — plus every database, queue, admin UI and an Android
emulator you might need, each in its own file, started only when you want it.

Your code and all data live in plain folders inside this repo, so the whole thing moves with you:
clone it on a new machine, run one command, keep working.

```
 host                                      container "workstation"
 ─────────────────────────────              ─────────────────────────────
 projects/  ─────────────────────────────►  /projects      (your code)
 volumes/vol-workstation/home ───────────►  /home/dev      (dotfiles, ~/.claude, VS Code server)
 volumes/vol-workstation/mise ───────────►  /opt/mise      (node/go/java/rust/ruby/python/flutter …)
 volumes/vol-workstation/caches ─────────►  /opt/caches    (composer/npm/go/m2/gradle/chromium/android-sdk/pub/R)
 volumes/vol-mysql-8, vol-redis-7, … ────►  each service's data
```

## Quick start

1. Get the repo:
   ```bash
   git clone <this repo> ~/workstation && cd ~/workstation
   ```
2. Install Docker (see [prerequisites/](prerequisites/README.md) for macOS, Windows, other distros). Ubuntu/Debian:
   ```bash
   bash prerequisites/setup-host.sh              # asks: clean? install? add2path?
   ```
   It walks the three host chores one prompt at a time. Just the installer, if you prefer:
   ```bash
   sudo bash prerequisites/install-docker.sh     # engine + compose plugin, nothing else
   ```
   Either way, log out and back in once so the `docker` group applies.
3. Set up. This writes `.env` with your user id, creates the folders, installs the VS Code attach
   config, builds the workstation image and starts the enabled services (first build: 10–20 min):
   ```bash
   bin/dev setup
   echo "export PATH=\"$PWD/bin:\$PATH\"" >> ~/.bashrc && source ~/.bashrc   # `dev` from any folder
   ```
4. Your code lives in one folder, mounted as `/projects` inside. Default: `projects/` in this repo;
   setup asks, and you can change it anytime with `dev projects ~/code` (`PROJECTS_BASE` in `.env`).
   Each project is one sub-folder. Then:
   ```bash
   git clone git@github.com:you/my-app.git projects/my-app
   cd projects/my-app && dev        # a shell inside the workstation, in that folder
   dev code .                       # VS Code attached (Claude Code, PHP, Go, Python, Java/Spring, Kotlin, Rust, Ruby, R, Flutter ready)
   dev list                         # which services exist / are enabled / are running
   ```

Node, Go, Java, Kotlin, Rust, Ruby, Python, Flutter, the Android SDK and Chromium download in the
background on the very first start (10–20 min, Ruby is compiled; `dev logs workstation` or
`tail -f /opt/caches/bootstrap.log` inside). PHP works immediately.

## Daily use

| you want | you type |
|---|---|
| shell in the workstation, in the project you're standing in | `cd projects/my-app && dev` |
| run one command inside | `dev php7.4 -v` · `dev composer install` · `dev npm run dev -- --host` |
| VS Code on a project (a new window each time) | `dev code .` · `dev code my-app` |
| where my code lives (mounted as `/projects`) | `dev projects` · `dev projects ~/code` |
| start / stop what's enabled | `dev up` · `dev down` |
| start something just this once | `dev up postgres-16` |
| enable / disable permanently | `dev enable postgres-16` · `dev disable mysql-5` |
| logs, status | `dev logs mysql-8` · `dev ps` |
| every container, live, on one screen | `dev lazy` (lazydocker) |
| rebuild the workstation image | `dev rebuild` |
| all commands | `dev help` |

Serve on any port in `WS_PORTS_A/B/C` (`.env`: 8000-8099, 3000-3010, 5173-5180) bound to `0.0.0.0`
inside, and it's `localhost:<port>` on your host:
```bash
cd projects/legacy-app && dev
php7.2 artisan serve --host=0.0.0.0 --port=8072     # → http://localhost:8072
```

### One machine, many windows

`dev code <project>` opens a VS Code window attached to the workstation with that folder open. Run it
again for another project: every window shares the same container, extensions, terminals and Claude
Code login, exactly like several windows on one machine. Inside any window, *File → Open Folder* also
works — everything under `/projects` is yours.

Other Compose projects can join the workstation's network with
`networks: { default: { name: common, external: true } }` and reach `mysql-8`, `redis-7`, … by name.

## Services

Every service is one file in `services/`, opt-in through its name in `COMPOSE_PROFILES` (`.env`).
Hostnames inside the network are the service names; from the host use `localhost:<port>`.
All ports bind to `127.0.0.1` unless you set `BIND_IP=0.0.0.0` in `.env`.

| service | what | host port | login / notes |
|---|---|---|---|
| `workstation` | the machine | 8000-8099, 3000-3010, 5173-5180 | user `dev`, passwordless sudo |
| `mysql-8` | MySQL 8.4 LTS | 3306 | `dev_user` / `dev_password`, root `dev_root_password`, db `app` |
| `mysql-5` | MySQL 5.7 (EOL, legacy apps, pairs with php7.2) | 3307 | same; amd64 image, emulated on ARM |
| `mariadb-10` | MariaDB 10.11 | 3308 | same credentials |
| `postgres-16` | PostgreSQL 16 + PostGIS, pgvector, pg_cron, pg_partman | 5433 | `admin` / `admin` |
| `postgres-timescale-16` | TimescaleDB on PG 16 | 5432 | `admin` / `admin`, db `benchmark` |
| `mongodb-7` · `mongodb-7-express` | MongoDB 7 · web UI | 27017 · 8181 | `admin` / `admin` |
| `dynamodb-local` | DynamoDB + Streams | 18000 (inside: `dynamodb-local:8000`) | `AWS_ENDPOINT_URL_DYNAMODB` is preset in the workstation |
| `redis-7` · `redis-7-insight` | Redis 7 · Redis Insight | 6379 · 5540 | no password |
| `rabbitmq` | RabbitMQ 4 + management | 5672 · UI 15672 | `rabbit` / `rabbit`, vhost `vhost` |
| `kafka` | Kafka 4 (KRaft, single node) | 29092 (inside: `kafka:9092`) | |
| `elasticsearch` · `kibana` | Elastic 8.19, security off | 9229 · 5601 | |
| `meilisearch` | Meilisearch | 7700 | master key in `.env` |
| `mailpit` | catches all outgoing mail | SMTP 1025 · UI 8125 | Laravel: `MAIL_HOST=mailpit MAIL_PORT=1025` |
| `phpmyadmin` · `adminer` · `pgadmin` | DB web UIs | 8880 · 8321 · 5050 | pgadmin login in `.env` |
| `grafana` | Grafana | 3300 | `admin` / `admin` |
| `grpcui` | web UI for a gRPC server in the workstation | 8480 | `GRPCUI_TARGET=workstation:50051` |
| `android-emulator` | Android 14 emulator (x86_64 + KVM), screen in the browser | 6080 · adb 5555 | Linux hosts only (`/dev/kvm`), ≈ 4 GB RAM; inside: `adb-emu`, see below |
| `awslocalstack` | LocalStack | 14566 | needs `LOCALSTACK_AUTH_TOKEN` (free Hobby plan) |
| `ms-sql` | SQL Server 2022 Developer | 9433 | `sa` / `.env`, needs 2 GB |
| `cassandra` · `scylla` · `scylla-manager` | wide-column stores | 9044 · 9043 · 5080 | |
| `cratedb` · `quest` · `influx` | analytics / time series | 4200 · 9000 · 8186 | |
| `nominatim` · `osrm` · `osm-tile-server` · `overpass` | OpenStreetMap stack (needs a `.osm.pbf`, see `docker_files/`) | 8183 · 5001-5003 · 8182 · 12345 | heavy imports |

Connection strings inside the workstation need no host-side ports:
```php
new PDO("mysql:host=mysql-8;dbname=app", "dev_user", "dev_password");
```
```ts
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));   // endpoint + creds come from env
```

## The workstation

| | |
|---|---|
| PHP | `php7.2` … `php8.4`, `composer7.2` … `composer8.4`; plain `php` follows `php-default 8.1` (persisted); `phpv` lists them |
| Octane | `frankenphp` (static, own PHP), `swoole` + opcache for PHP 8.x |
| Node / Go / Java / Kotlin / Rust / Ruby / Python / Flutter | via [mise](https://mise.jdx.dev): `mise ls`; per project `mise use node@18`, `ruby@3.3` … (auto-switch on `cd`); Maven and Gradle too |
| Java / Kotlin | Temurin 21 + Maven + Gradle: Spring Boot runs as is (`./mvnw spring-boot:run`, 8080 is published); `kotlinc` for scripts; older projects: `mise use java@temurin-17` |
| Python / R | `python` + `pip` from mise, no venv needed; R from CRAN (`Rscript -e 'install.packages("tidyverse")'`, library in `/opt/caches/R`); Jupyter: `pip install jupyterlab && jupyter lab --ip 0.0.0.0 --port 8088` → http://localhost:8088 (a freshly pip/gem-installed CLI is not on PATH in scripts until `mise reshim`) |
| Android / Flutter / React Native | Android SDK in `/opt/caches/android-sdk` (`sdkmanager`, `adb`, licenses accepted; Gradle fetches other platforms itself), `flutter` + Dart, `CHROME_EXECUTABLE` set for Flutter web. Gradle is capped at 3 GB heap with 10-min daemon timeout via `/opt/caches/gradle/gradle.properties` (edit freely). Device: the `android-emulator` service, below |
| headless Chromium | `chromium --headless --screenshot=x.png https://…`; `CHROME_BIN` is set; Playwright, Puppeteer, Dusk, Lighthouse find it. Shared cache: `npx playwright install chromium` is instant after the first time |
| Docker | `docker`, `docker compose`, `lazydocker` talk to the host daemon (the socket is mounted: full control of host Docker, fine for a personal box) |
| Claude Code | already inside: `claude` CLI (apt stable channel) and the VS Code extension, installed into the container by `dev code`. Nothing to install on the host. Sign in once with a Pro/Max/Team/Enterprise or Console account (the free plan does not include Claude Code); the login persists in `~/.claude` |
| also | git, curl, jq, ripgrep, mysql/psql/redis clients, sqlite3, python3 + venv |

`sudo apt install …` inside the container is lost on `dev rebuild`; bake packages into
`docker_files/workstation/Dockerfile` instead. Runtimes go in `docker_files/workstation/mise-config.toml`
(then `runtime-bootstrap`, no rebuild).

### Android emulator

`android-emulator` is an Android 14 image (x86_64, needs `/dev/kvm`, so Linux hosts only) whose
screen is served as a web page. The workstation talks to it over the shared network:

```bash
dev up android-emulator            # screen: http://localhost:6080  (boots in under a minute)
cd projects/my-app && dev          # inside the workstation:
adb-emu                            #   adb connect + metro.host=workstation + adb reverse 8081 (run after every emulator start)
npx react-native run-android --active-arch-only   # builds only the emulator's x86_64 (4x faster); or: flutter run · ./gradlew installDebug
```

`adb-emu` attaches the device and points React Native at Metro in the workstation (a stock emulator would
look for it at 10.0.2.2, its own container, and show "Unable to load script"). The device is
factory-fresh on every start: use `dev down android-emulator` / `dev up android-emulator`, never
`docker stop` + `start` (the image leaves lock files behind and does not come up again). The default screen is a Nexus 5 (1080x1920); `ANDROID_EMULATOR_DEVICE` in `.env` picks another, but big ones (Galaxy S10, 1440x3040) are software-rendered and cost 6 GB + five cores.
Memory on a 12 GB laptop: emulator ≈ 4 GB, an Android Gradle build ≈ 3 GB — run one at a time and stop the
emulator (`dev down android-emulator`) before big builds; it never auto-starts after a reboot.
On macOS/Windows Docker has no KVM: run Android Studio's emulator (or a phone) on the host, start the
host's adb server with `adb -a nodaemon server`, and inside the workstation
`export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037`.

### VS Code details

`dev code` uses the *Dev Containers* extension's attach mode with the config in
`vscode/attached-container.json` (installed to VS Code's `nameConfigs/workstation.json` by `dev setup`;
`dev vscode --force` to re-install after editing). It sets the remote user, opens `/projects`, installs
the extensions and makes the integrated terminal a login shell so `node`, `php` etc. resolve.
Claude Code's extension shows *Installed in Container: workstation*; sign in once.

## Persistence and moving machines

Everything is a plain folder under `volumes/` (one exception: pgAdmin keeps its settings in the named
Docker volume `workstation_pgadmin-data`). Copy the repo folder (with `projects/` and `volumes/`) to
another machine, run `bin/dev setup`, done. `dev rebuild` never touches data. `dev down` stops
containers but keeps everything.

`.env` and `projects/` are git-ignored; `volumes/` content too.

## Troubleshooting

- **Service exits with a permission error on its data folder** → the folder under `volumes/` was created
  by Docker as root (happens only if you bypass `dev`): `sudo chown -R $(id -u):$(id -g) volumes/vol-<name>`.
- **"port is already allocated"** → something on the host uses it; `ss -ltnp | grep :<port>`.
- **node / go / ruby / flutter / adb / chromium missing right after the first start** → still bootstrapping:
  `dev 'tail -f /opt/caches/bootstrap.log'`. Re-run any time (also after editing `mise-config.toml`)
  with `dev runtime-bootstrap`.
- **android-emulator: "error gathering device information" / no `/dev/kvm`** → KVM exists only on Linux
  hosts (and is off inside most VMs). See *Android emulator* above for the host-side alternative.
- **VS Code lands as root** → `dev vscode --force`, then *Developer: Reload Window*.
- **VS Code stuck on "Downloading VS Code Server" / "Retrying"** → your network blocks Microsoft's
  redirector. `dev vscode-server` fetches it from the CDN directly (`dev code` does this on its own),
  then *Developer: Reload Window*.
- **Which file is wrong?** → `docker compose --profile '*' config` names file and line.
- **mysql-5 won't start** → it's an unmaintained amd64 image; use `mariadb-10` instead.

## Repo layout

```
compose.yml            lists services/*.yml (Compose `include`); default network = common
services/<name>.yml    one standalone Compose file per service, `profiles: [<name>]`
docker_files/          Dockerfiles: workstation, postgres+GIS, OSM tools
bin/dev                the command above
vscode/                VS Code attach config
prerequisites/         host setup: setup-host.sh (guided), install-docker.sh, docker-cleanup.sh
volumes/  projects/    data and code (git-ignored)
.claude/               CLAUDE.md conventions + skills for working on this repo with Claude Code
```

Adding a service = one new file + one line in `compose.yml` (template and rules in
`.claude/skills/add-service/SKILL.md`). Requirements on the host: Docker with Compose v2.20+; nothing else.
