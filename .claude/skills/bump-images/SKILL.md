---
name: bump-images
description: Upgrade a service's Docker image tag safely — verify the tag exists, check for breaking env-var or data-format changes, test start-up, and keep data volumes compatible.
---

# Bump an image

1. Find the current tag in `services/<name>.yml`. Prefer pinned major/minor tags (`mysql:8.4`, `influxdb:2`) over `latest` for anything with a data directory; `latest` is acceptable for stateless UIs.

2. Confirm the candidate exists and supports the host arch:
```bash
docker manifest inspect <image>:<tag> | grep -E '"architecture"' | sort | uniq -c
```

3. Read the image's release notes for the jump. Known traps in this repo:
   - `mysql:8` now resolves to 8.4: `mysql_native_password` is off by default (PHP ≥ 7.2.4 is fine).
   - `mysql:5.7` is unmaintained and amd64-only; the file sets `platform: linux/amd64`.
   - `influxdb:latest` is 3.x with a different bootstrap; stay on `influxdb:2` unless migrating data.
   - `postgres:<major>`: a data directory is tied to its major version. A major bump needs `pg_dumpall` + a fresh `volumes/vol-postgres-16`, or a renamed service (`postgres-17`) with its own volume.
   - `localstack/localstack` requires `LOCALSTACK_AUTH_TOKEN` since 2026.03.
   - Elastic images: keep elasticsearch and kibana on the identical version.

4. Edit the tag, then:
```bash
docker compose --profile '*' config --quiet
docker compose pull <name>
docker compose up -d <name> && sleep 10 && docker compose ps <name> && docker compose logs --tail=50 <name>
```
   A healthcheck must reach `healthy`; if the service has none, curl/ping its port.

5. If a data-format migration is involved, say so explicitly in the commit message and README services table.
