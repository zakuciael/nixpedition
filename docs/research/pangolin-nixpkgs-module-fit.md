# nixpkgs Pangolin module fit vs standalone Traefik on `francois`

Research date: 2026-11-20. Primary sources only: nixpkgs module source, init PR, NixOS release notes / wiki, Fossorial Pangolin docs, and this repo’s Traefik aspect / flake lock.

**Question:** Against current nixpkgs/`nixos-unstable` (and this repo’s flake channel), what does the NixOS Pangolin module configure (Pangolin, Gerbil, Traefik, Badger, ports, certs hooks), and can it replace our standalone `services/traefik` aspect on `francois` for public HTTPS — what gaps force Docker or extra modules?

---

## 1. Channel inventory (what we actually pin)

| Source | `fosrl-pangolin` | `fosrl-gerbil` | Module notes |
| --- | --- | --- | --- |
| Upstream GitHub (context) | 1.24.x line documented in prior research | Gerbil separate repo | Official install remains Docker Compose–first |
| `nixos-unstable` tip | **1.24.0** | **1.6.0** | `openFirewall` opens UDP **21820** + **51820**; default settings include `disable_signup_without_invite = true` |
| `nixos-26.05` tip | **1.24.0** | **1.4.0** | Same module shape as this repo’s lock for firewall/Badger; **no** UDP 21820 in `openFirewall` |
| **This repo’s flake lock** (FlakeHub `nixpkgs` `0.2605`, rev `c5c4a43b0e…`) | **1.21.1** | **1.4.0** | Module present; behind 26.05 tip on Pangolin package |

Repo flake input is **not** `nixos-unstable`. It is release-track **26.05** via FlakeHub:

- [`flake.nix`](../../flake.nix): `nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.zst"` (regenerated flake-file also lists FlakeHub `0.2605` in lock metadata).
- [`flake.lock`](../../flake.lock): locked rev `c5c4a43b0e8056328ec4529f735cabdb8f1942bb`.

Package sources:

- Locked Pangolin: <https://github.com/NixOS/nixpkgs/blob/c5c4a43b0e8056328ec4529f735cabdb8f1942bb/pkgs/by-name/fo/fosrl-pangolin/package.nix>
- Unstable Pangolin: <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/fo/fosrl-pangolin/package.nix>
- Locked Gerbil: <https://github.com/NixOS/nixpkgs/blob/c5c4a43b0e8056328ec4529f735cabdb8f1942bb/pkgs/by-name/fo/fosrl-gerbil/package.nix>
- Unstable Gerbil: <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/fo/fosrl-gerbil/package.nix>

Module paths (same file on both channels):

- Unstable: <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/pangolin.nix>
- Locked: <https://github.com/NixOS/nixpkgs/blob/c5c4a43b0e8056328ec4529f735cabdb8f1942bb/nixos/modules/services/networking/pangolin.nix>
- Listed in `nixos/modules/module-list.nix` as `./services/networking/pangolin.nix`.

Init PR (merged 2025-09-22): [nixos/pangolin: init](https://github.com/NixOS/nixpkgs/pull/416148). Release notes (25.11 new modules): Pangolin as `services.pangolin`, Newt as `services.newt`. Maintainer wiki sketch: [User:Jackrosenberg/Pangolin](https://wiki.nixos.org/wiki/User:Jackrosenberg/Pangolin).

---

## 2. What `services.pangolin` configures

Enabling `services.pangolin.enable` wires a **native systemd stack** (no Docker): Pangolin → Gerbil → Traefik, plus a Traefik **Badger** plugin pin. Order is documented in-module: `pangolin.service` → `gerbil.service` → `traefik.service`.

### 2.1 Pangolin (control plane)

| Item | Behavior |
| --- | --- |
| Package | `pkgs.fosrl-pangolin` (`services.pangolin.package`) |
| User/group | system user `pangolin` in group `fossorial` |
| State | `dataDir` default `/var/lib/pangolin`; tmpfiles create `dataDir`, `config/`, `config/letsencrypt/` |
| Config | Merged YAML written to `${dataDir}/config/config.yml` on `preStart` |
| Defaults (locked / 26.05 tip) | `app.dashboard_url`, `domains.domain1.base_domain` + `prefer_wildcard_cert = false`, server ports **3000/3001/3002/3003**, `internal_hostname = "localhost"`, `gerbil.base_endpoint = dashboardDomain`, `flags.enable_integration_api = false` |
| Unstable delta | Settings default also sets `flags.disable_signup_without_invite = true` (wiki still warns you must set invite/org flags yourself on older defaults) |
| Secrets | Optional `environmentFile` (e.g. `SERVER_SECRET=…`) |
| Hardening | Extensive systemd sandbox; **denies binding** TCP/UDP sockets (`SocketBindDeny`) — listens only as the app binds internally |

Options of note: `baseDomain`, `dashboardDomain` (default `pangolin.${baseDomain}`), `letsEncryptEmail`, `dnsProvider`, `settings`, `openFirewall`, `environmentFile`, `dataDir`.

Source: module `options.services.pangolin` / `systemd.services.pangolin` in `pangolin.nix` (both revisions above).

### 2.2 Gerbil (tunnel manager / WireGuard)

| Item | Behavior |
| --- | --- |
| Package | `pkgs.fosrl-gerbil` |
| User | `gerbil` in `fossorial` |
| Listen | `LISTEN=localhost:${services.gerbil.port}` (default **3004**) |
| Exec | `--reachableAt=http://localhost:3004`, key at `${dataDir}/config/key`, `--remoteConfig=http://localhost:${internal_port}/api/v1/gerbil/get-config` |
| Caps | `CAP_NET_ADMIN`, `CAP_SYS_MODULE` (WireGuard / iptables) |
| Ordering | `after`/`requires` pangolin; `before`/`requiredBy` traefik; `upholds` traefik |
| Post-start | Deletes host `wg0` once and restarts Gerbil (workaround for upstream interface rename / first-boot issue; [fosrl/newt#37](https://github.com/fosrl/newt/issues/37)) |

`services.gerbil.port` / `services.gerbil.environmentFile` are separate options under the same module file.

### 2.3 Traefik (ingress — module takes over `services.traefik`)

When Pangolin is enabled the module sets:

```nix
services.traefik.enable = true;
services.traefik.group = "fossorial";
services.traefik.dataDir = "${cfg.dataDir}/config/traefik";
```

**Static config highlights:**

| Area | Module value |
| --- | --- |
| Dynamic routes | HTTP provider polling `http://localhost:${internal_port}/api/v1/traefik-config` every 5s |
| Entry points | `web` `:80`, `websecure` `:443` (TLS certResolver `letsencrypt`; long read timeout on websecure) |
| ACME | Resolver name **`letsencrypt`**; storage `${dataDir}/config/letsencrypt/acme.json`; production LE directory |
| Challenge | **HTTP-01** on `web` by default; **DNS-01** iff `domains.domain1.prefer_wildcard_cert` (or legacy `traefik.prefer_wildcard_cert`) using `services.pangolin.dnsProvider` |
| File/Docker providers | **Not** configured by the module |
| HTTP/3 | **Not** enabled |
| Dashboard routers | Hard-coded dynamic routers for dashboard / API / WS / optional integration API host `api.${baseDomain}` |

`fossorial` group members: `pangolin`, `gerbil`, `traefik`.

Init PR discussion (author, 2025-07-23): Pangolin is assumed to **own** Traefik; “If the user has a developed Traefik workflow already, they should not use Pangolin.”  
Source: [nixos/pangolin: init (#416148)](https://github.com/NixOS/nixpkgs/pull/416148) timeline.

### 2.4 Badger (Traefik forward-auth plugin)

Pinned in static config:

```nix
experimental.plugins.badger = {
  moduleName = "github.com/fosrl/badger";
  version = "v1.2.0";
};
```

Comment in-module: `# TODO to change this once #437073 is merged.`  
Related PR [nixos/traefik: refactor, add `plugins` option](https://github.com/NixOS/nixpkgs/pull/437073) is **closed unmerged**. Traefik still downloads Badger from the Traefik plugin registry at runtime (not a nix-packaged plugin wire-up in the Pangolin module).

Upstream Docker docs currently recommend Badger **v1.4.x–v1.7.0** depending on page; update guide: [How to Update](https://docs.pangolin.net/self-host/how-to-update).  
Product role: Traefik middleware enforcing Pangolin auth on public resources — [System Architecture](https://docs.pangolin.net/development/system-architecture).

Issue [#528964](https://github.com/NixOS/nixpkgs/issues/528964) reported unavailable Badger `v1.2.0`; maintainers attributed the failure log to DNS/`network is unreachable` rather than a missing artifact, and the issue was closed. Pin remains `v1.2.0` on unstable and 26.05 tips as of this research.

### 2.5 Ports & firewall

`services.pangolin.openFirewall`:

| Channel | TCP | UDP |
| --- | --- | --- |
| Locked / `nixos-26.05` tip | 80, 443 | **51820** only |
| `nixos-unstable` | 80, 443 | **51820** + **21820** |

Official self-host docs: TCP 80/443; UDP **51820** (site tunnels) and **21820** (client relay) when tunneling is used — [DNS & Networking](https://docs.pangolin.net/self-host/dns-and-networking), [Docker Compose](https://docs.pangolin.net/self-host/manual/docker-compose). Relay semantics: [System Architecture — Peer-to-Peer and Relay](https://docs.pangolin.net/development/system-architecture).

Internal localhost ports (not opened by `openFirewall`): Pangolin 3000–3003, Gerbil 3004.

### 2.6 Certificate hooks

| Hook | Mechanism |
| --- | --- |
| Email | `services.pangolin.letsEncryptEmail` (defaults to `security.acme.defaults.email`) |
| HTTP-01 | Default when `prefer_wildcard_cert = false`; challenge entryPoint `web` |
| DNS-01 / wildcard | Set `settings.domains.domain1.prefer_wildcard_cert = true`, set `dnsProvider` (e.g. `"cloudflare"`), and supply Traefik provider env via `services.traefik.environmentFiles` — **asserted** by the module |
| Storage | `${dataDir}/config/letsencrypt/acme.json` (dir owned by `traefik:fossorial`) |
| Resolver name | Always `letsencrypt` in module static config (must match Pangolin `cert_resolver` if customized in YAML) |

Aligns with Fossorial wildcard guide (replace HTTP-01 with Cloudflare DNS-01, prefer_wildcard_cert, Traefik env creds): [Wildcard Domains](https://docs.pangolin.net/self-host/advanced/wild-card-domains).

Module does **not** configure Pangolin’s alternate `acme.cert_mode: pangolin` / built-in authoritative DNS ACME path from [Private Configuration File](https://docs.pangolin.net/self-host/advanced/private-config-file); Traefik ACME is the wired path.

### 2.7 Explicit non-goals / TODOs in module

- Comment: `### TODO: make tunnels declarative by calling API`
- No resource/site/tunnel declarations in the Pangolin module itself (Newt has a separate `blueprint` option — see §4)
- NixOS test `nixos/tests/pangolin.nix` covers startup / ACME wiring; full Newt tunnel path still TODO upstream in that test file

---

## 3. What our standalone Traefik aspect does today

On `francois`, `<services/traefik>` is included from [`machines/francois/default.nix`](../../machines/francois/default.nix). Aspect sources:

- [`modules/services/traefik/default.nix`](../../modules/services/traefik/default.nix)
- [`modules/services/traefik/secrets.nix`](../../modules/services/traefik/secrets.nix)
- App quirks: [`modules/services/niks3/traefik.nix`](../../modules/services/niks3/traefik.nix), [`modules/services/nixbot/traefik.nix`](../../modules/services/nixbot/traefik.nix)

| Concern | Standalone aspect | Pangolin module Traefik |
| --- | --- | --- |
| Entry points | `http` / `https` | `web` / `websecure` |
| Cert resolver | `cloudflare` (DNS-01 always) | `letsencrypt` (HTTP-01 or DNS-01 if wildcard flag) |
| ACME email / storage | Fixed email; `acme.json` under Traefik dataDir | `letsEncryptEmail`; under Pangolin `dataDir/config/letsencrypt` |
| Secrets | Clan vars → sops template `CF_DNS_API_TOKEN` | Operator must set `services.traefik.environmentFiles` for DNS-01 |
| Dynamic config | `den.quirks.traefik` → tmpfiles JSON into `/var/lib/traefik/dynamic` | Pangolin HTTP API provider (+ fixed dashboard routers) |
| Docker provider | Optional when Podman/Docker socket enabled | None |
| HTTP/3 | Enabled on `:443` | Not set |
| Firewall | TCP 80/443, UDP 443 | TCP 80/443; UDP 51820 (+ 21820 on unstable) |
| Group | OCI backend group | `fossorial` |
| dataDir | NixOS Traefik default | `/var/lib/pangolin/config/traefik` |

Public apps today are **Traefik file routers** (`Host(…)` → localhost backends), not Pangolin resources.

---

## 4. Can the module replace standalone Traefik for public HTTPS?

### Verdict

**Yes, as a cutover — not as a merge.** The nixpkgs Pangolin module is designed to be the sole owner of `services.traefik` and to terminate public HTTPS for the Pangolin node (dashboard + resources driven by Pangolin’s Traefik-config API). That matches the standing preference that Pangolin’s Traefik becomes the only ingress.

**It does not force Docker** for the control-plane node on NixOS: packages and units are native. Docker remains Fossorial’s documented default install path and an escape hatch for EE tags / day-0 versions — [Docker Compose](https://docs.pangolin.net/self-host/manual/docker-compose), [Quick Install](https://docs.pangolin.net/self-host/quick-install).

**You cannot keep** `modules/services/traefik`’s staticConfig / file-provider quirks alongside the module without fighting exclusive entryPoints, cert resolvers, `dataDir`, group, and provider sets. Init PR maintainers treat coexistence as out of scope.

### What replacing looks like on `francois`

1. Remove `<services/traefik>` (and stop writing `den.quirks.traefik` routers for niks3/nixbot).
2. Enable `services.pangolin` with `baseDomain`, `letsEncryptEmail`, `openFirewall`, `environmentFile` (`SERVER_SECRET`, setup token per wiki).
3. For Cloudflare wildcard DNS-01 (repo preference): `settings.domains.domain1.prefer_wildcard_cert = true`, `dnsProvider = "cloudflare"`, reuse CF token via `services.traefik.environmentFiles` (same secret shape as today’s sops template).
4. Republish niks3 / nixbot as **Pangolin public HTTP resources** (Blueprints / API / UI) targeting local backends — not Traefik file JSON. Local-vs-Newt attachment is outside this ticket’s module-fit question (see map “Not yet specified”).
5. Open UDP **21820** explicitly if staying on the 26.05-shaped module (lock / 26.05 tip omit it from `openFirewall`).
6. Site peers (e.g. `esquie`) use **`services.newt`**, not the Pangolin module — separate nixpkgs module with optional `blueprint` ([`newt.nix`](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/newt.nix)).

### Gaps that force work (Docker vs extra modules vs overrides)

| Gap | Forces Docker? | Forces extra module / overlay / override? |
| --- | --- | --- |
| Exclusive Traefik ownership / entryPoint & quirk incompatibility | No | Drop/replace standalone Traefik aspect; migrate routes to Pangolin resources |
| No declarative tunnels/resources in `services.pangolin` | No | Blueprints/API/Terraform community providers; Newt `blueprint` on sites |
| Badger pin `v1.2.0` + runtime plugin download; `#437073` unmerged | No | Override `services.traefik.staticConfigOptions.experimental.plugins.badger.version`; keep egress to plugin registry, or wait for nixpkgs Traefik plugins work |
| Flake lock Pangolin **1.21.1** vs unstable/26.05 tip **1.24.0**; Gerbil **1.4.0** vs unstable **1.6.0** | Only if you refuse overlays and need newer-than-nixpkgs day-0/EE | `flake.lock` bump and/or package overlay; Docker only as currency escape hatch |
| UDP **21820** missing from 26.05/`openFirewall` | No | Extra firewall allow; or follow unstable module |
| No HTTP/3 / no Docker provider in module Traefik | No | Optional staticConfig overrides if still required (HTTP/3); Docker provider not needed if OCI apps become Pangolin resources |
| Signup flags on locked defaults | No | Set `settings.flags.disable_signup_without_invite` (unstable default already) |
| Site connectors / machine clients | No | **`services.newt`** (and Olm/CLI elsewhere) — extra modules/packages, still Nix |
| EE image tags / installer-only features | **Yes** (documented Docker path) | Or wait for nixpkgs packaging |

**Bottom line:** For Nix-first public HTTPS on `francois`, the module **can** replace the standalone Traefik aspect. Gaps are **cutover + resource migration + firewall/Badger/version overrides + Newt on remote sites**, not a hard requirement to run Pangolin itself in Docker. Docker is only forced if you need packaging/features nixpkgs does not ship (EE / installer day-0), not because the module fails to configure Traefik for HTTPS.

---

## 5. Sources

### nixpkgs

- <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/pangolin.nix>
- <https://github.com/NixOS/nixpkgs/blob/c5c4a43b0e8056328ec4529f735cabdb8f1942bb/nixos/modules/services/networking/pangolin.nix>
- <https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/networking/pangolin.nix>
- <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/newt.nix>
- <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/tests/pangolin.nix>
- <https://github.com/NixOS/nixpkgs/pull/416148>
- <https://github.com/NixOS/nixpkgs/pull/437073>
- <https://github.com/NixOS/nixpkgs/issues/528964>
- <https://wiki.nixos.org/wiki/User:Jackrosenberg/Pangolin>

### Pangolin / Fossorial

- <https://docs.pangolin.net/development/system-architecture>
- <https://docs.pangolin.net/self-host/manual/docker-compose>
- <https://docs.pangolin.net/self-host/dns-and-networking>
- <https://docs.pangolin.net/self-host/advanced/wild-card-domains>
- <https://docs.pangolin.net/self-host/how-to-update>
- <https://docs.pangolin.net/self-host/advanced/private-config-file>

### This repo

- [`flake.lock`](../../flake.lock) / [`flake.nix`](../../flake.nix)
- [`machines/francois/default.nix`](../../machines/francois/default.nix)
- [`modules/services/traefik/`](../../modules/services/traefik/)
- [`modules/services/niks3/traefik.nix`](../../modules/services/niks3/traefik.nix)
- [`modules/services/nixbot/traefik.nix`](../../modules/services/nixbot/traefik.nix)
- Prior product research: [`docs/research/pangolin-vs-netbird.md`](./pangolin-vs-netbird.md)
