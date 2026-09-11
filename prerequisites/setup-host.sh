#!/usr/bin/env bash
# setup-host.sh — one guided pass over the three host-side chores, each asked
# before it runs. Nothing happens that you did not answer 'y' to.
#
#   bash prerequisites/setup-host.sh                ask each step
#   bash prerequisites/setup-host.sh --yes          answer y to everything
#   bash prerequisites/setup-host.sh --deep-clean   make step 1 the --all cleanup
#
#   1. clean      reclaim Docker disk space   (prerequisites/docker-cleanup.sh)
#   2. install    Docker Engine + Compose v2  (prerequisites/install-docker.sh)
#   3. add2path   put bin/ on your PATH so `dev` works from any folder
#
# Run it as yourself, NOT with sudo — step 3 has to write to your own shell rc.
# Step 2 calls sudo on its own and will ask for your password.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
YES=0; DEEP=0
for a in "$@"; do
  case "$a" in
    --yes|-y)     YES=1 ;;
    --deep-clean) DEEP=1 ;;
    -h|--help)    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a  (try --help)"; exit 1 ;;
  esac
done

if [ "$(id -u)" = 0 ]; then
  echo "Do not run this with sudo — step 3 must write to your own shell rc."
  echo "Run:  bash $0 $*"
  exit 1
fi
if [ "$YES" != 1 ] && [ ! -t 0 ]; then
  echo "no terminal to ask questions on — re-run with --yes"; exit 1
fi

ask() {  # ask "question" [default y|n]  -> 0 for yes
  local q="$1" d="${2:-n}" a p
  [ "$d" = y ] && p="[Y/n]" || p="[y/N]"
  if [ "$YES" = 1 ]; then printf '%s %s y   (--yes)\n' "$q" "$p"; return 0; fi
  read -r -p "$q $p " a
  a="${a:-$d}"
  case "$a" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
hr() { printf '\n%s\n' "============================================================"; }

CLEANED=skipped; INSTALLED=skipped; PATHED=skipped; FAILED=0

# ---- 1. clean ----------------------------------------------------------------
# Optional and it asks again with the full plan, so declining is not a failure.
hr; echo " 1/3  clean"
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed yet — nothing to clean."
  CLEANED="n/a (no docker)"
elif ask "clean ?" n; then
  set -- ; [ "$DEEP" = 1 ] && set -- --all ; [ "$YES" = 1 ] && set -- "$@" --yes
  if bash "$ROOT/prerequisites/docker-cleanup.sh" "$@"; then
    CLEANED=done
  else
    CLEANED="not done (declined or failed)"
  fi
fi

# ---- 2. install --------------------------------------------------------------
hr; echo " 2/3  install"
if ask "install ?" y; then
  echo "(sudo will ask for your password)"
  set -- ; [ "$YES" = 1 ] && set -- --yes
  if sudo bash "$ROOT/prerequisites/install-docker.sh" "$@"; then
    INSTALLED=done
  else
    INSTALLED=FAILED; FAILED=1
  fi
fi

# ---- 3. add2path -------------------------------------------------------------
hr; echo " 3/3  add2path"
case "$(basename "${SHELL:-/bin/bash}")" in
  zsh)  RC="$HOME/.zshrc" ;;
  bash) RC="$HOME/.bashrc" ;;
  *)    RC="$HOME/.profile" ;;
esac
if grep -qsF "$ROOT/bin" "$RC"; then
  echo "already on PATH in $RC"
  PATHED="already there"
elif ask "add2path ?  ($ROOT/bin -> $RC)" y; then
  if printf '\n# portable-workstation: the `dev` command\nexport PATH="%s/bin:$PATH"\n' "$ROOT" >> "$RC"; then
    echo "added to $RC"; PATHED=done
  else
    echo "could not write $RC"; PATHED=FAILED; FAILED=1
  fi
fi

# ---- result ------------------------------------------------------------------
hr
printf '  clean      %s\n  install    %s\n  add2path   %s\n' "$CLEANED" "$INSTALLED" "$PATHED"
echo
if [ "$FAILED" != 0 ]; then
  echo "Something above failed — read the output and fix it before continuing."
  exit 1
fi
echo "All good."
echo
# Only a fresh docker group or a fresh PATH line needs a new login session.
if [ "$INSTALLED" = done ] || [ "$PATHED" = done ]; then
  echo "  >>> Log out and log back in. <<<"
  echo
  echo "  Why: the docker group only applies to a new login session, and your shell"
  echo "  reads its rc file at start-up. Until you do, 'docker' says permission"
  echo "  denied and 'dev' is not found."
  echo
  echo "  After logging back in:   cd $ROOT && dev setup"
else
  echo "  Nothing was changed, so there is no need to log out."
  echo "  Next:   cd $ROOT && dev setup"
fi
exit 0
