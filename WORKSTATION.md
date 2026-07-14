# Workstation add-on for DcokerCommonServices

Everything from our build session, consolidated into one drop-in package: a single always-on
container with every PHP/Node/Go/Java version installed (feels like your local machine), plus
MySQL 8, MySQL 5.7, and phpMyAdmin added to your existing services (mongodb, postgres, redis, etc).

**This replaces the two earlier zips (`workstation-addon.zip`, `demo-apps.zip`) — this one has everything.**

## What's in here

```
docker_files/workstation/   Dockerfile + scripts for the workstation image
services/
  workstation.yml            the workstation container itself
  mysql-8.yml                MySQL 8   → localhost:3306
  mysql-5.yml                MySQL 5.7 → localhost:3307
  phpmyadmin.yml              browse both  → localhost:8880
bin/dev                      shell helper — enter the workstation from any project folder
projects/
  php-mysql-redis-demo/      tested example: PHP + MySQL + Redis
  node-redis-demo/           tested example: Node + Redis (shares state with the PHP one)
env.workstation.example       vars to append to your .env
```

## Install (once)

1. Unzip this into your repo root (paths match exactly — `services/`, `docker_files/`, `bin/`, `projects/`).
2. `chmod +x bin/dev`
3. Append `env.workstation.example` to your `.env` (set `USER_UID`/`USER_GID` to your `id -u`/`id -g`).
4. `go run generate-compose.go && docker compose up -d --build`
5. Add `bin/` to your `PATH` (e.g. `echo 'export PATH="$PWD/bin:$PATH"' >> ~/.bashrc`).

First build: ~5–10 min. PHP works immediately; Node/Go/Java finish installing in the background
(`bin/dev logs` to watch). `?servicename.yml` disables anything you don't want, same as always —
e.g. rename to `?mysql-5.yml` if you only need MySQL 8.

## Daily use

```
cd projects/legacy-app && dev                          # shell opens *in that folder*, in the container
php7.2 artisan serve --host=0.0.0.0 --port=8072         # → localhost:8072
```
Another tab, another project, same container:
```
cd projects/frontend && dev
npm run dev -- --host                                    # mise auto-picks that project's node version
```

| you want | you type |
|---|---|
| shell / run one command | `dev` / `dev composer install` |
| pick a PHP explicitly | `php7.4 script.php`, `composer7.2 install` |
| change default `php` | `php-default 8.1` (persists across rebuilds) |
| pin a runtime per project | in project dir: `mise use node@18` |
| list installed PHPs / runtimes | `phpv` / `mise ls` |

## Databases & phpMyAdmin

Two MySQL versions run side by side so old and new projects both have a home:

| service | hostname (from workstation) | host port | use for |
|---|---|---|---|
| `mysql-8` | `mysql-8` | `localhost:3306` | current projects |
| `mysql-5` | `mysql-5` | `localhost:3307` | legacy apps (pairs naturally with `php7.2`) |
| `redis-7` | `redis-7` | `localhost:6379` | caching/sessions, no password currently set |

**phpMyAdmin** → `http://localhost:8880`. The login screen shows a server dropdown —
pick **MySQL 8** or **MySQL 5** — then log in with `dev_user` / `dev_password` (or
`root` / whatever `DB_MYSQL_ROOT_PASSWORD` is in your `.env`).

From inside the workstation, PHP connects the same way regardless of version:
```php
new PDO("mysql:host=mysql-8;dbname=app", "dev_user", "dev_password");   // or host=mysql-5
```

One thing to flag honestly: `mysql:5.7` is an old image — most failures-to-start on modern
hosts are just resource/config issues visible in `docker compose logs mysql-5`, but if it
won't come up on your machine, `mariadb:10.6` is a wire-compatible drop-in replacement.

## The tested example (PHP + Node sharing MySQL & Redis)

`php-mysql-redis-demo/visit.php` logs each run to MySQL and counts hits in Redis:
```
cd projects/php-mysql-redis-demo && dev
php8.1 visit.php
```
`node-redis-demo/` is a tiny server hitting the *same* Redis counter — proof both runtimes
share the network:
```
cd projects/node-redis-demo && dev
npm install && npm start        # then curl localhost:3000 from another tab
```

## Persistence — "nothing goes unnoticed"

Everything stateful lives under `volumes/`, visible and inspectable, same as your other services:

```
volumes/vol-workstation/home/     dotfiles, shell history, your `php-default` choice
volumes/vol-workstation/mise/     installed node/go/java versions
volumes/vol-workstation/caches/   composer, npm, go-mod, m2, gradle
volumes/vol-mysql-8/data/
volumes/vol-mysql-5/data/
```
Rebuilding the workstation image (`dev rebuild`) loses none of this — only packages installed
ad-hoc with `sudo apt` inside the container are ephemeral; bake those into the Dockerfile instead.
