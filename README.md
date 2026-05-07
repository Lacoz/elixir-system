# Elixir System

Local-first Elixir/OTP system built around independently deployable capabilities.

The local environment mirrors production topology at the service level: PostgreSQL,
Vault-compatible secrets, Prometheus, Grafana, and the app run through Podman.

## Current Status

This repository currently contains the architectural contract, Makefile
entrypoints, local Podman Compose definitions under `infra/local/`, and a minimal
Mix project: the `:es_kernel` OTP application lives under [`kernel/`](kernel/)
and is pulled in from the root [`mix.exs`](mix.exs).

Kernel modules include `CapabilityStorage`, grant/partition scaffolding, PubSub-backed
`CapabilityBus`, Mix tasks under `mix capabilities.*`, and a dev-only `caps.toml`
watcher. Human maintainers still own `caps.toml` / `caps.lock` edits.

## Prerequisites

Required local tools:

- Git
- Homebrew
- Elixir, Erlang/OTP, and Mix
- Podman with the `podman compose` subcommand
- [ticket](https://github.com/wedow/ticket) CLI: `tk` (install: `brew tap wedow/tools && brew install ticket`)
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

Tickets live under `.tickets/` (git-backed). Install the CLI, then see `tk help`:

```bash
brew tap wedow/tools && brew install ticket   # provides `ticket`; symlink `tk` per upstream README if desired
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

Copy the starter manifest once (maintainers evolve it deliberately; agents never ship
committed `caps.toml` / `caps.lock`):

```bash
cp caps.toml.example caps.toml
```

Run database migrations locally (PostgreSQL must be reachable via `DATABASE_URL`):

```bash
mix setup
```

Wire `DATABASE_URL`, then start dependencies and the supervision tree:

```bash
make dev
```

Run the regression suite plus manifest/diff guards:

```bash
make check
```

Run-only compile/tests without infra:

```bash
mix compile
CAPS_MANIFEST_PATH=caps.toml.example mix capabilities.check
mix test
```

Interactive console against the umbrella:

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
├── caps.toml.example       # starter manifest (copy locally to caps.toml)
├── caps.toml / caps.lock   # real manifests (maintainer-authored, usually gitignored)
├── kernel/                 # OTP app :es_kernel — registry, grants, storage API, Mix tasks
├── capabilities/
├── config/
├── .tickets/               # markdown tickets ([ticket](https://github.com/wedow/ticket))
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

Check ticket CLI:

```bash
tk ready
# or: ticket ready
```

Check local service containers:

```bash
podman ps
```
