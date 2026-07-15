# /etc/profile.d/10-workstation.sh — loaded by every login shell (bash -l)
export MISE_DATA_DIR=/opt/mise
export MISE_CACHE_DIR=/opt/caches/mise-cache

# package caches live in one visible place: ${VOL_BASE}/vol-workstation/caches
export COMPOSER_CACHE_DIR=/opt/caches/composer
export npm_config_cache=/opt/caches/npm
export GOMODCACHE=/opt/caches/go-mod
export GOPATH=/opt/caches/gopath
export MAVEN_OPTS="-Dmaven.repo.local=/opt/caches/m2 ${MAVEN_OPTS:-}"
export GRADLE_USER_HOME=/opt/caches/gradle

# ~/.local/bin first → your chosen default `php` wins
# /opt/mise/shims → node/go/java work even in non-interactive shells
export PATH="$HOME/.local/bin:/opt/mise/shims:$GOPATH/bin:$PATH"
