#!/usr/bin/env bash
# docker-cleanup.sh — reclaim disk from Docker. Standalone: needs only Docker,
# not this repo, so you can copy it to any machine.
#
#   bash docker-cleanup.sh              safe   stopped containers, dangling images,
#                                              ANONYMOUS volumes, unused networks, build cache
#   bash docker-cleanup.sh --all        more   + every unused image and every unused NAMED volume
#   bash docker-cleanup.sh --nuke       all    running containers too, every image, every volume
#   bash docker-cleanup.sh --dry-run           print the plan, delete nothing
#   bash docker-cleanup.sh --yes               skip the confirmation prompt
#
# Only --all and --nuke can destroy data you still want: a NAMED volume is where
# a database keeps its files. This repo stores almost everything in bind mounts
# under ./volumes, which Docker never touches at any level — only pgadmin uses a
# named volume. Anonymous volumes (64 hex characters, no name) are leftovers and
# safe to drop at the default level.
set -uo pipefail

MODE=safe; DRY=0; YES=0
for a in "$@"; do
  case "$a" in
    --all)     MODE=all ;;
    --nuke)    MODE=nuke ;;
    --dry-run|-n) DRY=1 ;;
    --yes|-y)  YES=1 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a  (try --help)"; exit 1 ;;
  esac
done

command -v docker >/dev/null 2>&1 || { echo "docker is not installed — nothing to clean"; exit 0; }
if ! docker info >/dev/null 2>&1; then
  echo "cannot talk to the Docker daemon."
  echo "  is it running?   are you in the docker group? (sudo usermod -aG docker \$USER, then log out and in)"
  exit 1
fi

hr() { printf '%s\n' "------------------------------------------------------------"; }
# print a list, one indented item per line, or "(none)"
show() { if [ -z "${1:-}" ]; then echo "    (none)"; else printf '%s\n' "$1" | sed 's/^/    /'; fi; }
count() { [ -z "${1:-}" ] && echo 0 || printf '%s\n' "$1" | grep -c .; }

echo "== current usage"
docker system df
hr

# ---- work out what goes ------------------------------------------------------
STOPPED="$(docker ps -aq -f status=exited -f status=created -f status=dead 2>/dev/null)"
RUNNING="$(docker ps -q 2>/dev/null)"
DANGLING_IMG="$(docker images -q -f dangling=true 2>/dev/null | sort -u)"
UNUSED_VOL="$(docker volume ls -q -f dangling=true 2>/dev/null)"
# anonymous volumes are 64 hex characters; anything else was given a name
ANON_VOL="$(printf '%s\n' "$UNUSED_VOL"  | grep -xE '[0-9a-f]{64}' 2>/dev/null)"
NAMED_VOL="$(printf '%s\n' "$UNUSED_VOL" | grep -vxE '[0-9a-f]{64}' 2>/dev/null | grep .)"

echo "== plan  (level: $MODE)"
case "$MODE" in
  safe)
    echo "  stopped containers        $(count "$STOPPED")"
    echo "  dangling images           $(count "$DANGLING_IMG")"
    echo "  anonymous volumes         $(count "$ANON_VOL")"
    show "$ANON_VOL"
    echo "  unused networks + UNUSED build cache (reusable cache is kept, so rebuilds stay fast)"
    echo
    echo "  KEPT: running containers, every tagged image, and these unused NAMED volumes:"
    show "$NAMED_VOL"
    echo "  (use --all to remove those too)"
    ;;
  all)
    echo "  stopped containers        $(count "$STOPPED")"
    echo "  ALL unused images (not just dangling)"
    echo "  ALL unused volumes        $(count "$UNUSED_VOL")  <-- INCLUDES NAMED VOLUMES, this is data"
    show "$UNUSED_VOL"
    echo "  unused networks + ALL build cache (the next image build starts from scratch)"
    echo
    echo "  KEPT: running containers and anything they use."
    ;;
  nuke)
    echo "  running containers        $(count "$RUNNING")   <-- these get killed"
    echo "  stopped containers        $(count "$STOPPED")"
    echo "  EVERY image, EVERY volume, every custom network, all build cache."
    echo
    echo "  ALL VOLUMES GO, in use or not:"
    show "$(docker volume ls -q 2>/dev/null)"
    echo
    echo "  Bind mounts on the host (this repo's ./volumes and ./projects) are NOT touched."
    ;;
esac
hr

if [ "$DRY" = 1 ]; then echo "dry run — nothing was removed."; exit 0; fi

if [ "$YES" != 1 ]; then
  case "$MODE" in
    safe) read -r -p "proceed? [y/N] " ans; case "$ans" in y|Y|yes) ;; *) echo "aborted"; exit 1 ;; esac ;;
    *)    echo "This can delete data that is not backed up."
          read -r -p "type 'yes' to continue: " ans; [ "$ans" = yes ] || { echo "aborted"; exit 1; } ;;
  esac
fi

# ---- do it -------------------------------------------------------------------
echo
case "$MODE" in
  safe)
    [ -n "$STOPPED" ] && { echo "== removing stopped containers"; docker rm $STOPPED >/dev/null; }
    echo "== pruning dangling images";  docker image prune -f   >/dev/null
    echo "== pruning anonymous volumes"; docker volume prune -f >/dev/null
    echo "== pruning unused networks";  docker network prune -f >/dev/null
    echo "== pruning unused build cache"; docker builder prune -f >/dev/null
    ;;
  all)
    [ -n "$STOPPED" ] && { echo "== removing stopped containers"; docker rm $STOPPED >/dev/null; }
    echo "== pruning all unused images";  docker image prune -af  >/dev/null
    echo "== pruning all unused volumes"; docker volume prune -af >/dev/null
    echo "== pruning unused networks";    docker network prune -f >/dev/null
    echo "== pruning build cache";        docker builder prune -af >/dev/null
    ;;
  nuke)
    ids="$(docker ps -aq)";        [ -n "$ids" ] && { echo "== removing all containers"; docker rm -f $ids >/dev/null; }
    vols="$(docker volume ls -q)"; [ -n "$vols" ] && { echo "== removing all volumes";   docker volume rm -f $vols >/dev/null 2>&1; }
    imgs="$(docker images -aq | sort -u)"; [ -n "$imgs" ] && { echo "== removing all images"; docker rmi -f $imgs >/dev/null 2>&1; }
    echo "== pruning networks";     docker network prune -f  >/dev/null
    echo "== pruning build cache";  docker builder prune -af >/dev/null
    ;;
esac

hr
echo "== usage now"
docker system df
echo
echo "Done."
[ "$MODE" = nuke ] && echo "The workstation image is gone too — 'dev rebuild' takes 10-20 minutes."
exit 0
