# syntax=docker/dockerfile:1
# ============================================================
# workstation — one container that feels like your local machine
#   PHP 7.2 → 8.4 side by side (Sury PPA)       php7.2 … php8.4, composer7.2 …
#   node / go / java / kotlin / rust / ruby / python / flutter via mise
#                                                auto-switch per project
#   R (CRAN) · Android SDK + adb · FrankenPHP · headless Chromium (Playwright)
#   Docker CLI · Claude Code
# Rebuild after editing:  dev rebuild
# ============================================================
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USER_UID=1000
ARG USER_GID=1000
ARG PHP_VERSIONS="7.2 7.4 8.0 8.1 8.2 8.3 8.4"

# ---- base tools (feels like a real machine) -----------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git unzip zip sudo gnupg lsb-release \
    software-properties-common build-essential pkg-config \
    vim nano less htop tree jq ripgrep \
    openssh-client iputils-ping dnsutils netcat-openbsd rsync \
    mysql-client postgresql-client redis-tools sqlite3 \
    python3 python3-venv python3-pip \
    # libs so `mise install python@x` also works if you ever want it
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libffi-dev liblzma-dev libncursesw5-dev xz-utils tk-dev \
    locales && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ---- Docker CLI (talks to the host daemon via /var/run/docker.sock) ----
# ---- Claude Code CLI (official apt repo, stable channel) --------------
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list && \
    curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o /etc/apt/keyrings/claude-code.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
      > /etc/apt/sources.list.d/claude-code.list && \
    apt-get update && apt-get install -y --no-install-recommends \
      docker-ce-cli docker-compose-plugin docker-buildx-plugin claude-code && \
    rm -rf /var/lib/apt/lists/*

# ---- PHP: every version side by side ------------------------
RUN add-apt-repository -y ppa:ondrej/php && apt-get update && \
    for v in ${PHP_VERSIONS}; do \
      apt-get install -y --no-install-recommends \
        php${v}-cli php${v}-readline php${v}-mbstring php${v}-xml \
        php${v}-curl php${v}-zip php${v}-gd php${v}-intl php${v}-bcmath \
        php${v}-mysql php${v}-pgsql php${v}-sqlite3 php${v}-redis \
        || echo "!! php${v} not available, skipping"; \
    done && rm -rf /var/lib/apt/lists/*

# ---- composer (one binary, works with any PHP) ---------------
RUN curl -fsSL https://getcomposer.org/installer -o /tmp/ci.php && \
    php /tmp/ci.php --install-dir=/usr/local/bin --filename=composer && \
    rm /tmp/ci.php && \
    # per-version shims: composer7.2 ... composer8.4
    for v in ${PHP_VERSIONS}; do \
      if [ -x /usr/bin/php${v} ]; then \
        printf '#!/bin/sh\nexec /usr/bin/php%s /usr/local/bin/composer "$@"\n' "$v" \
          > /usr/local/bin/composer${v} && chmod +x /usr/local/bin/composer${v}; \
      fi; \
    done

# ---- Octane extras: opcache + swoole per version --------------
# opcache isn't guaranteed under --no-install-recommends, and Octane
# without opcache.enable_cli=1 loses most of its speed advantage.
# swoole is guarded per version (the PPA only builds it for PHP 8.x).
RUN apt-get update && \
    for v in ${PHP_VERSIONS}; do \
      if [ -x /usr/bin/php${v} ]; then \
        apt-get install -y --no-install-recommends php${v}-opcache \
          || echo "!! php${v}-opcache not available, skipping"; \
        apt-get install -y --no-install-recommends php${v}-swoole \
          || echo "!! php${v}-swoole not available, skipping"; \
        if [ -d /etc/php/${v}/cli/conf.d ]; then \
          printf 'opcache.enable_cli=1\n' > /etc/php/${v}/cli/conf.d/99-octane.ini; \
        fi; \
      fi; \
    done && rm -rf /var/lib/apt/lists/*

# ---- FrankenPHP (primary Octane runtime) -----------------------
# Static binary: embeds its own PHP, so the apt-installed PHPs above
# are untouched. Asset names: frankenphp-linux-x86_64 / -aarch64.
RUN curl -fsSL "https://github.com/php/frankenphp/releases/latest/download/frankenphp-linux-$(uname -m)" \
      -o /usr/local/bin/frankenphp && \
    chmod +x /usr/local/bin/frankenphp && \
    /usr/local/bin/frankenphp version

# ---- headless Chromium: OS libraries only ---------------------
# Playwright's own installer knows the exact apt list for this Ubuntu.
# The browser binaries are downloaded once at first start by
# runtime-bootstrap into /opt/caches/ms-playwright (a persistent volume),
# so every project (Node, PHP, Python) shares one Chromium.
RUN python3 -m venv /tmp/pw && /tmp/pw/bin/pip install -q playwright && \
    /tmp/pw/bin/playwright install-deps chromium && \
    rm -rf /tmp/pw /var/lib/apt/lists/*

# ---- mise (node / go / java / kotlin / maven / gradle / rust / ruby / python / flutter / lazydocker)
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh
COPY mise-config.toml /etc/mise/config.toml

# ---- R (CRAN, current release) + build libs for Ruby, R packages, Flutter ----
# Ruby is compiled by mise at first start (needs libyaml + gmp). R packages
# compile against the usual curl/xml2/fontconfig/harfbuzz/freetype/png/tiff/
# jpeg dev libs (tidyverse & co). `file` and libglu1-mesa keep `flutter doctor`
# and the Android tooling quiet. Non-interactive install.packages() needs a
# mirror preset; the user library goes to the persistent cache (R_LIBS_USER).
# postgresql-16 is the *server* (initdb, pg_ctl, postgres): test suites that spin up a
# throwaway cluster need it locally — the postgres-16 service is a different thing.
# libpq-dev only for /usr/bin/pg_config: postgresql-client-16 ships pg_config inside
# /usr/lib/postgresql/16/bin, which is not on PATH (psql is a pg_wrapper symlink, it is not).
# Costs libllvm17t64 (~120 MB, postgres JIT). Kept in this late layer so PHP/Chromium stay cached.
RUN curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc -o /etc/apt/keyrings/cran.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/cran.asc] https://cloud.r-project.org/bin/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME")-cran40/" \
      > /etc/apt/sources.list.d/cran.list && \
    apt-get update && apt-get install -y --no-install-recommends \
      libyaml-dev libgmp-dev \
      postgresql-16 libpq-dev \
      r-base r-base-dev \
      libcurl4-openssl-dev libxml2-dev libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
      libfreetype-dev libpng-dev libtiff-dev libjpeg-dev \
      file libglu1-mesa && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /etc/R && \
    printf '\noptions(repos = c(CRAN = "https://cloud.r-project.org"))\n' >> /etc/R/Rprofile.site

# ---- dev user (uid/gid match your host user) ------------------
RUN userdel -r ubuntu 2>/dev/null || true; \
    groupadd -g ${USER_GID} dev 2>/dev/null || true; \
    useradd -m -s /bin/bash -u ${USER_UID} -g ${USER_GID} dev && \
    echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev

# ---- workstation scripts & shell setup ------------------------
COPY profile.d-workstation.sh /etc/profile.d/10-workstation.sh
COPY bashrc.seed /etc/workstation/bashrc.seed
COPY php-default runtime-bootstrap android-sdk-setup adb-emu chromium entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/php-default /usr/local/bin/runtime-bootstrap \
             /usr/local/bin/android-sdk-setup /usr/local/bin/adb-emu /usr/local/bin/chromium \
             /usr/local/bin/entrypoint.sh

# persistent dirs (bind-mounted from ./volumes/vol-workstation)
RUN mkdir -p /projects /opt/mise /opt/caches && \
    chown dev:dev /projects /opt/mise /opt/caches

# Everything that doesn't need root is visible to non-login shells too
# (VS Code's extension host, `docker exec`, cron-like runners).
# Keep in sync with profile.d-workstation.sh.
ENV MISE_DATA_DIR=/opt/mise \
    MISE_CACHE_DIR=/opt/caches/mise-cache \
    PLAYWRIGHT_BROWSERS_PATH=/opt/caches/ms-playwright \
    CHROME_BIN=/usr/local/bin/chromium \
    CHROME_PATH=/usr/local/bin/chromium \
    CHROME_EXECUTABLE=/usr/local/bin/chromium \
    ANDROID_HOME=/opt/caches/android-sdk \
    ANDROID_SDK_ROOT=/opt/caches/android-sdk \
    PUB_CACHE=/opt/caches/pub \
    R_LIBS_USER=/opt/caches/R \
    COREPACK_HOME=/opt/caches/corepack \
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    PATH=/home/dev/.local/bin:/opt/mise/shims:/home/dev/.cargo/bin:/opt/caches/android-sdk/cmdline-tools/latest/bin:/opt/caches/android-sdk/platform-tools:/opt/caches/gopath/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Default user is `dev`: `docker exec`, VS Code attach and `dev` all land
# as you, never root. The entrypoint uses sudo for the few root-only steps.
USER dev
WORKDIR /projects
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
