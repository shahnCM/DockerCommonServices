---
name: add-service
description: Add a new Docker Compose service to this workstation repo — file, profile, ports, volumes, listing in compose.yml, README row, validation.
---

# Add a service

One file per service, always standalone, always opt-in via its profile.

1. Create `services/<name>.yml` from this template. Service name, `container_name`, and the profile are the **same string**:

```yaml
# <What it is>  →  host localhost:<port>   (login / notes)
services:
  <name>:
    image: <image>:<pinned-tag>
    container_name: <name>
    profiles: [<name>]
    restart: unless-stopped
    environment:
      SOME_PASSWORD: ${SOME_PASSWORD:-dev_default}
    ports:
      - "${BIND_IP:-127.0.0.1}:<host-port>:<container-port>"
    healthcheck:            # if the image ships a cheap probe
      test: ["CMD", "..."]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits: { memory: 512M, cpus: '1.0' }
    volumes:
      - ./volumes/vol-<name>:/path/in/container
```

2. Rules that keep the repo simple:
   - No `networks:` block. Every service joins `common` automatically; hostnames are service names.
   - Paths are relative to the repo root (`./volumes/...`, `./docker_files/...`), never `${VOL_BASE}`.
   - Ports: always `${BIND_IP:-127.0.0.1}:HOST:CONTAINER`. Host ports must stay outside the workstation ranges (8000-8099, 3000-3010, 5173-5180). Use `${VAR:-default}` (colon form) for every variable.
   - Never use `${VAR:?error}`: interpolation runs for all services even when the profile is off, so it would break every command.
   - `depends_on` only when the service is useless without the other one (kibana → elasticsearch). Admin UIs do not depend on databases.
   - If the container runs as a fixed non-root uid and writes a bind mount, either add `user: "${USER_UID:-1000}:${USER_GID:-1000}"` (when the image supports arbitrary uids) or say so in the header comment. `bin/dev` pre-creates every bind folder as the host user.
   - Verify the tag exists: `docker manifest inspect <image>:<tag>`.

3. List the file in `compose.yml` under `include.path` in the matching section.

4. Add a row to the README services table and, if a credential is involved, a line in `.env.example`.

5. Validate:
```bash
docker compose --profile '*' config --quiet
docker compose --profile '*' config | grep -E '^\s+published: ' | awk '{print $2}' | tr -d '"' | sort | uniq -d   # must print nothing
docker compose up -d <name> && docker compose ps <name> && docker compose logs --tail=50 <name>
docker compose --profile '*' down <name>
```
