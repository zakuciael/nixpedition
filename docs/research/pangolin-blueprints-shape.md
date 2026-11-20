# Pangolin Blueprints shape — public HTTP, Newt, private SSH

Research for nixpedition Wayfinder ticket *Blueprints for public HTTP, Newt, SSH*.  
Research date: 2026-11-20. Sources are official Pangolin docs and first-party `fosrl/pangolin` blueprint schema/code only.

**Question**

What Blueprint (or equivalent declarative) shape covers: (1) public HTTP resources for niks3 and nixbot on `francois` without SSO, (2) a Newt Site on `esquie`, (3) private SSH resources for `francois` and `esquie` granted to an admin/CI identity — and how does that compose with Nix-generated config?

**Standing preferences (from map)**

- Blueprints from Nix; niks3/nixbot public without Pangolin SSO; Newt Site on `esquie`; deny-by-default private SSH grants.
- Today’s Traefik routers: `modules/services/niks3/traefik.nix`, `modules/services/nixbot/traefik.nix`.

---

## Verdict

One org-level YAML Blueprint with three top-level sections covers the cases:

| Case | Blueprint section | Shape |
| --- | --- | --- |
| Public niks3 / nixbot (no SSO) | `public-resources` | `mode: http`, `full-domain`, `auth.sso-enabled: false`, `targets` on a **Local Site** pointing at loopback/`httpAddr` |
| Newt on `esquie` | Site **outside** Blueprint create path; optional `sites.esquie` settings only | Create/provision Pangolin Site → run Newt with `id` / `secret` / `endpoint`; Blueprint `sites:` only sets `name` + `docker-socket-enabled` |
| Private SSH for deploy/CI | `private-resources` | Prefer `mode: host`, `destination: localhost` (or site-reachable host), `tcp-ports: "22"`, `alias`, explicit `roles` / `users` / `machines` — **Pangolin Site required** (Local Site cannot host private resources) |

Nix generates that YAML (`pkgs.formats.yaml` / attrset merge mirroring today’s Traefik fragments) and applies it via CLI/API (org-wide) and/or `--blueprint-file` on sites (continuous source of truth). Site credentials and Local Site creation are not minted by Blueprints; they are provisioning/API/dashboard inputs referenced by stable site identifiers (`niceId`).

---

## 1. Blueprint mental model (primary)

A Blueprint may contain up to four top-level sections:

- `public-resources` (alias `proxy-resources`) — internet-facing HTTP/TCP/UDP/SSH/RDP/VNC/…
- `private-resources` (alias `client-resources`) — client-only ZTNA
- `public-policies` — reusable public auth/rules (**shared policies are Pangolin Cloud / Enterprise**)
- `sites` — site-level settings (not full site lifecycle)

Keys under those maps are stable identifiers (`niceId`); later applies match and update by key.

Sources: [Blueprints](https://docs.pangolin.net/manage/blueprints) (mental model + apply paths); [Resource policies](https://docs.pangolin.net/manage/resources/public/resource-policies) (shared policies Cloud/EE only).

**Apply paths**

| Method | Behavior |
| --- | --- |
| Site `--blueprint-file` / container labels | Ongoing source of truth (dashboard edits can be overwritten) |
| `--provisioning-blueprint-file` | One-shot at site provision |
| Dashboard paste / API `PUT /org/{orgId}/blueprint` / CLI `pangolin apply blueprint` | One-off apply |

Source: [Blueprints — How YAML Blueprints Are Applied](https://docs.pangolin.net/manage/blueprints#how-yaml-blueprints-are-applied), [Site provisioning](https://docs.pangolin.net/manage/sites/site-provisioning).

Schema note: `sites` entries are only `{ name, docker-socket-enabled? }` — they do not create Newt credentials.

Source: [`server/lib/blueprints/types.ts` `SiteSchema`](https://github.com/fosrl/pangolin/blob/71f45b8a/server/lib/blueprints/types.ts).

---

## 2. Public HTTP without SSO (niks3, nixbot on `francois`)

### Resource type

Public HTTP resources are reverse proxies with an FQDN; users open them in a browser (no Pangolin client). Targets name site + upstream host/port/method.

Sources: [Understanding Resources](https://docs.pangolin.net/manage/resources/understanding-resources), [HTTP / HTTPS](https://docs.pangolin.net/manage/resources/public/http-https), [Blueprints — HTTP example](https://docs.pangolin.net/manage/blueprints#http-resource-example).

### Auth / SSO off

- UI docs: Platform SSO is **on by default** for public resources.
- Blueprint field: `auth.sso-enabled` (boolean). AuthSchema defaults the field to `false` when parsed; apply code writes policy/resource SSO from `auth["sso-enabled"]` (`?? false` / `|| false` paths).
- For nixpedition: set **`auth.sso-enabled: false`** explicitly on each public HTTP resource and omit PIN/password/basic/mTLS/whitelist unless wanted.

Sources: [Authentication (public)](https://docs.pangolin.net/manage/resources/public/authentication); [Blueprints — Auth object](https://docs.pangolin.net/manage/blueprints); [`AuthSchema` / sync in `types.ts` + `publicResources.ts`](https://github.com/fosrl/pangolin/blob/71f45b8a/server/lib/blueprints/types.ts).

Optional alternative: ranked `rules` with `action: allow` to **bypass** auth for matching requests without turning SSO off globally on the resource — useful for path carve-outs, not the preferred whole-app public model.

Source: [Rules](https://docs.pangolin.net/manage/access-control/rules).

### Where the backend lives on `francois`

Self-hosted **Local Site**: same host as Pangolin; no tunnel; supports public HTTP/TCP/UDP (and AI Gateway) only — **not** private resources, health checks, or Docker socket scanning.

Sources: [Understanding Sites — Local Site](https://docs.pangolin.net/manage/sites/understanding-sites), [Understanding Resources — site compatibility](https://docs.pangolin.net/manage/resources/understanding-resources), [Without Tunneling](https://docs.pangolin.net/self-host/advanced/without-tunneling).

Mapping from today’s Traefik modules:

| Service | Today | Blueprint target |
| --- | --- | --- |
| nixbot | `http://localhost:${port}` | `hostname: localhost` (or `127.0.0.1`), `port: <nixbot port>`, `method: http`, `site: francois-local` |
| niks3 | `http://${cfg.httpAddr}` (`0.0.0.0:${port}` in module) | Same Local Site; use a loopback-reachable address Pangolin can dial (prefer `127.0.0.1` + listen binding that accepts it, or the concrete listen IP Traefik used) |

`full-domain` should be the same public names already in host constants / Cloudflare records (niks3 write/API `domain`; nixbot `domain`). Public binary-cache `cacheDomain` is served via R2 custom domain in this repo’s Terranix — it is **not** the Traefik router in `niks3/traefik.nix`; do not assume it must become a Pangolin public resource unless cutover scope expands.

---

## 3. Newt Site on `esquie`

**Newt** is the lightweight site connector (same tunneling as a Pangolin Site without the full CLI). New installs may use Pangolin CLI; Newt remains supported for the smallest binary/container. Dashboard shows which agent a site uses.

You must **create a site and copy Newt config** (id, secret, endpoint) before running Newt — or use a **provisioning key** so the site exchanges `spk_…` for id/secret on first connect.

Sources: [Install Newt](https://docs.pangolin.net/manage/sites/install-newt), [Understanding Sites](https://docs.pangolin.net/manage/sites/understanding-sites), [Site Provisioning Keys](https://docs.pangolin.net/manage/sites/site-provisioning).

Typical NixOS shape (from upstream systemd example): env file with `NEWT_ID`, `NEWT_SECRET`, `PANGOLIN_ENDPOINT`; unit `ExecStart=newt`. Optional `--blueprint-file` / provisioning blueprint for site-local continuous/bootstrap apply.

**Blueprint `sites.esquie`** only documents/enables settings such as `docker-socket-enabled` (default true in schema). It does **not** replace Newt install or credential distribution. Prefer leaving Docker socket discovery off on NixOS hosts that do not run labeled Compose stacks (`docker-socket-enabled: false`).

---

## 4. Private SSH for `francois` and `esquie` (admin / CI)

### Deny-by-default

Private resources require a connected Pangolin client. **No access until** roles, users, or machines are granted. Empty grants ⇒ clients see nothing for that resource.

Sources: [Understanding Resources](https://docs.pangolin.net/manage/resources/understanding-resources), [Private authentication](https://docs.pangolin.net/manage/resources/private/authentication).

### Site requirement (important for `francois`)

Private resources **require a Pangolin Site**. Local Site and Basic WireGuard Site **cannot** host them.

So: Local Site on `francois` is enough for public niks3/nixbot, but **private SSH to `francois` needs a Newt/CLI Pangolin Site on `francois` (or another Pangolin Site that can reach its SSH)** in addition to Local — preferences only mandate Newt on `esquie`, but the product model forces a Pangolin Site wherever private resources attach.

Source: [Understanding Resources — private site compatibility](https://docs.pangolin.net/manage/resources/understanding-resources).

### Recommended shape for clan/CI OpenSSH

Prefer **`mode: host`** (native SSH client over the tunnel), not public browser SSH and not necessarily private `mode: ssh`:

```yaml
private-resources:
  francois-ssh:
    name: francois SSH
    mode: host
    sites: [francois]          # Pangolin Site niceId on francois
    destination: localhost     # SSH on the site connector host
    tcp-ports: "22"            # custom allow-list; default would be "*"
    udp-ports: ""              # or omit / block UDP as desired
    disable-icmp: true
    alias: francois.pangolin.internal   # required pattern when using loopback from clients
    roles: [AdminOps]          # custom role — cannot list reserved Admin in blueprint roles
    users: []                  # or explicit admin emails
    machines: [hercules-ci]    # CI Olm/machine client id
```

- Loopback destinations need an **alias** so clients do not hit their own localhost.
- Port restrictions: custom TCP `22` matches least-privilege SSH; default TCP/UDP is all ports if unrestricted.
- `Admin` role name is reserved and **cannot** appear in blueprint `roles` / `sso-roles` lists — use a custom role or `users` / `machines`.

Sources: [Host private resources](https://docs.pangolin.net/manage/resources/private/host), [Ports and ICMP](https://docs.pangolin.net/manage/resources/private/port-restrictions), [Blueprints — private resources](https://docs.pangolin.net/manage/blueprints#private-resources), provisioning example with `destination: localhost` + `tcp-ports: "22,…"` in [Site provisioning](https://docs.pangolin.net/manage/sites/site-provisioning).

### Alternate: `mode: ssh`

Private `mode: ssh` is for Pangolin SSH workflows (`pangolin ssh`, auth-daemon / PAM). Suitable when adopting Pangolin identity→host provisioning; heavier than “tunnel to existing OpenSSH” for current `clan machine update` / CI.

Sources: [SSH Access](https://docs.pangolin.net/manage/ssh), [Private SSH](https://docs.pangolin.net/manage/resources/private/ssh), Blueprints `auth-daemon` object.

### Public SSH (out of preferred path)

Public `mode: ssh` is browser FQDN SSH with public auth — not the deny-by-default private deploy path.

Source: [Public SSH](https://docs.pangolin.net/manage/resources/public/ssh).

---

## 5. Concrete sketched Blueprint (three cases)

Identifiers (`francois-local`, `francois`, `esquie`, domains, role/machine names) are placeholders for real `niceId`s and clan constants.

```yaml
# Generated from Nix — org-wide desired state for nixpedition Pangolin
public-resources:
  niks3:
    name: niks3
    mode: http
    full-domain: niks3.example.com          # host.constants.services.niks3.domain
    enabled: true
    auth:
      sso-enabled: false
    targets:
      - site: francois-local                # Local Site on control plane host
        hostname: 127.0.0.1
        port: 8080                          # niks3 listen port from constants
        method: http

  nixbot:
    name: nixbot
    mode: http
    full-domain: nixbot.example.com         # host.constants.services.nixbot.domain
    enabled: true
    auth:
      sso-enabled: false
    targets:
      - site: francois-local
        hostname: 127.0.0.1
        port: 3000                          # nixbot port from constants
        method: http

private-resources:
  francois-ssh:
    name: francois SSH
    mode: host
    sites:
      - francois                            # Pangolin Site (Newt/CLI) on francois
    destination: localhost
    tcp-ports: "22"
    udp-ports: ""
    disable-icmp: true
    alias: francois.internal.example
    roles:
      - Ops
    machines:
      - hercules-ci

  esquie-ssh:
    name: esquie SSH
    mode: host
    sites:
      - esquie                              # Newt site on esquie
    destination: localhost
    tcp-ports: "22"
    udp-ports: ""
    disable-icmp: true
    alias: esquie.internal.example
    roles:
      - Ops
    machines:
      - hercules-ci

sites:
  esquie:
    name: esquie
    docker-socket-enabled: false
  francois:
    name: francois
    docker-socket-enabled: false
```

Notes:

- Create Local Site `francois-local` and Pangolin Sites `francois` / `esquie` (or provision Newt) **before** or beside first apply so site keys resolve.
- Omit `public-policies` on self-hosted CE unless running EE/Cloud shared policies; keep auth inline (`auth.sso-enabled: false`).
- Do not put Newt secrets, API keys, or SSH host keys in the Blueprint file.

---

## 6. Composition with Nix-generated config

### Generate

Mirror the existing Traefik aspect pattern: small per-service Nix fragments that contribute Blueprint attrsets (niks3/nixbot → `public-resources.*`; host/site modules → `private-resources.*` + `sites.*`), merged on `francois` into one YAML via `pkgs.formats.yaml.generate` (or `lib.generators.toYAML`).

Domains/ports come from the same `host.constants` / clan vars the Traefik modules already read.

### Apply (recommended layering)

1. **Org Blueprint (primary for nixpedition):** activation or CI on `francois` runs  
   `pangolin apply blueprint --file … --api-key … --endpoint … --org …`  
   (or API `PUT /org/{orgId}/blueprint` with base64 JSON). One-off per deploy/generation; fits “Blueprints from Nix” without requiring Docker labels.
2. **Site continuous (optional):** Newt/CLI on `esquie` (and `francois` site) with `--blueprint-file` only if that host should own a slice as ongoing SoT — otherwise keep a single org file to avoid split-brain.
3. **Bootstrap:** provisioning key + optional `--provisioning-blueprint-file` for first Newt connect; switch to org apply or `--blueprint-file` for steady state.

Sources: [Blueprints apply / CLI / API](https://docs.pangolin.net/manage/blueprints), [Site provisioning](https://docs.pangolin.net/manage/sites/site-provisioning).

### What stays outside the YAML

| Concern | Mechanism |
| --- | --- |
| Local Site on `francois` | Dashboard/API once (or automation); referenced as `site:` on HTTP targets |
| Newt id/secret/endpoint or provisioning key | clan vars / secrets → Newt env; not Blueprint |
| Integration API key for apply | clan vars on `francois` / CI |
| Olm/machine client for Hercules CI | separate research ticket; grant via `machines:` / roles once id exists |
| TLS for public FQDNs | Pangolin/Traefik + Cloudflare DNS-01 (other ticket) |

### Relation to retiring Traefik modules

`modules/services/*/traefik.nix` routers become Blueprint `public-resources` entries targeting Local Site; Pangolin’s bundled Traefik becomes the edge. No need for Compose label Blueprints on these NixOS services.

---

## 7. Implications for later tickets

- **francois site dualism:** Local Site (public HTTP) + Pangolin Site (private SSH) on the control-plane host.
- **Aspect layout:** generate/merge Blueprint near services; Newt aspect on `esquie`; apply hook on `francois`.
- **targetHost naming:** private host `alias` values are the natural clan/`deploy` hostnames once Olm is up — grill separately.
- **CI:** grant the Olm machine id on both SSH host resources; do not open public SSH for deploy.

---

## Primary sources (index)

1. [Blueprints](https://docs.pangolin.net/manage/blueprints) — schema, apply, HTTP/private examples, auth fields, sites object  
2. [Understanding Resources](https://docs.pangolin.net/manage/resources/understanding-resources) — public vs private; site compatibility  
3. [Understanding Sites](https://docs.pangolin.net/manage/sites/understanding-sites) — Pangolin Site vs Local vs WireGuard  
4. [Install Newt](https://docs.pangolin.net/manage/sites/install-newt) — Newt run/systemd/env  
5. [Site Provisioning Keys](https://docs.pangolin.net/manage/sites/site-provisioning) — bootstrap + blueprint flags + localhost SSH example  
6. [Authentication (public)](https://docs.pangolin.net/manage/resources/public/authentication) — default SSO  
7. [Authentication (private)](https://docs.pangolin.net/manage/resources/private/authentication) — deny-by-default grants  
8. [Host (private)](https://docs.pangolin.net/manage/resources/private/host) — loopback + alias  
9. [Ports and ICMP](https://docs.pangolin.net/manage/resources/private/port-restrictions) — custom TCP ports  
10. [SSH Access](https://docs.pangolin.net/manage/ssh) / [Private SSH](https://docs.pangolin.net/manage/resources/private/ssh) — `mode: ssh` alternative  
11. [Rules](https://docs.pangolin.net/manage/access-control/rules) — allow bypass vs SSO flag  
12. [Resource policies](https://docs.pangolin.net/manage/resources/public/resource-policies) — shared policies Cloud/EE  
13. [fosrl/pangolin `server/lib/blueprints/types.ts`](https://github.com/fosrl/pangolin/blob/71f45b8a/server/lib/blueprints/types.ts) — AuthSchema / SiteSchema  
14. [fosrl/pangolin `server/lib/blueprints/publicResources.ts`](https://github.com/fosrl/pangolin/blob/71f45b8a/server/lib/blueprints/publicResources.ts) — `sso-enabled` apply behavior  
15. Prior product context: [`docs/research/pangolin-vs-netbird.md`](./pangolin-vs-netbird.md) (when present on the reading branch)
