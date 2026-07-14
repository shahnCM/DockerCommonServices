# ============================================================
# workstation — one container that feels like your local machine
#   PHP 7.2 → 8.4 side-by-side (Sury PPA, apt)  → php7.2, php8.3 ...
#   node / go / java / maven / gradle via mise   → auto-switch per project
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

# ---- mise (node / go / java / maven / gradle version manager) -
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh
COPY mise-config.toml /etc/mise/config.toml

# ---- dev user (uid/gid match your host user) ------------------
RUN userdel -r ubuntu 2>/dev/null || true; \
    groupadd -g ${USER_GID} dev 2>/dev/null || true; \
    useradd -m -s /bin/bash -u ${USER_UID} -g ${USER_GID} dev && \
    echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev

# ---- workstation scripts & shell setup ------------------------
COPY profile.d-workstation.sh /etc/profile.d/10-workstation.sh
COPY bashrc.seed /etc/workstation/bashrc.seed
COPY php-default runtime-bootstrap /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/php-default /usr/local/bin/runtime-bootstrap \
             /usr/local/bin/entrypoint.sh

# persistent dirs (bind-mounted from ${VOL_BASE}/vol-workstation)
RUN mkdir -p /projects /opt/mise /opt/caches && \
    chown dev:dev /projects /opt/mise /opt/caches

WORKDIR /projects
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
