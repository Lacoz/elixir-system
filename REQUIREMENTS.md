# System requirements (extracted from AGENTS.md)

This document lists **normative requirements** for this codebase as stated in
[`AGENTS.md`](./AGENTS.md). AGENTS.md remains the architectural contract; this
file is a **checklist-oriented digest** for onboarding and reviews.

## Philosophy

1. Any design MUST allow **adding** without touching the kernel **unless** the kernel API truly requires extension (then follow arch-change process).
2. Any design MUST allow **changing** one capability without breaking unrelated capabilities.
3. Any design MUST allow **removing** a capability without orphaned code, data, or undocumented intent.

## Repository layout

4. **No business logic** in `kernel/`.
5. **Capability code** lives only under `capabilities/<name>_cap/` (no shared root `lib/` for domain logic).
6. Cross-capability interaction goes through the kernel registry/bus/APIs defined in AGENTS — **not** direct imports between capability modules.

## Capability lifecycle

7. Capabilities map **1:1** to OTP applications and are declared in `caps.toml` / frozen in `caps.lock`.
8. Adding, materially changing, deprecating, or removing a capability follows the **semver + migration + intent record** rules in AGENTS (ticket reference on each capability row where required).
9. **AI agents do not edit `caps.toml` or `caps.lock` directly** — human/CI workflow only.

## Kernel

10. Kernel exposes **only** the APIs enumerated in AGENTS (registry, storage API, grants, partition provisioning, principal resolution, event bus, etc.).
11. Kernel MUST NOT contain HTTP handlers, domain schemas, raw cross-cap SQL, or imports of capability modules.
12. Kernel MUST be covered by **stricter tests** than generic capability code (see AGENTS §9).

## Storage

13. Table names use the **capability namespace prefix**; partitions use **partition schemas** — never conflate the two axes.
14. Migrations live under each capability’s `priv/migrations/`; implement **`up` and `down`**; no hand-editing `caps.lock`.

## Coordination (tickets)

15. Use **[ticket](https://github.com/wedow/ticket)** (`tk`) for intent tracking — markdown tickets under `.tickets/` (see AGENTS §7).
16. Operational grant/partition operations do not require a ticket **unless** AGENTS says otherwise for that operation class.

## Testing & CI

17. Respect **`mix capabilities.diffcheck`** line limits per commit (see AGENTS §7.3).
18. Gate order and tooling (`capabilities.check`, `test`, `dialyzer`, `credo`, etc.) as documented in AGENTS §8.3.
19. Capability coverage floor **≥ 80%**; kernel expectations **stricter** (see AGENTS §9).

## Agents (permissions boundary)

20. Permitted / requires-approval / forbidden actions for automation are exactly as listed in AGENTS §10.

## Compliance & resilience

21. Event contracts, gateways for externals, rollback-friendly migrations, telemetry, secrets handling, GDPR hooks — follow AGENTS §13–14 where applicable.

---

For prose, examples, and exceptions, always read **`AGENTS.md`**.
