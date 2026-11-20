# Pangolin machine client in Hercules CI `deploy`

Primary-source research for running a Pangolin **machine client** inside (or alongside) the nixpedition Hercules CI `deploy` effect so `clan machines update` and `hci-effects.ssh` can reach hosts via **private** Pangolin resources instead of public IPs.

Research date: 2026-11-20. Sources are Pangolin docs, fosrl/olm, and Hercules CI docs/agent source only.

**Repo context (not a product claim):** today’s `deploy` effect (`nix/effects/deploy.nix`) uses `secretsMap` for SSH/age, persists `~/.ssh/known_hosts` via `getStateFile`/`putStateFile`, and SSH targets come from `clan.core.networking.targetHost` (francois currently `root@51.83.129.177:2222`). Preference from the Pangolin plan: steady state = CI runs Olm/machine client; bootstrap may still use public SSH once.

---

## Verdict

**Yes — with a machine client (Pangolin CLI), not a user login, and not a one-shot “enrollment token”.**

1. Create a **machine client** in Pangolin; store **ID + secret + endpoint** in the HCI agent `secrets.json` and map them into the effect (same pattern as `ci-ssh-keys`).
2. Ensure each deploy target is a **private host** (or private SSH) resource with an **alias**, granted to that machine client (`clientIds` / blueprint `machines`).
3. Bring the tunnel up **before** `clan machines update` / `hci-effects.ssh`, with **Override DNS** on so aliases resolve.
4. Point `networking.targetHost` at the alias (e.g. `root@francois.internal:2222`), not the public IP.
5. Treat **TUN / NET_ADMIN in the effect sandbox** as the main implementation risk; a supported fallback is a **persistent machine client on the agent host**, because effects **share the host network namespace**.

Olm standalone is **deprecated**; Pangolin CLI is the recommended machine-client runner (Olm remains the underlying library).

---

## 1. Client model: machines vs users

| Kind | Auth | Intended use |
| --- | --- | --- |
| User device | Web login (password / 2FA / IdP) → session | Humans |
| Machine client | **ID + secret + endpoint** (no web login) | Servers, automation, **CI/CD** |

Sources: [Understanding Clients](https://docs.pangolin.net/manage/clients/understanding-clients), [Machine Clients](https://docs.pangolin.net/manage/clients/machine-clients).

Docs explicitly list **“A CI/CD runner that deploys against an internal database”** as a machine-client use case.

**There is no separate “enrollment token”** for machine clients in current docs. Provisioning is: dashboard **Clients → Machines** → create → copy **ID, secret, endpoint** shown at creation. Credentials can be **regenerated** later (invalidates the old ID/secret).

Olm’s `--user-token` / `OLM_USER_TOKEN` flags exist for **user** flows; machine auth is ID/secret/endpoint (CLI flags or env). Source: [Olm (Deprecated)](https://docs.pangolin.net/manage/clients/platforms/olm).

---

## 2. How to run the client (headless)

### Recommended: Pangolin CLI

```bash
pangolin up --id {client_id} --secret {client_secret} --endpoint {endpoint_url} --attach
```

- `--attach` keeps the client in the **foreground** (suitable as a background job in an effect with `&` / wait-for-ready, or as a systemd `ExecStart`).
- Without a user login: pass machine credentials as above.
- Persistent host install: `sudo pangolin service install client --id … --secret … --endpoint …`.

Install: `curl -fsSL https://static.pangolin.net/get-cli.sh | bash`, or GitHub release binaries / `fosrl/pangolin-cli` Docker image.

Docker notes (also the capability checklist for any containerized runner): `network_mode: host`, `cap_add: [NET_ADMIN]`, `/dev/net/tun`.

Source: [Pangolin CLI](https://docs.pangolin.net/manage/clients/platforms/cli).

Config defaults (DNS, etc.) live in `~/.config/pangolin/config.json` (`pangolin config path`). Override DNS defaults to **on** (`up.override_dns`).

### Deprecated but still documented: Olm

```bash
olm --id … --secret … --endpoint https://pangolin.example.com
```

Env equivalents: `PANGOLIN_ENDPOINT`, `OLM_ID`, `OLM_SECRET`. Optional `CONFIG_FILE` / `~/.config/olm-client/config.json` persists credentials after first start (“you do not need to run every time with --id and secret if you have run it once”).

Gotcha: Olm creates a **native TUN** interface and typically needs **root / CAP_NET_ADMIN** and `/dev/net/tun`.

Sources: [Olm](https://docs.pangolin.net/manage/clients/platforms/olm), [fosrl/olm](https://github.com/fosrl/olm) (points operators at Pangolin CLI for machine clients).

**For nixpedition:** prefer packaging/running **Pangolin CLI** in the effect; treat “Olm” in plan language as “machine client (CLI/Olm stack).”

---

## 3. Access grant + private SSH path for Clan / OpenSSH

### Deny-by-default

A connected machine client has **no** private-resource access until granted:

| Method | Where | Notes |
| --- | --- | --- |
| Direct | Private resource → Access → assign machine | Works on self-hosted without EE |
| Roles | Machine → General → roles | Role assignment on machines is **Cloud / self-hosted Enterprise** only |

Sources: [Machine Clients](https://docs.pangolin.net/manage/clients/machine-clients), [Private authentication](https://docs.pangolin.net/manage/resources/private/authentication).

API / Blueprints: private resources take `clientIds` (numeric machine IDs) or blueprint `machines: [machine-id-…]`.  
Sources: [Common API Routes — create private resource](https://docs.pangolin.net/manage/common-api-routes), [Blueprints](https://docs.pangolin.net/manage/blueprints).

### Resource types that fit `clan` + `hci-effects.ssh`

| Type | How SSH works | Fit for current deploy effect |
| --- | --- | --- |
| **Private host** | Tunnel + normal OpenSSH to destination or **alias**; any TCP/UDP with port restrictions | **Best fit** — keep `writeSSHKey` / `openssh` / `hci-effects.ssh` |
| **Private SSH** | `pangolin ssh <alias>` with Pangolin identity / optional cert provisioning | Extra CLI surface; not required if host resource + existing SSH keys suffice |

Private **host** docs call out CI explicitly: “Give a machine client, such as a CI runner, access to one build server…”. Use destination `127.0.0.1`/`localhost` when the service is on the **site connector host**, and **require an alias** (loopback on the client machine is not the remote). Restrict TCP to the SSH port (e.g. `2222`) via port restrictions.

Sources: [Private Host](https://docs.pangolin.net/manage/resources/private/host), [Private SSH](https://docs.pangolin.net/manage/resources/private/ssh), [Port restrictions](https://docs.pangolin.net/manage/resources/private/port-restrictions).

**francois sketch:** site on francois (Newt or local site connector) + private host resource destination `127.0.0.1` (or the SSH listen address) + alias e.g. `francois.internal` + TCP allow `2222` + `clientIds` = CI machine. Then `networking.targetHost = "root@francois.internal:2222"`.

---

## 4. DNS and routing for aliases

- Clients are **split-tunnel by default**: only granted resource IPs/CIDRs/aliases go through the tunnel. Source: [Understanding Clients](https://docs.pangolin.net/manage/clients/understanding-clients).
- **Override DNS** (default **on**) points the OS resolver at the org utility-subnet DNS (default first address **`100.96.128.1`**). Aliases and private HTTP names resolve to **overlay** addresses, not the real LAN IP — required for aliases to work. Source: [DNS for Clients](https://docs.pangolin.net/manage/clients/dns).
- Aliases need **no public DNS**. Avoid single-label names and `.local`. Source: [Aliases](https://docs.pangolin.net/manage/resources/private/alias).
- If **match domains** are set, every alias must match a pattern or it never hits Pangolin DNS.
- Site applies **SNAT**: backends see the **site connector’s** IP, not the client WireGuard IP — relevant for host firewalls on francois/esquie. Source: [Understanding Clients — How Traffic Leaves the Site](https://docs.pangolin.net/manage/clients/understanding-clients).

For the effect: start the client with override DNS enabled (CLI default), wait until the alias resolves (e.g. `getent hosts francois.internal` or `nslookup … 100.96.128.1`), then run `clan machines update` / `hci-effects.ssh`.

---

## 5. Persistence across effect runs

| Data | Persist how? | Why |
| --- | --- | --- |
| Machine **ID / secret / endpoint** | HCI agent **`secrets.json`** + effect `secretsMap` (like existing `ssh` / `age`) | Stable long-lived credentials; secret must stay off state files and git |
| SSH host keys | Existing `getStateFile` / `putStateFile` for `known_hosts` | Already in `deploy.nix` |
| Pangolin CLI/Olm config under `~/.config/…` | Optional via state API | **Not required** if every run passes `--id/--secret/--endpoint` (or env) from secrets |
| WireGuard session / ephemeral keys | **Do not persist** | Re-established each connect (handshake → temp session → WS → WG). Source: [Machine Clients — Credentials](https://docs.pangolin.net/manage/clients/machine-clients) |

Hercules CI state API is a per-project file bucket with history; secrets stay on the agent. Sources: [Effects](https://docs.hercules-ci.com/hercules-ci-agent/effects/), [putStateFile](https://docs.hercules-ci.com/hercules-ci-effects/reference/bash-functions/putstatefile/), [Effects introduction](https://docs.hercules-ci.com/hercules-ci/effects/).

**Rotation:** regenerate machine credentials in the dashboard, update agent secrets, restart clients. “Regenerate and Disconnect” forces immediate reconnect with new secrets.

---

## 6. Hercules CI effect sandbox constraints

Documented sandbox:

- Transient **Linux** container (`crun`), network access, Nix store, secrets, state API.
- Process is **virtual UID 0**; “does not gain any real privileges from being uid 0.”
- Optional **`mounts` / `effectMountables`** (agent ≥ 0.10.1) to bind host paths (docs example: `/dev/kvm`; USB guide shows the pattern for other devices).

Sources: [Effects](https://docs.hercules-ci.com/hercules-ci-agent/effects/), [effectMountables](https://docs.hercules-ci.com/hercules-ci-agent/agent-config/), [Add USB devices](https://docs.hercules-ci.com/hercules-ci/guides/add-a-usb-device/), [Effect core `mounts`](https://docs.hercules-ci.com/hercules-ci-effects/reference/effect-modules/core/).

**Network namespace:** agent builds the OCI spec from `crun spec --rootless` and **removes the `network` namespace** from the template, so the effect **shares the agent host’s network stack** (and thus host routes/DNS if a host-level client is up). Source: [Container.hs `effectToOCIRuntimeSpec`](https://hdiff.luite.com/file/hercules-ci-agent/0.10.8/src/Hercules/Effect/Container.hs) (filter on `linux.namespaces`).

**TUN implication (open risk):** Pangolin CLI/Olm Docker docs require `NET_ADMIN` + `/dev/net/tun`. HCI docs do **not** document granting `CAP_NET_ADMIN` to effects. Mounting `/dev/net/tun` via `effectMountables` is plausible by analogy with USB/KVM mounts, but **creating a WireGuard interface inside a rootless effect is unverified** and may fail without agent/host capability work.

### Two steady-state shapes

| Shape | Where the client runs | Pros | Cons |
| --- | --- | --- | --- |
| **A. In-effect** | `pangolin up … --attach` at start of `effectScript` | Matches “CI runs the client”; credentials only in effect secrets | Needs working TUN in sandbox; must wait for connect; teardown/DNS restore on exit |
| **B. On agent host** | systemd/`pangolin service install client` on the HCI agent machine | Tunnel always up; effect inherits host netns routes/DNS | Client lifecycle outside the effect; agent host must stay enrolled |

Both satisfy “CI reaches private SSH resources.” Shape A matches the written preference most closely; shape B is the documented-capability-safe fallback if TUN-in-effect fails.

---

## 7. End-to-end path for nixpedition `deploy`

**Bootstrap (public SSH once):** keep `targetHost = "root@PUBLIC:2222"` until Pangolin control plane + site on francois (and other sites) exist and a private host resource + machine client are created. Apply Blueprints/API for the private resource with `machines` / `clientIds`.

**Steady state:**

1. Agent secret e.g. `ci-pangolin-machine` → `{ id, secret, endpoint }`.
2. Effect `secretsMap."pangolin" = "ci-pangolin-machine"`.
3. Before deploy SSH: start Pangolin CLI machine client (shape A) **or** assume host client (shape B); confirm alias resolution.
4. Set Clan `networking.targetHost` to `root@<alias>:<ssh-port>`.
5. Existing `writeSSHKey` + `clan machines update --host-key-check accept-new` + `hci-effects.ssh` continue to work over the tunnel.

Do **not** need `pangolin ssh` unless adopting Pangolin’s SSH certificate/provisioning mode.

---

## 8. Open risks / follow-ups

1. **Prove TUN in the actual HCI agent** (or adopt shape B). No first-party HCI doc states WireGuard-in-effect support.
2. **Machine create API** for fully Nix/Blueprint-driven bootstrap: common-routes guide documents private resources with `clientIds` but **dashboard create** is the documented way to obtain ID/secret; confirm Swagger/OpenAPI for machine CRUD before automating enrollment.
3. **Enterprise vs CE:** role assignment on machine clients is EE/Cloud; direct resource grants are enough for CE.
4. **DNS override side effects** in a shared host netns (shape A or B): Override DNS rewrites system resolver while connected; effect crash cleanup and `pangolin reset-dns` matter on the agent host. Source: [DNS for Clients](https://docs.pangolin.net/manage/clients/dns).
5. Prior product research noted Clan-over-Pangolin as **partial** until private resources + aliases + machine clients are proven — this note supplies that path. See [`docs/research/pangolin-vs-netbird.md`](./pangolin-vs-netbird.md) §9 row 5 (on main / Projects tree if missing from this worktree).

---

## Source index

| Topic | URL |
| --- | --- |
| Machine clients | https://docs.pangolin.net/manage/clients/machine-clients |
| Understanding clients | https://docs.pangolin.net/manage/clients/understanding-clients |
| Pangolin CLI | https://docs.pangolin.net/manage/clients/platforms/cli |
| Olm (deprecated) | https://docs.pangolin.net/manage/clients/platforms/olm |
| Client DNS | https://docs.pangolin.net/manage/clients/dns |
| Aliases | https://docs.pangolin.net/manage/resources/private/alias |
| Private host | https://docs.pangolin.net/manage/resources/private/host |
| Private SSH | https://docs.pangolin.net/manage/resources/private/ssh |
| Port restrictions | https://docs.pangolin.net/manage/resources/private/port-restrictions |
| Private auth | https://docs.pangolin.net/manage/resources/private/authentication |
| Blueprints | https://docs.pangolin.net/manage/blueprints |
| Common API routes | https://docs.pangolin.net/manage/common-api-routes |
| fosrl/olm | https://github.com/fosrl/olm |
| HCI Effects | https://docs.hercules-ci.com/hercules-ci-agent/effects/ |
| HCI effectMountables | https://docs.hercules-ci.com/hercules-ci-agent/agent-config/ |
| HCI USB/mounts guide | https://docs.hercules-ci.com/hercules-ci/guides/add-a-usb-device/ |
| HCI effect `mounts` | https://docs.hercules-ci.com/hercules-ci-effects/reference/effect-modules/core/ |
| HCI putStateFile | https://docs.hercules-ci.com/hercules-ci-effects/reference/bash-functions/putstatefile/ |
| Agent Container.hs (netns) | https://hdiff.luite.com/file/hercules-ci-agent/0.10.8/src/Hercules/Effect/Container.hs |
