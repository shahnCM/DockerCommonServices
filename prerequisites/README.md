# Prerequisites

The host needs exactly two things: **Docker Engine with Compose v2** and, if you want the editor
part, **VS Code**. Nothing else (no Go, no Node, no PHP) is installed on the host.

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

## Then

```bash
bin/dev setup
```

See the main [README](../README.md) for daily use.
