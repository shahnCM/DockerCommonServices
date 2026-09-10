#!/usr/bin/env bash
# install-docker.sh — install exactly what this repo needs, from Docker's official repository:
#   docker-ce  docker-ce-cli  containerd.io  docker-buildx-plugin  docker-compose-plugin
# Ubuntu and Debian (and their derivatives). Idempotent: safe to re-run.
#
#   sudo bash prerequisites/install-docker.sh            install / upgrade, keep existing data
#   sudo bash prerequisites/install-docker.sh --purge    remove EVERY Docker package, image,
#                                                        container and volume first, then install
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "run with sudo:  sudo bash $0 $*"; exit 1; }
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
PURGE=0; YES=0
for a in "$@"; do case "$a" in --purge) PURGE=1 ;; --yes|-y) YES=1 ;; *) echo "unknown option: $a"; exit 1 ;; esac; done

# ---- which Docker repo ---------------------------------------------------------
. /etc/os-release
if [ -n "${UBUNTU_CODENAME:-}" ]; then
  DISTRO=ubuntu; CODENAME="$UBUNTU_CODENAME"            # Ubuntu and derivatives (Mint, Pop!_OS …)
elif [ "${ID:-}" = debian ] || [[ "${ID_LIKE:-}" == *debian* ]]; then
  DISTRO=debian; CODENAME="${VERSION_CODENAME:?}"
else
  echo "unsupported distro '${ID:-?}' — follow https://docs.docker.com/engine/install/ instead"; exit 1
fi
ARCH="$(dpkg --print-architecture)"
PKGS="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

# ---- optional: wipe everything first ------------------------------------------------
if [ "$PURGE" = 1 ]; then
  echo "!! --purge removes ALL Docker packages AND all images, containers, volumes, networks"
  echo "   (/var/lib/docker, /var/lib/containerd, /etc/docker, $TARGET_HOME/.docker)."
  if [ "$YES" != 1 ]; then read -r -p "   type 'yes' to continue: " ans; [ "$ans" = yes ] || { echo "aborted"; exit 1; }; fi
  echo "== stopping services"
  systemctl disable --now docker.service docker.socket containerd.service 2>/dev/null || true
  echo "== purging packages"
  apt-get purge -y $PKGS \
    docker-ce-rootless-extras docker-model-plugin docker-scan-plugin \
    docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true
  apt-get autoremove -y --purge
  echo "== removing data"
  rm -rf /var/lib/docker /var/lib/containerd /etc/docker /run/docker /run/containerd "$TARGET_HOME/.docker"
  rm -f /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.sources \
        /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.asc
fi

# ---- install --------------------------------------------------------------------------
echo "== Docker repository ($DISTRO $CODENAME $ARCH)"
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg >/dev/null
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/$DISTRO/gpg" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$DISTRO $CODENAME stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq

echo "== installing: $PKGS"
apt-get install -y --no-install-recommends $PKGS

echo "== enabling service, adding $TARGET_USER to the docker group"
systemctl enable --now containerd.service docker.service
groupadd -f docker
usermod -aG docker "$TARGET_USER"

echo
docker --version
docker compose version
echo
if id -nG "$TARGET_USER" | grep -qw docker && [ "$(id -u "$TARGET_USER")" != 0 ]; then
  echo "Done. Log out and back in once so the docker group applies, then run:  bin/dev setup"
fi
