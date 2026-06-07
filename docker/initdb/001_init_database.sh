#!/bin/sh
set -eu

for migration in /app/migrations/*.sql; do
  psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --file "$migration"
done

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"   --file /app/seeds/001_development_seed.sql
