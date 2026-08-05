# Use official PostgreSQL image as the base image
FROM postgres:16

# Install additional PostgreSQL extensions and dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-contrib \
        postgresql-16-postgis-3 \
        postgresql-16-cron \
        postgresql-16-partman \
        postgresql-16-pgvector \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN echo "shared_preload_libraries='pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample

# Expose PostgreSQL port
EXPOSE 5432
