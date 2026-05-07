# Elixir System

Local-first Elixir/OTP system built around independently deployable capabilities.

The local environment mirrors production topology at the service level: PostgreSQL,
Vault-compatible secrets, Prometheus, Grafana, and the app run through Podman.

## Current Status

This repository currently contains the architectural contract, Makefile
entrypoints, local Podman Compose definitions under `infra/local/`, and a minimal
Mix project: the `:es_kernel` OTP application lives under [`kernel/`](kernel/)
and is pulled in from the root [`mix.exs`](mix.exs).

Capability surface and OTP apps beyond the bare kernel shell still need work:

- `capabilities/` directories and capability OTP apps
- `caps.toml` / `caps.lock` (manifest; human/CI edits only)

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

Install Elixir dependencies and compile the umbrella projects:

```bash
make setup
```

Initialize Beads only when setting up the project issue database for the first time:

```bash
bd init
bd setup cursor
```

## Local Services

Compose and supporting config live under:

```text
infra/local/
  compose.yml
  prometheus.yml
  grafana/provisioning/
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
├── mix.exs                 # meta project; depends on kernel via path
├── caps.toml             # (planned) declared capability surface
├── caps.lock             # (planned) frozen production manifest
├── kernel/               # OTP app :es_kernel — shell only for now
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
