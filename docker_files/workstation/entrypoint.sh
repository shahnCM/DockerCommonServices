#!/usr/bin/env bash
# entrypoint — runs as `dev` once per container start, then hands over to
# CMD (sleep infinity). Root-only steps go through passwordless sudo.
# Everything here is idempotent.
set -u

# 1. own the bind mounts (top level only — never -R over big caches)
sudo chown dev:dev /home/dev /opt/mise /opt/caches /projects 2>/dev/null || true
for d in composer npm go-mod gopath m2 gradle mise-cache ms-playwright android-sdk pub R; do
  mkdir -p "/opt/caches/$d"
done

# 1b. Gradle defaults for this box (user-level wins over project gradle.properties):
#     3 GB heap instead of the 8 GB some templates ask for, daemons exit after
#     10 idle minutes instead of 3 hours. Seeded once; edit the file freely.
if [ ! -f /opt/caches/gradle/gradle.properties ]; then
  cat > /opt/caches/gradle/gradle.properties <<EOF
# seeded by the workstation entrypoint — yours to edit (persistent volume)
org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g
org.gradle.daemon.idletimeout=600000
EOF
fi

# 2. docker socket: let `dev` drive the host daemon (docker, lazydocker)
#    without sudo. The socket's group id differs per host, so map it here.
if [ -S /var/run/docker.sock ]; then
  gid="$(stat -c %g /var/run/docker.sock)"
  if [ "$gid" != "0" ]; then
    getent group "$gid" >/dev/null || sudo groupadd -g "$gid" docker-host
    sudo usermod -aG "$(getent group "$gid" | cut -d: -f1)" dev
  fi
fi

# 3. seed home dir on first run (home is a bind mount, starts empty)
if [ ! -f /home/dev/.bashrc ]; then
  cp -n /etc/skel/.bashrc /etc/skel/.profile /home/dev/ 2>/dev/null || true
fi
if ! grep -q workstation/bashrc.seed /home/dev/.bashrc 2>/dev/null; then
  echo '[ -f /etc/workstation/bashrc.seed ] && . /etc/workstation/bashrc.seed  # workstation/bashrc.seed' >> /home/dev/.bashrc
fi

# 4. default `php` shim (persists in home volume, survives rebuilds)
if [ ! -e /home/dev/.local/bin/php ]; then
  php-default "${PHP_DEFAULT:-8.3}" || true
fi

# 5. one-time install of every mise runtime + Chromium + the Android SDK
#    into the persistent volumes. Runs in the background so the container
#    is usable immediately (PHP works right away). A leftover .bootstrapping
#    marker can only be stale at container start, so retry.
rm -f /opt/mise/.bootstrapping
if [ ! -f /opt/mise/.bootstrapped ]; then
  touch /opt/mise/.bootstrapping
  ( runtime-bootstrap > /opt/caches/bootstrap.log 2>&1 \
      && mv /opt/mise/.bootstrapping /opt/mise/.bootstrapped \
      || echo 'bootstrap failed — fix the cause, then run: runtime-bootstrap' >> /opt/caches/bootstrap.log ) &
fi

exec "$@"
