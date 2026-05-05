# AGENTS.md — Architectural Contract

> This document is the single source of truth for all development decisions.
> It is immutable by default. Changes require an explicit Beads issue with
> `type: arch-change` and approval from a human maintainer.
> Agents MUST read this file before any action in this repository.

---

## 0. Core Philosophy

This system is designed to last **years**, not sprints. Every decision must
answer three questions simultaneously:

1. Can this be **added** without touching the kernel?
2. Can this be **changed** without breaking other capabilities?
3. Can this be **removed** without leaving orphaned code, data, or intent?

If the answer to any of the three is "no" — the design is wrong.
Refactor before proceeding.

---

## 1. Repository Structure

```
/
├── AGENTS.md                  ← you are here (immutable contract)
├── caps.toml                  ← declared capability surface (editable via Beads only)
├── caps.lock                  ← frozen production state (generated, never hand-edited)
├── kernel/                    ← immutable core, no business logic
│   ├── lib/
│   │   ├── capability_supervisor.ex
│   │   ├── capability_registry.ex
│   │   ├── capability_watcher.ex         ← dev-only file watcher
│   │   ├── storage_api.ex
│   │   ├── tenant_capability_registry.ex ← which tenant has what active
│   │   ├── tenant_capability_guard.ex    ← plug: enforces per-request access
│   │   └── tenant_provisioner.ex         ← creates/archives tenant schemas
│   └── mix.exs
├── capabilities/              ← one directory per capability
│   └── <name>_cap/
│       ├── lib/
│       │   ├── <name>_cap/application.ex
│       │   ├── <name>_cap/supervisor.ex
│       │   └── <name>_cap/*.ex
│       ├── priv/migrations/   ← Ecto migrations scoped to this capability
│       ├── test/
│       └── mix.exs
├── .beads/                    ← Beads DB (gitignored)
└── .github/
    └── workflows/
        └── release.yml        ← runs mix capabilities.freeze before mix release
```

**Rules:**
- Never place business logic in `kernel/`.
- Never create files outside `capabilities/<name>_cap/` for capability code.
- Never create a shared `lib/` at root level. Cross-capability communication
  goes through the kernel's `CapabilityRegistry`, not direct module calls.

---

## 2. Capability Lifecycle

A capability is the **unit of functionality**. It maps 1:1 to an OTP Application.

### 2.1 States

```
absent → active → deprecated → absent
              ↑                    ↓
              └────────────────────┘
                  (reactivation via new issue)
```

| State        | In caps.toml | In caps.lock | OTP started | Code in prod binary |
|--------------|:---:|:---:|:---:|:---:|
| `absent`     | ✗   | ✗   | ✗   | ✗   |
| `active`     | ✓   | ✓   | ✓   | ✓   |
| `deprecated` | ✓*  | ✓*  | ✓   | ✓   |
| `removed`    | ✗   | ✗   | ✗   | ✗   |

*Marked with `deprecated = true` in caps.toml. Deprecated capabilities accept
no new data — they serve read-only for migration purposes.

### 2.2 Adding a Capability

**Step 1 — Intent (Beads):**
```bash
bd create "add <name> capability" --type cap-add
bd update bd-<hash> --meta '{"cap": "<name>_cap", "version": "0.1.0"}'
```
The issue is the record of *why* this capability exists. Never skip this step.

**Step 2 — Scaffold:**
```bash
mix capability.new <name>
# generates capabilities/<name>_cap/ with required structure
```

**Step 3 — Declare in caps.toml:**
```toml
[[capability]]
name    = "<name>_cap"
version = "0.1.0"
beads   = "bd-<hash>"   # links capability to its origin issue
status  = "active"
```

**Step 4 — Storage migration:**
```elixir
# capabilities/<name>_cap/priv/migrations/<timestamp>_create_<name>_namespace.exs
defmodule NameCap.Repo.Migrations.CreateNamespace do
  use Ecto.Migration

  @namespace "<name>"   # MUST match capability name exactly

  def up do
    CapabilityStorage.create_namespace(@namespace)
    # then create tables using prefixed names: "<name>_<table>"
    create table(:"#{@namespace}_items") do
      add :id, :binary_id, primary_key: true
      # ...
      timestamps()
    end
  end

  def down do
    CapabilityStorage.archive_namespace(@namespace)
  end
end
```

**Step 5 — Close Beads issue only after migration runs in CI:**
```bash
bd close bd-<hash> --note "deployed in caps.lock sha:<git_sha>"
```

### 2.3 Modifying a Capability

Every modification requires a Beads issue:
```bash
bd create "change <name>: <what and why>" --type cap-change
```

**Semver rules (enforced by `mix capabilities.check` in CI):**

| Change type                          | Version bump |
|--------------------------------------|:---:|
| Add optional field / new command     | patch |
| Add required field / change response shape | minor |
| Remove command / change command name | **major** |
| Change storage schema in breaking way | **major** |

A major bump MUST include a migration and a deprecation period of ≥ 1 sprint
before the old interface is removed.

### 2.4 Removing a Capability

Removal is a **two-step process across two releases**:

**Release N — Deprecate:**
```toml
[[capability]]
name       = "<name>_cap"
version    = "2.3.1"
status     = "deprecated"
removed_in = "next"
beads      = "bd-<hash>"
```

**Release N+1 — Remove:**
```bash
# 1. Remove from caps.toml entirely
# 2. Run: mix capability.remove <name>
#    This iterates all active tenants, archives their <name>_* tables,
#    verifies no dependents, then removes the OTP app from the build
# 3. Commit with message: "cap(remove): <name>_cap [bd-<hash>]"
```

The capability tables are **archived per-tenant schema, not deleted** for 90 days.
`mix capability.purge <name>` permanently drops them after the retention period
across all tenant schemas simultaneously.

---

## 3. Kernel Rules

The kernel is **frozen**. Its public API surface is:

```elixir
# Starting/stopping (used by CapabilityWatcher in dev, CapabilitySupervisor in prod)
CapabilityRegistry.start_capability(name :: atom) :: :ok | {:error, term}
CapabilityRegistry.stop_capability(name :: atom) :: :ok | {:error, :has_dependents}
CapabilityRegistry.active_capabilities() :: [atom]

# Storage — always tenant-scoped in production (capabilities MUST use this, never raw Ecto)
CapabilityStorage.repo(cap_name :: atom, tenant_id :: String.t()) :: Ecto.Repo.t()
CapabilityStorage.namespace(cap_name :: atom) :: String.t()
# Returns the Ecto prefix for this tenant: "tenant_<id>"
CapabilityStorage.prefix(tenant_id :: String.t()) :: String.t()

# Tenant capability registry
TenantCapabilityRegistry.active_for(tenant_id :: String.t()) :: [atom]
TenantCapabilityRegistry.activate(tenant_id :: String.t(), cap :: atom, opts :: keyword) :: :ok | {:error, :not_in_caps_lock}
TenantCapabilityRegistry.deactivate(tenant_id :: String.t(), cap :: atom) :: :ok
TenantCapabilityRegistry.capable?(tenant_id :: String.t(), cap :: atom) :: boolean

# Tenant provisioning (creates / archives PostgreSQL schema for tenant)
TenantProvisioner.provision(tenant_id :: String.t(), capabilities :: [atom]) :: :ok
TenantProvisioner.deprovision(tenant_id :: String.t()) :: :ok | {:error, :has_active_data}

# Cross-capability messaging (no direct module calls between capabilities)
CapabilityBus.emit(cap_name :: atom, event :: atom, payload :: map, tenant_id :: String.t()) :: :ok
CapabilityBus.subscribe(cap_name :: atom, event :: atom) :: :ok
```

**What the kernel MUST NOT contain:**
- HTTP handlers
- Business logic of any kind
- Domain schemas
- Direct database queries
- Any `import` of a capability module

If you are about to add something to the kernel that is not in the list above,
stop and create a Beads issue with `type: arch-change`.

---

## 4. Storage Rules

### 4.1 Namespace isolation

Storage has **two dimensions**: capability namespace and tenant schema.
These are orthogonal — never conflate them.

```
PostgreSQL schema:  tenant_<tenant_id>          ← tenant isolation (row of the matrix)
Table prefix:       <capability_name>_<table>   ← capability isolation (column of the matrix)

Full address:  tenant_abc.billing_invoices
               └─────────┘ └─────────────┘
               tenant schema  cap namespace
```

Every capability owns exactly one table prefix: the capability name without `_cap`.
Example: `billing_cap` owns prefix `billing_` within whatever tenant schema is active.

**Never** create a table without the capability prefix.
**Never** `JOIN` across capability prefixes directly — use `CapabilityBus` events or
define a read-only projection in the consuming capability's own tables.
**Never** `JOIN` across tenant schemas — this is a hard isolation boundary.

Table naming convention (within a tenant schema):
```
billing_invoices
billing_line_items
billing_payment_methods
```

### 4.2 Migrations

- Migrations live in `capabilities/<name>_cap/priv/migrations/`
- Run per-capability across all tenant schemas: `mix capabilities.migrate <name>`
- Each migration must implement both `up` and `down`
- Migrations are tenant-schema-agnostic — they define tables, not schemas
- `TenantProvisioner.provision/2` runs pending migrations for a tenant at onboarding
- `down` for the initial migration must call `CapabilityStorage.archive_namespace/2`

Migration template:
```elixir
defmodule BillingCap.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  # No schema/prefix here — the migration runner applies it per tenant
  def up do
    create table(:billing_invoices, primary_key: false) do
      add :id,          :binary_id, primary_key: true
      add :tenant_id,   :string,    null: false  # denormalized for audit queries
      add :amount,      :decimal,   null: false
      timestamps()
    end
  end

  def down do
    drop table(:billing_invoices)
  end
end
```

### 4.3 Dev vs Prod

| Environment | Storage backend |
|-------------|----------------|
| dev / test  | PostgreSQL, namespaces created on `Application.start` |
| prod        | PostgreSQL, namespaces created during CI migration step |

Never use ETS as primary storage. ETS is allowed for ephemeral caches within
a capability's own supervisor subtree only.

---

## 5. caps.toml — The Contract

`caps.toml` is the **declared surface area** of this system instance.
It is the only file an agent or operator needs to read to understand
what the system currently does.

```toml
# Schema version of this file format
schema = "1"

# Minimum kernel version required
kernel_min = "1.0.0"

[[capability]]
name       = "issues_cap"       # must match OTP application name
version    = "1.4.2"            # semver, enforced by CI
status     = "active"           # active | deprecated | (absent = not listed)
beads      = "bd-a1b2"          # origin Beads issue
requires   = []                 # other capability names this depends on
deprecated = false

[[capability]]
name       = "billing_cap"
version    = "0.3.0"
status     = "active"
beads      = "bd-c3d4"
requires   = ["auth_cap"]       # CapabilityRegistry enforces this at start
deprecated = false
```

**Rules:**
- Only humans and CI may edit `caps.toml`.
- Agents may READ `caps.toml` to understand current surface.
- Agents must NEVER write to `caps.toml` directly.
  All manifest changes go through a Beads issue → human review → commit.

---

## 6. caps.lock — Audit Trail

`caps.lock` is generated by `mix capabilities.freeze` during CI.
It is committed to git. Never hand-edit it.

```toml
[meta]
frozen_at  = "2026-05-05T10:23:00Z"
built_by   = "ci/release#4471"
git_sha    = "a3f8b2c"
git_branch = "main"

[[capability]]
name    = "issues_cap"
version = "1.4.2"
hash    = "sha256:a3f8..."
beads   = "bd-a1b2"

[[capability]]
name    = "billing_cap"
version = "0.3.0"
hash    = "sha256:c7d2..."
beads   = "bd-c3d4"

[[removed]]
name       = "csv_export_cap"
removed_at = "2026-03-12T08:00:00Z"
removed_by = "ci/release#4310"
beads      = "bd-e5f6"
reason     = "replaced by reporting_cap"
```

The `[[removed]]` section is **append-only**. Entries are never deleted.
This is the permanent record that a capability existed, why it was removed,
and when.

---

## 7. Beads Integration

Beads is the coordination layer. Every change to capability state MUST have
a corresponding Beads issue.

### 7.1 Issue types for this project

| Type          | When to use |
|---------------|-------------|
| `cap-add`     | Adding a new capability |
| `cap-change`  | Modifying a capability (any semver bump) |
| `cap-remove`  | Removing or deprecating a capability |
| `cap-reuse`   | Upgrading a capability version (e.g. auth_cap v2→v3) |
| `arch-change` | Modifying this AGENTS.md or kernel API |
| `bug`         | Standard bug within a capability |
| `task`        | Development task within a capability |

### 7.2 Commit message convention

All commits that change capability state MUST reference the Beads issue:

```
cap(add): billing_cap v0.1.0 [bd-c3d4]
cap(change): auth_cap v2.1.0→v2.3.0 [bd-e7f8]
cap(remove): csv_export_cap [bd-e5f6]
cap(deprecate): csv_export_cap [bd-e5f6]
arch: update kernel storage API [bd-xxxx]
fix(billing_cap): handle nil invoice date [bd-yyyy]
```

### 7.3 Agent workflow

When an agent works on a task:

```bash
# 1. Check what is unblocked
bd ready

# 2. Claim before starting
bd update bd-<hash> --claim

# 3. Work...

# 4. Close with reference
bd close bd-<hash> --note "implemented in <commit_sha>"
```

Agents MUST NOT start work on a task that is not in `bd ready`.
Agents MUST NOT modify `caps.toml` or `caps.lock`.
Agents MUST NOT create Beads issues of type `cap-*` or `arch-change`
— these require human intent.

---

## 8. Build Pipeline Rules

### 8.1 Dev mode

```bash
mix deps.get
mix ecto.migrate          # runs all capability migrations
iex -S mix                # CapabilityWatcher starts, watches caps.toml
```

Changes to `caps.toml` in dev are applied immediately without restart.

### 8.2 Production release

```
mix capabilities.check    # validates caps.toml semver consistency
mix capabilities.freeze   # writes caps.lock
mix ecto.migrate          # runs pending migrations
mix release               # compiles ONLY active capabilities from caps.lock
```

`mix release` uses `caps.lock` — not `caps.toml` — as its source of truth.
A capability not in `caps.lock` is **not compiled into the binary**.

### 8.3 CI gates (all must pass before merge to main)

1. `mix capabilities.check` — semver consistency
2. `mix test` — full test suite including capability integration tests
3. `mix capabilities.audit` — every capability in caps.toml has a valid Beads issue
4. `mix dialyzer` — type checking
5. `mix credo --strict` — style and code quality

---

## 9. Testing Rules

### 9.1 Capability isolation in tests

Each capability test suite runs with its own namespaced sandbox:

```elixir
# test/support/capability_case.ex
defmodule MyApp.CapabilityCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use MyApp, :capability_case
      import MyApp.CapabilityFactory
    end
  end

  setup tags do
    cap = tags[:capability] || raise "must tag test with @tag capability: :name"
    CapabilityStorage.sandbox_start(cap)
    on_exit(fn -> CapabilityStorage.sandbox_stop(cap) end)
    :ok
  end
end
```

```elixir
# In a capability test
@tag capability: :billing
test "creates invoice" do
  # ...
end
```

### 9.2 Cross-capability tests

Tests that verify interactions between capabilities live in
`test/integration/<cap_a>_<cap_b>_test.exs`. They require both namespaces
to be active and test only through `CapabilityBus` — never through
direct module calls between capabilities.

### 9.3 Coverage requirement

Every capability must maintain ≥ 80% test coverage.
CI fails below this threshold.

---

## 10. What Agents May and May Not Do

### Permitted without human approval
- Implement tasks listed in `bd ready` within an existing capability
- Write tests for existing capability code
- Fix bugs within a capability's own namespace
- Read any file in the repository
- Run `mix test`, `mix dialyzer`, `mix credo`
- Create Beads issues of type `bug` or `task`

### Requires human approval (create Beads issue, wait for human to proceed)
- Any change to `AGENTS.md`
- Any change to `caps.toml`
- Any change to `kernel/`
- Creating a new capability directory
- Adding a dependency between capabilities (`requires` field)
- Any migration that drops or renames a table

### Never permitted
- Writing to `caps.lock` (CI only)
- Deleting migration files
- Bypassing `CapabilityStorage` to access another capability's tables directly
- Creating Beads issues of type `cap-add`, `cap-change`, `cap-remove`, `arch-change`
- Writing directly to `tenant_capability_events` table
- Calling `TenantProvisioner.deprovision/2` (destructive — human only)
- Cross-tenant queries of any kind

---

## 11. Glossary

| Term | Definition |
|------|-----------|
| **capability** | A self-contained OTP Application representing one domain of functionality |
| **kernel** | The immutable core: supervisor, registry, storage API, event bus, tenant layer, secrets API |
| **caps.toml** | Human-editable manifest declaring the active capability surface (system axis) |
| **caps.lock** | CI-generated frozen snapshot used for production builds |
| **capability namespace** | Table prefix owned by exactly one capability, e.g. `billing_` |
| **tenant schema** | PostgreSQL schema isolating one tenant's data, e.g. `tenant_abc` |
| **tenant capability** | The activation of a system capability for a specific tenant (tenant axis) |
| **degrowth** | The deliberate, clean removal of a capability including its code, storage across all tenants, infra module, and intent record |
| **Beads issue** | The unit of intent — records why a change was made, not just what |
| **system axis** | What capabilities exist in the binary (governed by caps.lock) |
| **tenant axis** | Which capabilities a tenant has activated (governed by TenantCapabilityRegistry) |
| **Gateway behaviour** | Elixir behaviour that abstracts an external service, enabling swap without touching capability logic |
| **event contract test** | Test in the consumer capability that validates the shape of events emitted by another capability |
| **capability infra module** | Terraform module that provisions all cloud resources for one capability — applied on add, destroyed on remove |

---

## 12. Multitenancy Rules

Multitenancy introduces a **second, independent axis** on top of the capability lifecycle.
The two axes must never be conflated:

| Axis | Governed by | Changed by | Audit in |
|------|-------------|------------|----------|
| system | `caps.lock` | CI build | git / caps.lock `[[removed]]` |
| tenant | `TenantCapabilityRegistry` | runtime API | `tenant_capability_events` table |

### 12.1 Two-axis invariant

A capability can be activated for a tenant **only if** it is present in `caps.lock`.
`TenantCapabilityRegistry.activate/3` enforces this at the call site — it returns
`{:error, :not_in_caps_lock}` if the capability is absent from the current build.

```
caps.lock has billing_cap?  ──NO──→  cannot activate for any tenant
        │
       YES
        │
TenantCapabilityRegistry has billing_cap for tenant_abc? ──NO──→ 403 at guard
        │
       YES
        │
      request proceeds with prefix: "tenant_abc"
```

### 12.2 Tenant schema lifecycle

**Provisioning a new tenant:**
```elixir
# Creates PostgreSQL schema + runs all migrations for activated capabilities
TenantProvisioner.provision("tenant_abc", [:issues_cap, :billing_cap])
# → CREATE SCHEMA tenant_abc
# → runs issues_cap migrations in tenant_abc
# → runs billing_cap migrations in tenant_abc
# → inserts rows in TenantCapabilityRegistry
```

**Activating a capability for an existing tenant:**
```elixir
TenantCapabilityRegistry.activate("tenant_abc", :reporting_cap, plan: :pro)
# → verifies :reporting_cap in caps.lock
# → runs reporting_cap pending migrations in schema tenant_abc
# → inserts row in tenant_capability_events (audit)
```

**Deactivating a capability for a tenant (data retained):**
```elixir
TenantCapabilityRegistry.deactivate("tenant_abc", :reporting_cap)
# → marks inactive in registry (data in tenant_abc.reporting_* untouched)
# → inserts row in tenant_capability_events (audit)
# → TenantCapabilityGuard starts returning 403 for reporting routes
```

**Deprovisioning a tenant entirely:**
```elixir
TenantProvisioner.deprovision("tenant_abc")
# → requires explicit confirmation flag: deprovision("tenant_abc", confirm: true)
# → archives schema tenant_abc → tenant_abc_archived_<timestamp>
# → retention: 90 days, then DROP SCHEMA
```

### 12.3 TenantCapabilityGuard

Every HTTP request passes through this plug. It is the **only** enforcement point —
capabilities themselves must not contain tenant permission checks.

```elixir
defmodule MyApp.TenantCapabilityGuard do
  import Plug.Conn

  def call(conn, _opts) do
    tenant_id = conn.assigns.tenant_id
    capability = conn.assigns.capability   # set by router

    if TenantCapabilityRegistry.capable?(tenant_id, capability) do
      conn
      |> assign(:storage_prefix, TenantProvisioner.prefix(tenant_id))
    else
      conn |> send_resp(403, "capability not active for this tenant") |> halt()
    end
  end
end
```

The `:storage_prefix` assign is then passed into every `CapabilityStorage.repo/2` call.
Capabilities receive the prefix from the connection — they never look it up themselves.

### 12.4 Tenant capability events (audit table)

All changes to tenant capability state are written to a single append-only table
in the `public` schema (not in any tenant schema):

```sql
CREATE TABLE tenant_capability_events (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     text        NOT NULL,
  capability    text        NOT NULL,
  event         text        NOT NULL,  -- 'activated' | 'deactivated' | 'provisioned' | 'deprovisioned'
  plan          text,
  actor_id      text,                  -- user or agent that triggered the change
  beads_ref     text,                  -- optional Beads issue reference
  inserted_at   timestamptz NOT NULL DEFAULT now()
);
```

This table is **never updated, never deleted from**. It is the permanent record
of every capability state change per tenant. Agents must never write to it directly —
only kernel functions write to it.

### 12.5 Multitenancy and Beads

Tenant-level capability changes (activate/deactivate for a specific tenant) do **not**
require a Beads issue — they are operational, not architectural.

Beads issues are required when:
- Adding a new capability to `caps.toml` (which then becomes available to tenants)
- Removing a capability from `caps.toml` (which forces deactivation for all tenants)
- Changing how `TenantCapabilityGuard` or `TenantProvisioner` work (`arch-change`)

### 12.6 Dev / test multitenancy

In development, `MIX_ENV=dev` creates two fixed tenant schemas automatically:
`tenant_dev_a` and `tenant_dev_b` with all active capabilities provisioned.

In tests, use `TenantCase`:
```elixir
defmodule MyApp.TenantCase do
  use ExUnit.CaseTemplate

  setup do
    tenant_id = "tenant_test_#{System.unique_integer([:positive])}"
    caps = CapabilityRegistry.active_capabilities()
    TenantProvisioner.provision(tenant_id, caps)
    on_exit(fn -> TenantProvisioner.deprovision(tenant_id, confirm: true) end)
    {:ok, tenant_id: tenant_id}
  end
end
```

Never use a fixed tenant ID in tests — always generate unique IDs to allow
concurrent test runs without schema conflicts.

---

---

## 13. Resilience Rules

These rules close the six risk gaps that capability lifecycle, storage isolation,
and multitenancy alone do not cover.

### 13.1 Event contract testing

Every event emitted on `CapabilityBus` is a public API. Treat it as such.

**Event naming convention:**
```
<emitting_cap>:<event_name>:v<N>
billing:invoice_created:v2
auth:user_deactivated:v1
```

Version is **mandatory** in the event name string. Never emit an unversioned event.
When the payload shape changes in a breaking way, increment the version and keep
emitting both the old and new version for one deprecation sprint.

**Each capability that subscribes to an event MUST have a contract test:**
```elixir
# capabilities/reporting_cap/test/contracts/billing_contract_test.exs
defmodule ReportingCap.Contracts.BillingTest do
  use ExUnit.Case

  # This test documents what reporting_cap expects from billing_cap.
  # If billing_cap changes the payload, this test fails — not silently in prod.
  test "billing:invoice_created:v2 payload matches expected shape" do
    payload = %{
      invoice_id: "inv_123",
      tenant_id:  "tenant_abc",
      amount:     Decimal.new("99.00"),
      currency:   "EUR",
      issued_at:  ~U[2026-01-01 00:00:00Z]
    }

    assert {:ok, _} = BillingCap.Events.InvoiceCreatedV2.validate(payload)
  end
end
```

Contract tests live in the **consumer** capability, not the emitter. CI runs all
contract tests before merge. A failing contract test blocks the merge — not a
post-deployment alert.

**Event schema modules live in the emitting capability:**
```elixir
defmodule BillingCap.Events.InvoiceCreatedV2 do
  @required_keys [:invoice_id, :tenant_id, :amount, :currency, :issued_at]

  def validate(payload) do
    case Enum.filter(@required_keys, &(not Map.has_key?(payload, &1))) do
      []      -> {:ok, payload}
      missing -> {:error, {:missing_keys, missing}}
    end
  end
end
```

### 13.2 Anti-corruption layer for external dependencies

No capability may call an external service API directly. All external calls go
through a **Gateway behaviour** defined in the capability itself.

```elixir
# capabilities/billing_cap/lib/billing_cap/gateways/payment_gateway.ex
defmodule BillingCap.PaymentGateway do
  @callback charge(amount :: Decimal.t(), currency :: String.t(), token :: String.t())
    :: {:ok, String.t()} | {:error, term}

  @callback refund(charge_id :: String.t(), amount :: Decimal.t())
    :: :ok | {:error, term}
end

# Production implementation (Stripe)
defmodule BillingCap.Gateways.Stripe do
  @behaviour BillingCap.PaymentGateway
  # ... Stripe API calls here
end

# Test / local implementation
defmodule BillingCap.Gateways.Stub do
  @behaviour BillingCap.PaymentGateway
  def charge(_amount, _currency, _token), do: {:ok, "ch_stub_#{System.unique_integer()}"}
  def refund(_charge_id, _amount), do: :ok
end
```

**Config selects the implementation:**
```elixir
# config/config.exs
config :billing_cap, :payment_gateway, BillingCap.Gateways.Stub

# config/prod.exs
config :billing_cap, :payment_gateway, BillingCap.Gateways.Stripe
```

When the external provider changes their API, only the `Stripe` module changes.
The capability business logic, the event schema, and the tests are untouched.

Rules:
- Every external service (payment, email, SMS, AI inference, storage) gets its own
  Gateway behaviour.
- Gateway modules live in `capabilities/<name>_cap/lib/<name>_cap/gateways/`.
- Stub implementations must be complete — no `raise "not implemented"`.
- Integration tests against the real external API live in a separate
  `test/integration/` directory and are **not** run in CI by default.
  Run them with: `mix test --only integration`.

### 13.3 Rollback strategy

Every release must be safely reversible. This requires two things to be true
simultaneously: the binary can be downgraded, and the database can be rolled back.

**Rule: every migration must have a working `down`.**

CI enforces this by running `mix ecto.rollback --all` after `mix ecto.migrate`
in the test pipeline. If `down` raises or is not implemented, the build fails.

**Release procedure with rollback gate:**
```bash
# Before deploying to prod:
mix ecto.migrate                    # apply migrations
mix capabilities.smoke_test         # run smoke tests against staging

# If smoke tests fail — rollback:
mix ecto.rollback --step 1          # per-capability rollback available
mix release.rollback                # swap binary to previous release
```

**Zero-downtime migration rules:**

Database and binary are deployed independently. The old binary must work with
the new schema, and the new binary must work with the old schema, for the
duration of the deployment window (≤ 10 minutes).

This means:
- Never `DROP COLUMN` or `DROP TABLE` in the same release that stops using it.
  Remove usage in release N, drop the column in release N+1.
- Never rename a column in one step. Add the new column, dual-write, migrate
  reads, then drop the old column in a later release.
- Never add a `NOT NULL` column without a default in the same migration that
  removes the default. Add with default → backfill → add constraint separately.

**caps.lock records the previous version for rollback reference:**
```toml
[meta]
frozen_at    = "2026-05-05T10:23:00Z"
previous_sha = "b2f7a1c"             # ← binary to swap to on rollback
```

### 13.4 Observability per capability

Every capability is observable in isolation. The kernel provides the telemetry
infrastructure; each capability instruments itself.

**Kernel telemetry contract (`:telemetry` events every capability MUST emit):**

```elixir
# On every public function entry:
:telemetry.execute(
  [:my_cap, :operation, :start],
  %{system_time: System.system_time()},
  %{tenant_id: tenant_id, operation: :create_invoice}
)

# On success:
:telemetry.execute(
  [:my_cap, :operation, :stop],
  %{duration: duration},
  %{tenant_id: tenant_id, operation: :create_invoice, result: :ok}
)

# On error:
:telemetry.execute(
  [:my_cap, :operation, :exception],
  %{duration: duration},
  %{tenant_id: tenant_id, operation: :create_invoice, kind: :error, reason: reason}
)
```

**Kernel attaches a default handler** that emits these to Prometheus/StatsD.
Capabilities do not configure their own exporters.

**Three mandatory dashboards per capability** (provisioned by `mix capability.new`):
1. Request rate + error rate + latency (RED)
2. Storage namespace size over time
3. Event bus: emitted vs consumed events per minute

**Health check endpoint** — kernel exposes `/health/capabilities` returning:
```json
{
  "billing_cap": { "status": "ok",      "latency_p99_ms": 12 },
  "auth_cap":    { "status": "degraded","latency_p99_ms": 890 },
  "issues_cap":  { "status": "ok",      "latency_p99_ms": 4  }
}
```

A capability is `degraded` when its p99 latency exceeds 3× its 7-day baseline.
A capability is `down` when its health check fails 3 times in 30 seconds.

### 13.5 Configuration and secrets isolation

Configuration follows the same isolation model as storage: one namespace
per capability, one namespace per tenant.

**Three tiers of config:**

```
kernel config     → system-wide, managed by ops
capability config → per-capability, managed by capability owner
tenant config     → per-tenant overrides, managed via TenantCapabilityRegistry
```

**Capability config namespace** (mirrors storage namespace):
```elixir
# Access in capability code — never read Application.get_env directly
config = CapabilityConfig.get(:billing_cap)
# Returns merged map: defaults → env vars → tenant overrides

# In capability application.ex:
def start(_type, _args) do
  CapabilityConfig.register(:billing_cap, %{
    payment_gateway:    BillingCap.Gateways.Stub,  # default
    invoice_prefix:     "INV",
    max_retry_attempts: 3
  })
end
```

**Secrets** are never in config files, environment variables in source control,
or Docker images. They are fetched at runtime from the secrets backend:

```elixir
# kernel/lib/secrets_api.ex
SecretsApi.get(:billing_cap, :stripe_secret_key)
# → fetches from Vault (local) or cloud secrets manager (prod)
# → cached in memory with TTL, auto-rotated
```

**Rules:**
- Never call `System.get_env/1` in capability code. Use `SecretsApi.get/2` or
  `CapabilityConfig.get/1`.
- Never log config values — the kernel's telemetry handler strips known secret
  key patterns from log metadata automatically.
- Tenant-level config overrides (e.g. custom invoice prefix) go through
  `TenantCapabilityRegistry`, not environment variables.

### 13.6 Data deletion and GDPR compliance

Every capability that stores personal data MUST implement the
`CapabilityCompliance` behaviour:

```elixir
defmodule CapabilityCompliance do
  @doc """
  Delete all personal data for a user across this capability's namespace
  within the given tenant schema. Must be idempotent.
  Returns {:ok, count} where count is the number of records affected.
  """
  @callback delete_user_data(tenant_id :: String.t(), user_id :: String.t())
    :: {:ok, non_neg_integer()} | {:error, term}

  @doc """
  Export all personal data for a user (GDPR Article 20 — portability).
  Returns a map of table → list of sanitised rows.
  """
  @callback export_user_data(tenant_id :: String.t(), user_id :: String.t())
    :: {:ok, map()} | {:error, term}
end
```

The kernel provides `DataDeletion.execute(tenant_id, user_id)` which:
1. Calls `delete_user_data/2` on every active capability for the tenant.
2. Writes to `data_deletion_audit` (append-only table in `public` schema).
3. Returns `{:ok, report}` only when all capabilities confirm deletion.
4. Is **idempotent** — safe to call multiple times.

**Rules:**
- Capabilities that do not store personal data must still implement the behaviour
  and return `{:ok, 0}` — so the kernel can confirm compliance without checking
  which capabilities are "personal data" capabilities.
- `export_user_data/2` must not include fields tagged `:internal` or `:derived`
  in the schema — only fields that were directly provided by the user.
- Deletion is **hard delete by default**. Soft delete (anonymisation) is allowed
  only when a legal hold is active and must be documented via a Beads issue with
  type `compliance`.

---

## 14. Infrastructure

The infrastructure design follows the same growth/degrowth philosophy as
capabilities: each capability can have its own infra module, and the entire
stack can run locally without external dependencies.

### 14.1 Two-environment model

```
local      → Docker Compose, mirrors prod topology exactly
production → Cloud provider via Terraform/OpenTofu (IaC)
```

There is no separate "staging" environment. Staging parity is achieved via
`caps.toml` — a staging instance runs a subset of capabilities from the same
`caps.lock` as production.

**The cardinal rule:** if it works locally, it works in prod.
This is only possible if local = production topology at the service level.

### 14.2 Local development stack

All local services are defined in `infra/local/docker-compose.yml`.
Run with: `make dev` (alias for `docker compose -f infra/local/docker-compose.yml up`).

```yaml
# infra/local/docker-compose.yml
services:

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB:       app_dev
      POSTGRES_USER:     app
      POSTGRES_PASSWORD: app
    ports: ["5432:5432"]
    volumes: ["pg_data:/var/lib/postgresql/data"]

  vault:
    image: hashicorp/vault:1.15
    cap_add: [IPC_LOCK]
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: dev-root-token
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    ports: ["8200:8200"]
    # Local Vault mirrors prod Vault/cloud secrets manager API surface

  prometheus:
    image: prom/prometheus:v2.50.1
    volumes: ["./prometheus.yml:/etc/prometheus/prometheus.yml"]
    ports: ["9090:9090"]

  grafana:
    image: grafana/grafana:10.3.1
    environment:
      GF_AUTH_ANONYMOUS_ENABLED: "true"
    volumes: ["./grafana/dashboards:/etc/grafana/provisioning/dashboards"]
    ports: ["3000:3000"]
    depends_on: [prometheus]

  app:
    build: ../..
    environment:
      DATABASE_URL:      postgres://app:app@postgres:5432/app_dev
      VAULT_ADDR:        http://vault:8200
      VAULT_TOKEN:       dev-root-token
      CAPABILITY_ENV:    dev
    ports: ["4000:4000"]
    depends_on: [postgres, vault]
    volumes: ["../../:/app"]  # live reload in dev

volumes:
  pg_data:
```

**What maps to what in production:**

| Local service | Production equivalent |
|---------------|----------------------|
| `postgres`    | Managed PostgreSQL (RDS / Cloud SQL / Azure DB) |
| `vault`       | AWS Secrets Manager / GCP Secret Manager / Azure Key Vault |
| `prometheus`  | Managed Prometheus (AWS AMP / GCP Managed Prometheus) |
| `grafana`     | Grafana Cloud or self-hosted on K8s |
| `app`         | Container on ECS / Cloud Run / AKS |

The app code never knows which environment it runs in — it always talks to
`DATABASE_URL` and `VAULT_ADDR`. The runtime provides the right endpoints.

### 14.3 Infrastructure as Code structure

```
infra/
├── local/
│   ├── docker-compose.yml
│   ├── prometheus.yml
│   └── grafana/
│       └── dashboards/          ← auto-provisioned from capability templates
├── modules/
│   ├── capability-infra/        ← per-capability IaC module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── tenant-schema/           ← per-tenant DB schema provisioning
│   ├── secrets-namespace/       ← per-capability secrets namespace
│   └── observability/           ← dashboards + alerts per capability
├── envs/
│   ├── staging/
│   │   ├── main.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       └── terraform.tfvars
├── provider.tf                  ← provider abstraction (see 14.4)
└── Makefile
```

**Makefile targets:**
```makefile
dev:         docker compose -f local/docker-compose.yml up
dev-down:    docker compose -f local/docker-compose.yml down -v
plan-prod:   cd envs/prod && tofu plan
apply-prod:  cd envs/prod && tofu apply
destroy-cap: cd envs/prod && tofu destroy -target=module.$(CAP)_infra
```

### 14.4 Provider abstraction

OpenTofu (open-source Terraform) is the IaC tool. The cloud provider is
declared in one place — `infra/provider.tf` — and never referenced directly
in module code.

```hcl
# infra/provider.tf — the ONLY file that names a cloud provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "cloud_provider" {
  description = "Target cloud: aws | gcp | azure"
  default     = "aws"
}
```

Modules use abstract resource names mapped through a provider shim:
```hcl
# infra/modules/capability-infra/main.tf
# Receives: capability name, environment, provider shim outputs
# Produces: DB namespace, secrets namespace, IAM role, dashboard

module "db_namespace" {
  source     = "../tenant-schema"
  capability = var.capability_name
  db_url     = var.db_url        # injected from provider outputs
}

module "secrets" {
  source     = "../secrets-namespace"
  capability = var.capability_name
  backend    = var.secrets_backend  # "vault" | "aws_sm" | "gcp_sm" | "azure_kv"
}
```

**Switching providers** requires changing `provider.tf` and the `envs/prod/terraform.tfvars`
`secrets_backend` variable. No module code changes.

### 14.5 Capability infra lifecycle

Capabilities have infra just as they have code. When a capability is added,
its infra module is applied. When removed, it is destroyed.

```bash
# Add capability infra (runs after mix capabilities.freeze in CI)
tofu apply -target=module.billing_cap_infra

# Remove capability infra (runs after cap is removed from caps.lock)
tofu destroy -target=module.billing_cap_infra
```

The `mix capability.new <name>` scaffold generates:
- `infra/modules/capability-infra/<name>/` with Terraform module stubs
- `infra/local/grafana/dashboards/<name>.json` from the RED dashboard template
- `infra/local/prometheus.yml` append for the new scrape target

**Infra state is stored in a backend bucket** (S3 / GCS / Azure Blob) that is
the only manually-created resource in the cloud account. Everything else is
managed by OpenTofu.

### 14.6 Secrets management across environments

```
Local:       Vault dev server (auto-unsealed, no persistence)
Staging:     Vault OSS on a single VM (or cloud KMS-backed)
Production:  Cloud-native secrets manager (provider-specific)
```

The app always talks to `VAULT_ADDR` + `VAULT_TOKEN`. In production, a sidecar
(Vault Agent or cloud-specific equivalent) runs next to the app container,
handles cloud auth (IAM role binding), and exposes the same Vault API locally.

```elixir
# kernel/lib/secrets_api.ex
# The same code path works in all environments.
def get(capability, key) do
  path = "secret/#{capability}/#{key}"
  case Vault.read(path) do
    {:ok, %{"data" => %{"value" => v}}} -> {:ok, v}
    {:error, _} = err                   -> err
  end
end
```

**Secrets rotation rule:** Every secret must have a TTL. The kernel's
`SecretsApi` re-fetches secrets on TTL expiry without app restart.
Capabilities must not cache secrets beyond one request.

### 14.7 Container and release strategy

The app is released as an OTP release (not a Mix project) inside a minimal
Docker image:

```dockerfile
# Multi-stage build
FROM elixir:1.17-otp-27-alpine AS builder
WORKDIR /app
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY . .
RUN MIX_ENV=prod mix capabilities.freeze \
 && MIX_ENV=prod mix release

FROM alpine:3.19 AS runtime
RUN apk add --no-cache libstdc++ openssl ncurses-libs
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/app ./
ENV HOME=/app
CMD ["bin/app", "start"]
```

**Image tagging convention:**
```
registry/app:<git_sha>-<caps_lock_sha>
```

Both SHAs are in the tag — `git_sha` identifies the code, `caps_lock_sha`
identifies the capability set. A rollback to the previous binary is
`docker pull registry/app:<previous_git_sha>-<previous_caps_lock_sha>`.

**Never use `latest` in production.** Tags are immutable.

### 14.8 Infrastructure rules for agents

Agents may:
- Read any file in `infra/`
- Modify `infra/local/docker-compose.yml` for local development needs
- Add dashboard templates in `infra/local/grafana/dashboards/`
- Modify `infra/modules/capability-infra/<name>/` for the capability they
  are currently implementing (must be in `bd ready`)

Agents must never:
- Run `tofu apply` or `tofu destroy` — infra changes require human approval
- Modify `infra/provider.tf` or `infra/envs/prod/`
- Create new IAM roles, security groups, or network resources manually
- Commit secrets, credentials, or `.tfstate` files to git

---

*Document version: 1.0.0*
*Last arch-change: resilience rules + infrastructure [bd-rs01, bd-infra01]*
*Maintained by: human maintainers only*
*Agents: read-only*
