# Inferno Resources Keeper

A small Ruby REST API (Sinatra + Sequel + PostgreSQL) for storing expiring, session-scoped JSON resources, with create-or-update (upsert) semantics and bulk session expiry.

A resource is identified by the triple `(sessionId, resourceType, resourceId)`. Posting to the same triple again updates it in place and refreshes its expiry; resources stop being served once expired, and an entire session can be expired in one call.

## Requirements

- Ruby 3.3
- PostgreSQL (with the `pgcrypto` extension)
- Docker and Docker Compose (only if you want the containerized path)

## Quick start (Docker)

The fastest way to run the whole stack — app and database — is Docker Compose:

```sh
docker compose up --build
```

This builds the app image, starts Postgres (enabling `pgcrypto` on first boot), runs pending migrations automatically, and serves the API at `http://localhost:4567`. Data persists in a named volume across restarts.

## Local setup

1. Create the database and enable the required extension:

   ```sh
   createdb resource_api_dev
   psql resource_api_dev -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
   ```

2. Copy the example environment file and adjust it if needed:

   ```sh
   cp .example.env .env
   ```

3. Install dependencies:

   ```sh
   bundle install
   ```

4. Run migrations:

   ```sh
   bundle exec rake db:migrate
   ```

5. Start the server:

   ```sh
   bundle exec puma config.ru -p 4567
   ```

## Configuration

Settings are read from the environment (`.env` locally, via `dotenv`). See [.example.env](.example.env) for the template.

| Variable        | Required | Default | Description                                                                 |
| --------------- | -------- | ------- | ----------------------------------------------------------------------------- |
| `DATABASE_URL`  | yes      | —       | Postgres connection string, e.g. `postgres://user:password@localhost:5432/resource_api_dev` |
| `EXPIRATION_MS` | no       | `604800000` (7 days) | How long, in milliseconds, a resource stays valid after being created or updated |

## API reference

All responses are JSON. Timestamps (`createdAt`, `updatedAt`, `expiredAt`) are server-generated.

### `POST /resources`

Creates a resource, or updates it if one already exists for the same `(sessionId, resourceType, resourceId)` — refreshing its content and expiry either way.

```sh
curl -X POST http://localhost:4567/resources \
  -H "Content-Type: application/json" \
  -d '{
        "sessionId": "s1",
        "resourceType": "patient",
        "resourceId": "p1",
        "resource": { "name": "Alice" }
      }'
```

- `201 Created` — a new resource was created.
- `200 OK` — an existing resource was updated.
- `422 Unprocessable Content` — a required field (`sessionId`, `resourceType`, `resourceId`, or `resource`) is missing.

Response body:

```json
{
  "id": "8c788f58-0efc-429b-b2ce-0c213f1ad001",
  "sessionId": "s1",
  "resourceType": "patient",
  "resourceId": "p1",
  "resource": { "name": "Alice" },
  "createdAt": "2026-08-19 11:49:32 +0400",
  "updatedAt": "2026-08-19 11:49:32 +0400",
  "expiredAt": "2026-08-26 11:49:32 +0400"
}
```

### `GET /:sessionId/:resourceType/:resourceId`

Returns the resource if it exists and hasn't expired.

```sh
curl http://localhost:4567/s1/patient/p1
```

- `200 OK` — resource found.
- `404 Not Found` — resource doesn't exist, or has expired.

### `DELETE /sessions/:sessionId`

Expires every non-expired resource belonging to a session in one call.

```sh
curl -X DELETE http://localhost:4567/sessions/s1
```

Always returns `200 OK`, even for an unknown session:

```json
{ "sessionId": "s1", "expiredCount": 3 }
```

## Testing

```sh
bundle exec rspec
```

Coverage is enforced at 100% (line and branch) via SimpleCov — the suite fails if coverage drops below that. An HTML report is written to `coverage/index.html`. Tests run against a real Postgres database (`DATABASE_URL` from the environment); the schema is migrated automatically when the suite loads.

## Linting

```sh
bundle exec rubocop
```

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`) runs on every push, to every branch:

- **rubocop** — style/lint checks.
- **rspec** — the test suite against a Postgres service container, with 100% coverage enforced.

A third job, **docker-publish**, runs only after both checks pass, and only in two cases:

- **Push to `main`** — builds and pushes the image to `ghcr.io/projkov/inferno_resources_keeper`, tagged with the short commit SHA.
- **New GitHub release** — builds and pushes the same image, tagged with the release's version (its tag name).

Pull the latest image built from `main`:

```sh
docker pull ghcr.io/projkov/inferno_resources_keeper:<commit-sha>
```

## Project structure

```
.
├── app.rb                       # Sinatra app: routes and request handling
├── config.ru                    # Rack entry point
├── models/resource.rb           # Sequel model
├── db/migrations/               # Schema migrations
├── db/init/                     # Postgres bootstrap SQL (Docker only)
├── spec/                        # RSpec test suite
├── Dockerfile, docker-compose.yml, docker-entrypoint.sh
└── .github/workflows/ci.yml     # Lint, test, and publish pipeline
```
