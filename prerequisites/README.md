# Prerequisites

The host needs exactly two things: **Docker Engine with Compose v2** and, if you want the editor
part, **VS Code**. Nothing else (no Go, no Node, no PHP) is installed on the host.

## 0. The guided way (Linux)

One script, three questions, nothing done that you did not agree to:

```bash
bash prerequisites/setup-host.sh
```

```
1/3  clean      ?   reclaim Docker disk space   -> docker-cleanup.sh
2/3  install    ?   Docker Engine + Compose v2  -> install-docker.sh
3/3  add2path   ?   put bin/ on your PATH so `dev` works from any folder
```

It ends by telling you to **log out and log back in**, which is what makes the `docker`
group and the new `PATH` take effect. Run it as yourself, not with `sudo` — step 3 writes to
your own `~/.bashrc` (or `~/.zshrc`), and step 2 calls `sudo` on its own.

`--yes` answers y to everything, `--deep-clean` makes step 1 the `--all` cleanup. Re-running is
safe: the PATH line is only ever added once.

The rest of this page is the same work done by hand.

## 1. Docker

### Linux (Ubuntu, Debian, and derivatives)

```bash
sudo bash prerequisites/install-docker.sh
```

Installs only these packages from Docker's official repository and nothing more:

| package | why |
|---|---|
| `docker-ce` | the engine |
| `docker-ce-cli` | the `docker` command |
| `containerd.io` | container runtime the engine uses |
| `docker-buildx-plugin` | builds the workstation image |
| `docker-compose-plugin` | `docker compose` v2 (v2.20+ needed for `include`) |

It also enables the service and adds you to the `docker` group. **Log out and back in once**
afterwards, otherwise every `docker` command says "permission denied".

Safe to re-run: it upgrades in place and keeps your images and data.

**Start from zero** (removes every Docker package *and* all images, containers, volumes and
`~/.docker`, then installs the set above; asks for confirmation):

```bash
sudo bash prerequisites/install-docker.sh --purge
```

Add `--yes` to skip the confirmation prompt.

### Other Linux

Follow https://docs.docker.com/engine/install/ for your distro, install the same five packages
listed above, then `sudo usermod -aG docker $USER` and log out and in.

### macOS / Windows

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/). It ships the engine,
Compose v2 and buildx together; nothing else is needed. On Windows use the WSL 2 backend and run
everything from a WSL terminal (the repo must live inside the WSL filesystem, e.g. `~/workstation`,
not under `/mnt/c`).

### Verify

```bash
docker run --rm hello-world
docker compose version        # v2.20 or newer
```

## 2. VS Code (optional)

Install [VS Code](https://code.visualstudio.com/). The *Dev Containers* extension is installed
automatically the first time you run `dev code`; the extensions inside the container
(Claude Code, ESLint, Prettier, PHP, Go, Python) come from `vscode/attached-container.json`.

On macOS also run *Command Palette → Shell Command: Install 'code' command in PATH* so `dev code`
can find the `code` binary.

## 3. lazydocker on the host (optional)

Inside the workstation `lazydocker` is already there (`dev lazy`). If you also want it on the host:

```bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
# installs to ~/.local/bin — make sure that is on your PATH
```

## 4. Cleaning up Docker

`docker-cleanup.sh` reclaims disk. It needs only Docker, so you can copy the one file to any
machine. Three levels, and every one of them takes `--dry-run` to print the plan and delete
nothing:

```bash
bash prerequisites/docker-cleanup.sh --dry-run   # see the plan first, always fine to run
bash prerequisites/docker-cleanup.sh             # safe
bash prerequisites/docker-cleanup.sh --all       # also removes unused NAMED volumes
bash prerequisites/docker-cleanup.sh --nuke      # everything, running containers included
```

| level | removes | keeps |
|---|---|---|
| default | stopped containers, dangling images, **anonymous** volumes, unused networks, unused build cache | running containers, tagged images, every **named** volume, reusable build cache |
| `--all` | + every unused image, + every unused **named** volume, + all build cache | running containers and what they use |
| `--nuke` | every container, image, volume, custom network and all build cache | nothing |

The distinction that matters is **anonymous vs named volumes**. An anonymous volume is a 64-hex
leftover that no longer belongs to anything, so the default level drops it. A named volume is where
a database keeps its files, so only `--all` and `--nuke` touch it — and both print the names first
and make you type `yes`.

This repo is mostly safe from all of it: every service keeps its data in a bind mount under
`volumes/`, which is an ordinary host folder Docker never prunes. Only pgadmin uses a named volume.
`--nuke` does delete the `workstation:local` image, and rebuilding it takes 10-20 minutes.

Add `--yes` to skip the confirmation.

## Then

```bash
bin/dev setup
```

See the main [README](../README.md) for daily use.
