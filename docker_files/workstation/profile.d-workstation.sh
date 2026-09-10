# /etc/profile.d/10-workstation.sh — loaded by every login shell (bash -l)
# Keep in sync with the ENV block in the Dockerfile (non-login processes).
export MISE_DATA_DIR=/opt/mise
export MISE_CACHE_DIR=/opt/caches/mise-cache

# package caches live in one visible place: ./volumes/vol-workstation/caches
export COMPOSER_CACHE_DIR=/opt/caches/composer
export npm_config_cache=/opt/caches/npm
export GOMODCACHE=/opt/caches/go-mod
export GOPATH=/opt/caches/gopath
export MAVEN_OPTS="-Dmaven.repo.local=/opt/caches/m2 ${MAVEN_OPTS:-}"
export GRADLE_USER_HOME=/opt/caches/gradle
export PUB_CACHE=/opt/caches/pub            # dart / flutter packages
export R_LIBS_USER=/opt/caches/R            # R install.packages() target

# Android SDK: cmdline-tools + platform-tools (adb), installed by android-sdk-setup
export ANDROID_HOME=/opt/caches/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME

# one shared headless Chromium for every project (Node, PHP, Python, Flutter web)
export PLAYWRIGHT_BROWSERS_PATH=/opt/caches/ms-playwright
export CHROME_BIN=/usr/local/bin/chromium
export CHROME_PATH=/usr/local/bin/chromium
export CHROME_EXECUTABLE=/usr/local/bin/chromium

# ~/.local/bin first → your chosen default `php` wins
# /opt/mise/shims → node/go/java/… work even in non-interactive shells
# ~/.cargo/bin → `cargo install`ed binaries
export PATH="$HOME/.local/bin:/opt/mise/shims:$HOME/.cargo/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$GOPATH/bin:$PATH"
