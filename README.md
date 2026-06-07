# Postgres Finansas Personales

Esquema PostgreSQL para persistir los datos de finanzas personales descritos en `postgres_data_spec.md`.

## Archivos

- `migrations/001_initial_schema.sql`: extensión `pgcrypto`, tablas, restricciones, índices y triggers `updated_at`.
- `migrations/010_user_password_reset_outbox.sql`: outbox de emails de recuperacion de contrasena.
- `seeds/001_development_seed.sql`: usuario demo, categorías, presupuestos y transacciones de desarrollo.
- `queries/dashboard_progress.sql`: consulta de progreso mensual por categoría.
- `docker-compose.yml`: servicio PostgreSQL local listo para desarrollo.

## Ejecución local

```sh
cp .env.example .env
docker compose up -d
```

La semilla crea el usuario `demo@finanzas.local` y datos para el mes `2026-06-01`.

## Conexión

Valores por defecto:

```text
host: localhost
port: 5432
database: postgres_finansas_personales
user: finanzas_user
password: finanzas_password
```

`DATABASE_URL` equivalente:

```text
postgresql://finanzas_user:finanzas_password@localhost:5432/postgres_finansas_personales
```

## Recuperacion de contrasena

Si la API no tiene SMTP configurado, los correos temporales quedan en la tabla `password_reset_emails` para desarrollo local.

```sh
docker compose exec postgres psql -U finanzas_user -d postgres_finansas_personales -c "SELECT email, subject, body, status, created_at FROM password_reset_emails ORDER BY created_at DESC LIMIT 5;"
```

## Verificación

```sh
docker compose ps
docker compose exec postgres psql -U finanzas_user -d postgres_finansas_personales -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
```

## Reiniciar desde cero

Esto elimina el volumen local de datos y vuelve a ejecutar migraciones y semillas al levantar.

```sh
docker compose down -v
docker compose up -d
```
