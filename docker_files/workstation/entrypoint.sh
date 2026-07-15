#!/usr/bin/env bash
# entrypoint — runs as root once per container start, then sleeps.
# Everything here is idempotent.
set -u

# 1. own the bind mounts (top level only — never -R over big caches)
chown dev:dev /home/dev /opt/mise /opt/caches /projects 2>/dev/null || true
for d in composer npm go-mod gopath m2 gradle mise-cache; do
  mkdir -p "/opt/caches/$d" && chown dev:dev "/opt/caches/$d"
done

# 2. seed home dir on first run (home is a bind mount, starts empty)
if [ ! -f /home/dev/.bashrc ]; then
  cp -n /etc/skel/.bashrc /etc/skel/.profile /home/dev/ 2>/dev/null || true
  chown dev:dev /home/dev/.bashrc /home/dev/.profile 2>/dev/null || true
fi
if ! grep -q workstation/bashrc.seed /home/dev/.bashrc 2>/dev/null; then
  echo '[ -f /etc/workstation/bashrc.seed ] && . /etc/workstation/bashrc.seed  # workstation/bashrc.seed' >> /home/dev/.bashrc
fi

# 3. default `php` shim (persists in home volume, survives rebuilds)
if [ ! -e /home/dev/.local/bin/php ]; then
  su -s /bin/bash dev -c "php-default ${PHP_DEFAULT:-8.3}" || true
fi

# 4. one-time install of node/go/java/maven/gradle into /opt/mise
#    (background so the container is usable immediately; PHP works right away)
if [ ! -f /opt/mise/.bootstrapped ] && [ ! -f /opt/mise/.bootstrapping ]; then
  touch /opt/mise/.bootstrapping && chown dev:dev /opt/mise/.bootstrapping
  su -s /bin/bash dev -c \
    "runtime-bootstrap > /opt/caches/bootstrap.log 2>&1 \
       && mv /opt/mise/.bootstrapping /opt/mise/.bootstrapped \
       || echo 'bootstrap failed — run runtime-bootstrap manually' >> /opt/caches/bootstrap.log" &
fi

exec "$@"
