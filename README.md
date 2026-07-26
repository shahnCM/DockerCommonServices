# DockerCommonServices

## Overview

This project uses Docker Compose to manage multiple services, with configurations for different
environments (PROD, DEV, TEST). A small Go program generates the final `docker-compose.yml` from
individual service files, so enabling or disabling a service is a file rename, not a merge conflict.

On top of the original services (mongodb, postgres+GIS, redis, nominatim, osrm, etc.), this repo
also includes a **workstation** container — one always-on box with every PHP version (7.2→8.4),
Node, Go, and Java installed side by side, so working across multiple projects and runtimes feels
like using a single local machine, while every runtime and service still lives in Docker.

---

## 1. Machine setup (one-time, per computer)

Everything below takes a **freshly installed Linux Os** to fully working on this repo. Skip
anything already installed.

### Partitioning (only relevant when reinstalling the OS)
- Give `/home` its own partition — this repo and every DB/cache live under `~/dev/` as bind mounts,
  so a separate, **unformatted** `/home` survives an OS reinstall untouched. Only format it on a
  genuinely fresh start with nothing to preserve.
- Root (`/`): 60–100GB ext4, formatted fresh — holds the OS + `/var/lib/docker` (every image layer).
- EFI: fine to format on a single-OS machine. Dual-booting Windows → leave unformatted.
- Any other existing partition (NTFS, extra FAT32) — leave unformatted unless you know it's disposable.

### Base packages
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget gpg unzip
```

### Docker
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```
**Log out and back in once** (or `newgrp docker`) — this activates group membership; skip it and
every `docker` command fails with "permission denied" even though install succeeded. Verify both
pieces:
```bash
docker run hello-world
docker compose version
```

### Go (latest — the `apt` version is usually stale)
Only needed for `go run generate-compose.go`; skip if `docker-compose.yml` is already committed
and you're not adding services.
```bash
cd /tmp
GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -1)
wget https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf ${GO_VERSION}.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc && source ~/.bashrc
go version
```

### lazydocker (optional, recommended — this repo has a lot of services)
```bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```
Run `lazydocker` from anywhere — every container, logs, and stats on one screen, in real time.

---

## 2. Repo structure & conventions

- `services/` — one Docker Compose file per service.
- Prefix a filename with **`?`** (e.g. `?rabbitmq.yml`) to exclude it from the generated compose
  file entirely — the standard way to keep unused services defined but dormant.
- `generate-compose.go` — merges every non-`?` file in `services/` into one `docker-compose.yml`.
  Build once (`go build -o generate-compose && ./generate-compose`) or just `go run generate-compose.go`
  each time.
- `.env` (gitignored) — all credentials and path variables; `.env.example` is the template.
- `volumes/` — where every service's actual data lives, one folder per service, all bind-mounted
  and visible on disk (nothing hidden in anonymous Docker volumes). Some services' volume folders
  need specific permissions depending on the container's internal user.
- `bin/dev` — enters the workstation container (see §4).
- `docker_files/` — Dockerfiles and scripts for services that build a custom image (workstation,
  postgres+GIS, etc.).

## 3. Generate & start services

```bash
git clone git@github.com:shahnCM/DockerCommonServices.git ~/dev/DockerCommonServices
cd ~/dev/DockerCommonServices
cp .env.example .env
```
Edit `.env`: set `USER_UID`/`USER_GID` to match `id -u` / `id -g`, adjust any credentials you want
changed from the defaults.
```bash
go run generate-compose.go
```
Start **only what you actually want running** — a bare `up -d --build` starts every service
currently un-prefixed with `?`, which may be more than needed day to day:
```bash
docker compose up -d --build workstation mysql-8 mysql-5 phpmyadmin redis-7 dynamodb-local
```
Add or remove services anytime with the same pattern: `docker compose up -d <service-name>`.

---

## 4. The workstation container (runtimes)

One always-on container with every PHP version installed side by side (via the Sury PPA) plus
Node/Go/Java managed by `mise` (auto-switches per project via `.mise.toml`). It sits on the same
`common` network as every other service, so `mysql-8`, `redis-7`, etc. are reachable by hostname.

```bash
echo 'export PATH="$HOME/dev/DockerCommonServices/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
which dev   # should print a path — if empty, open a fresh terminal and retry
```

### Daily use
```bash
cd ~/dev/DockerCommonServices/projects/legacy-app && dev   # shell opens *in that folder*, in the container
php7.2 artisan serve --host=0.0.0.0 --port=8072            # → localhost:8072 on your host
```
Another tab, another project, same container — mise auto-activates that project's Node version:
```bash
cd ~/dev/DockerCommonServices/projects/frontend && dev
npm run dev -- --host
```

| you want | you type |
|---|---|
| shell / run one command | `dev` / `dev composer install` |
| pick a PHP explicitly | `php7.4 script.php`, `composer7.2 install` |
| change default `php` | `php-default 8.1` (persists across rebuilds) |
| pin a runtime per project | in project dir: `mise use node@18` |
| list installed PHPs / runtimes | `phpv` / `mise ls` |
| serve on a port | anything in `WS_PORTS_A/B/C` (`.env`), bind `0.0.0.0` |

## 5. Databases & phpMyAdmin

| service | hostname | host port | use for |
|---|---|---|---|
| `mysql-8` | `mysql-8` | `localhost:3306` | current projects |
| `mysql-5` | `mysql-5` | `localhost:3307` | legacy apps (pairs with `php7.2`) |
| `redis-7` | `redis-7` | `localhost:6379` | caching/sessions, no password set |
| `dynamodb-local` | `dynamodb-local` | `localhost:18000` | DynamoDB + Streams |

**phpMyAdmin** → `http://localhost:8880`. Login screen shows a server dropdown — pick **MySQL 8**
or **MySQL 5** — then `dev_user` / `dev_password` (or `root` / your `DB_MYSQL_ROOT_PASSWORD`).

```php
new PDO("mysql:host=mysql-8;dbname=app", "dev_user", "dev_password");   // or host=mysql-5
```

`mysql:5.7` is an old image — if it won't start on your host, check `docker compose logs mysql-5`
first; `mariadb:10.6` is a wire-compatible drop-in replacement.

### DynamoDB local

`amazon/dynamodb-local` — AWS's own emulator, the same one LocalStack wraps. Streams are included;
the DynamoDBStreams API is served on the same port, so no second endpoint.

Two addresses, and the difference bites:

| from | endpoint |
|---|---|
| inside the workstation | `http://dynamodb-local:8000` |
| your host (NoSQL Workbench, `curl`) | `http://localhost:18000` |

Published as `18000` because `8000` sits inside `WS_PORTS_A=8000-8099`, which the workstation
already claims.

`services/workstation.yml` sets `AWS_ENDPOINT_URL_DYNAMODB` for you. The AWS SDK reads that
variable natively, so application code needs **no** local-vs-prod branching — unset it in
production and the same code hits real AWS. The `AWS_*` credentials in `.env` are ignored by the
emulator but must be present, or the SDK refuses to sign the request.

```ts
// no endpoint, no credentials in code — the env vars do it
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
```

Two things that will waste an afternoon if you don't know them:

- **`-sharedDb` is not optional.** Without it, DynamoDB Local keys the database file by access-key
  and region, so a seed script and an app using different credentials silently see different tables.
- **The data dir must not be root-owned.** The process runs as the `dynamodblocal` user and dies
  with an opaque SQLite "database file could not be opened" error otherwise. `bin/dev` pre-creates
  it for this reason — create it yourself if you start the service some other way.

Known gaps vs real DynamoDB: provisioned throughput is ignored, parallel scans aren't supported,
`TransactionConflictException` is never thrown, and stream shard behaviour differs because there's
no table partitioning locally. Good for the programming model, not for tuning timing.

There is also a dormant `?awslocalstack.yml` if you later want S3, SSM, Secrets Manager and the
rest wired together — note LocalStack now requires an account and auth token, and Cognito is not
in the free tier.

## 6. VS Code (attach to the workstation)

Edit *inside* the container, not on the host — that way IntelliSense, ESLint and Jest all resolve
against the container's Node and the project's `node_modules`. Attaching is preferred over a
per-project `.devcontainer/`: your projects live outside this repo, and a devcontainer file would
have to reference a compose file outside its own tree.

Install the **Dev Containers** extension (`ms-vscode-remote.remote-containers`), then Remote
Explorer → Dev Containers → attach to `workstation`.

**The first attach lands as `root`.** The Dockerfile creates the `dev` user but never sets
`USER dev` — which is why `bin/dev` passes `-u dev` explicitly, and VS Code doesn't know about that
flag. Fix it with an attached-container config **on your host**:

```
~/.config/Code/User/globalStorage/ms-vscode-remote.remote-containers/nameConfigs/workstation.json
```
macOS: `~/Library/Application Support/Code/...` — the filename must match the container name.
The *Open Attached Container Configuration File* palette command often reports "no configuration
found"; just create the file with `mkdir -p` and an editor.

```json
{
  "workspaceFolder": "/projects",
  "remoteUser": "dev",
  "extensions": [
    "anthropic.claude-code",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode"
  ],
  "settings": {
    "terminal.integrated.defaultProfile.linux": "bash-login",
    "terminal.integrated.profiles.linux": {
      "bash-login": { "path": "bash", "args": ["-l"] }
    }
  }
}
```

Then *Developer: Reload Window* — or close the window and re-attach, since `remoteUser` is applied
when the connection is established and a reload doesn't always re-read it. Verify:

```bash
whoami && pwd && which node    # dev, /projects, a path under /opt/mise
```

`remoteUser: dev` earns its keep twice: it stops VS Code writing root-owned files into the
`/projects` bind mount, and it puts the VS Code server in `/home/dev/.vscode-server` — which *is*
bind-mounted, so it survives `dev rebuild` instead of re-downloading every time. The orphaned root
copy is safe to delete: `docker compose exec workstation rm -rf /root/.vscode-server`.

**Why `services/workstation.yml` sets `PATH` explicitly.** `profile.d-workstation.sh` puts
`/opt/mise/shims` on `PATH`, but only for login shells. VS Code's extension host isn't one, so
without the container-level `PATH` you get the confusing case where the integrated terminal finds
`node` fine and ESLint reports it missing. If shims are stale, `mise reshim`.

### Claude Code

Installed into the container by the `extensions` list above — check the Extensions view says
*Installed in Container: workstation*, not the local section, or it'll be reading your host
filesystem instead of `/projects`. Sign in on first open; the token lands in `/home/dev/.claude`,
bind-mounted, so you log in once.

The extension bundles its own CLI for the chat panel but does **not** put `claude` on your `PATH`.
Install the standalone CLI if you want `claude` in the integrated terminal, MCP servers
(`claude mcp add`), or the full command set:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Lands in `~/.local/bin` — already first on `PATH` and bind-mounted, so it survives rebuilds. Avoid
`npm install -g`: mise's `node = "lts"` is a moving target and global packages disappear with it.
Extension and CLI share conversation history and `~/.claude/settings.json`, so adding the CLI later
reconfigures nothing.

## 7. Demo apps (tested, working examples)

`projects/php-mysql-redis-demo/visit.php` — logs each run to MySQL, counts hits in Redis:
```bash
cd ~/dev/DockerCommonServices/projects/php-mysql-redis-demo && dev
php8.1 visit.php
```
`projects/node-redis-demo/` — hits the *same* Redis counter, proving both runtimes share state:
```bash
cd ~/dev/DockerCommonServices/projects/node-redis-demo && dev
npm install && npm start   # then curl localhost:3000 from another tab
```

## 8. Persistence — "nothing goes unnoticed"

Everything stateful is a visible bind mount under `volumes/`, not an anonymous Docker volume:
```
volumes/vol-workstation/home/     dotfiles, shell history, your `php-default` choice,
                                  ~/.vscode-server, ~/.claude, ~/.local/bin/claude
volumes/vol-workstation/mise/     installed node/go/java versions
volumes/vol-workstation/caches/   composer, npm, go-mod, m2, gradle
volumes/vol-mysql-8/data/
volumes/vol-mysql-5/data/
volumes/vol-dynamodb-local/data/  shared-local-instance.db — tables and streams
```
Rebuilding the workstation image (`dev rebuild`) loses none of this — only packages installed
ad-hoc with `sudo apt` inside the container are ephemeral; bake those into the Dockerfile instead.