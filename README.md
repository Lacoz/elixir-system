# Elixir System

Local-first Elixir/OTP system built around independently deployable capabilities.

The local environment mirrors production topology at the service level: PostgreSQL,
Vault-compatible secrets, Prometheus, Grafana, and the app run through Podman.

## Current Status

This repository currently contains the architectural contract and local setup
entrypoints. The application scaffold still needs to be created:

- root `mix.exs`
- `kernel/`
- `capabilities/`
- `config/`
- `infra/local/compose.yml`

## Prerequisites

Required local tools:

- Git
- Homebrew
- Elixir, Erlang/OTP, and Mix
- Podman with the `podman compose` subcommand
- Beads CLI: `bd`
- OpenTofu: `tofu`

Useful local CLIs:

- PostgreSQL client: `psql`
- Vault CLI: `vault`

Check your machine:

```bash
make doctor
```

Install missing tools with Homebrew:

```bash
make install-tools
```

Show installed versions:

```bash
make versions
```

## First-Time Setup

Run the local prerequisite check first:

```bash
make doctor
```

Install missing tools if needed:

```bash
make install-tools
make doctor
```

Once the Elixir project scaffold exists, install dependencies and run migrations:

```bash
make setup
```

Initialize Beads only when setting up the project issue database for the first time:

```bash
bd init
bd setup cursor
```

## Local Services

Local services should live in:

```text
infra/local/compose.yml
```

Expected local endpoints:

- App: `http://localhost:4000`
- PostgreSQL: `localhost:5432`
- Vault: `http://localhost:8200`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

Default local environment:

```bash
DATABASE_URL=postgres://app:app@localhost:5432/app_dev
VAULT_ADDR=http://localhost:8200
VAULT_TOKEN=dev-root-token
CAPABILITY_ENV=dev
```

Start the local stack:

```bash
make dev
```

Stop and remove local volumes:

```bash
make dev-down
```

## Daily Development

Typical loop after the scaffold exists:

```bash
make dev
make test
```

Run the local verification suite:

```bash
make check
```

Run the app:

```bash
iex -S mix
```

## Repository Layout

```text
/
├── AGENTS.md
├── README.md
├── Makefile
├── mix.exs
├── caps.toml
├── caps.lock
├── kernel/
├── capabilities/
├── config/
├── test/
└── infra/
    └── local/
        ├── compose.yml
        ├── prometheus.yml
        └── grafana/
```

## Capability Rules

Capabilities live under `capabilities/<name>_cap/`.

Do not put business logic in `kernel/`. Do not create a root-level `lib/`.
Cross-capability communication goes through kernel APIs, not direct module calls.

## Troubleshooting

Check Podman:

```bash
podman info
podman machine list
```

Start a Podman VM on macOS if needed:

```bash
podman machine init
podman machine start
```

Check Beads:

```bash
bd --version
bd ready
```

Check local service containers:

```bash
podman ps
```
