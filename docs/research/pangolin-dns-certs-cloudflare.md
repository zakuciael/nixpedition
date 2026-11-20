# Pangolin DNS and certs with Cloudflare (zakku.eu)

Independent primary-source research for public niks3/nixbot cutover onto Pangolin’s edge on `francois`, given existing Cloudflare/terranix DNS for `zakku.eu`.  
Research date: 2026-11-20. Sources are Pangolin docs, Traefik/Lego ACME docs, and this repo’s terranix/Traefik modules only. No live DNS or terranix config was changed.

**Question**

With Pangolin’s edge on `francois` and existing Cloudflare/terranix DNS for `zakku.eu`, what DNS records (wildcard vs per-name) and cert resolver setup are required for public niks3/nixbot cutover, and what breaks if we keep today’s per-host A/AAAA records pointing at `francois`?

**Standing preferences (from plan / prior design)**

- Prefer Cloudflare DNS-01 on the Pangolin edge.
- Privacy bar: no service enumeration / no internal IP leak; public wildcard to the VPS is OK.
- Prior product DNS analysis: [`docs/research/pangolin-vs-netbird.md`](pangolin-vs-netbird.md) (§3–4).

---

## 1. Today’s nixpedition DNS and certs (repo facts)

| Name | Role | Terranix / Traefik today |
| --- | --- | --- |
| `niks3.zakku.eu` | niks3 write/API | `cloudflare_dns_record` type **A**, `proxied = true`, content = `local.machine-francois-ipv4` ([`modules/services/niks3/terranix.nix`](../../modules/services/niks3/terranix.nix)) |
| `ci.zakku.eu` | nixbot | Same pattern ([`modules/services/nixbot/terranix.nix`](../../modules/services/nixbot/terranix.nix)) |
| `cache.zakku.eu` | public binary-cache reads | **R2 custom domain**, not an A→francois record ([`modules/services/niks3/terranix.nix`](../../modules/services/niks3/terranix.nix)) |

Domain values (vars): `niks3.zakku.eu`, `ci.zakku.eu`, `cache.zakku.eu`.

**AAAA:** terranix only materializes `machine-francois-ipv4` from OVH VPS IPs (IPv4 filter) ([`modules/services/terranix/global/providers/ovh.nix`](../../modules/services/terranix/global/providers/ovh.nix)). There is **no** AAAA record for niks3/nixbot in-tree. Ticket wording “A/AAAA” is aspirational relative to today’s config.

**Certs today:** standalone Traefik on `francois` uses a resolver named `cloudflare` with `dnsChallenge.provider = "cloudflare"` and ACME storage `acme.json` ([`modules/services/traefik/default.nix`](../../modules/services/traefik/default.nix)). Routers for niks3/nixbot set `tls.certResolver = "cloudflare"`. The API token is injected as `CF_DNS_API_TOKEN` via sops ([`modules/services/traefik/secrets.nix`](../../modules/services/traefik/secrets.nix)).

---

## 2. What Pangolin requires (primary sources)

### 2.1 Self-hosted domain type = wildcard A/AAAA at the DNS provider

For self-hosted Pangolin, the documented domain type is **Wildcard** with **A / AAAA** covering the base and subdomains; DNS stays at your provider (Cloudflare here). Pangolin does not manage those records on self-host.

Sources: [Domains](https://docs.pangolin.net/manage/domains), [DNS & Networking](https://docs.pangolin.net/self-host/dns-and-networking).

Recommended records:

```text
Type: A
Name: *
Value: <francois public IPv4>
```

Optional apex `@` only if the root hostname is used as a resource. AAAA if IPv6 is in use.  
Source: [DNS & Networking — Basic DNS Records](https://docs.pangolin.net/self-host/dns-and-networking).

### 2.2 Wildcard TLS needs DNS-01 (not HTTP-01)

Let’s Encrypt issues wildcards only via DNS-01. Pangolin’s Traefik must use a certificate resolver with `dnsChallenge` (Cloudflare example in docs). Pangolin’s `domains.<id>.cert_resolver` (and/or `traefik.cert_resolver`) must **exactly match** the Traefik resolver name. Set `prefer_wildcard_cert: true` so Pangolin asks Traefik for `*.base` instead of per-hostname certs.

Sources:

- [Wildcard Domains](https://docs.pangolin.net/self-host/advanced/wild-card-domains)
- [Configuration File — domains / traefik](https://docs.pangolin.net/self-host/advanced/config-file)
- Traefik ACME: wildcards require DNS-01 ([Traefik ACME](https://doc.traefik.io/traefik/v3.3/https/acme/))

Documented Cloudflare Traefik shape (resolver name often `letsencrypt` in Pangolin examples):

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      dnsChallenge:
        provider: "cloudflare"
      email: "admin@example.com"
      storage: "/letsencrypt/acme.json"
      caServer: "https://acme-v02.api.letsencrypt.org/directory"
```

Plus Traefik env `CLOUDFLARE_DNS_API_TOKEN` with **Zone:Read** and **DNS:Edit** on the zone.  
Source: [Wildcard Domains — Add DNS provider credentials](https://docs.pangolin.net/self-host/advanced/wild-card-domains).

Lego (Traefik’s ACME DNS lib) accepts `CLOUDFLARE_DNS_API_TOKEN` / `CF_DNS_API_TOKEN` (this repo already uses `CF_DNS_API_TOKEN`). Permissions: Zone/Zone/Read + Zone/DNS/Edit.  
Source: [Lego Cloudflare DNS](https://go-acme.github.io/lego/dns/cloudflare/).

Pangolin domain config sketch for `zakku.eu`:

```yaml
domains:
  zakku:
    base_domain: "zakku.eu"
    prefer_wildcard_cert: true
    cert_resolver: "cloudflare"   # must match Traefik certificatesResolvers key
```

Keeping the resolver name `cloudflare` (today’s Traefik name) is fine; Pangolin examples use `letsencrypt` only as a conventional default. What matters is name equality between Traefik and Pangolin.  
Source: [Wildcard Domains — Choose a resolver strategy](https://docs.pangolin.net/self-host/advanced/wild-card-domains).

### 2.3 Cloudflare orange-cloud (proxied) extras

Today’s niks3/nixbot A records are **proxied**. Pangolin supports Cloudflare proxy with constraints:

1. Wildcard certs via DNS-01 (recommended).
2. SSL/TLS mode **Full (Strict)** only — not Full or Automatic.
3. Port 80 can be disabled when using wildcard certs.
4. Set `gerbil.base_endpoint` to the **real VPS IP** (proxy hides the destination).
5. `server.trust_proxy: 2` and Badger ≥ 1.3.0 for `CF-Connecting-IP`.

Source: [Cloudflare Proxy](https://docs.pangolin.net/self-host/advanced/cloudflare-proxy).

WireGuard site/client UDP ports (51820 / 21820) are separate from HTTP DNS/certs; they must remain reachable on the VPS IP (not through Cloudflare HTTP proxy).  
Source: [DNS & Networking — Port Configuration](https://docs.pangolin.net/self-host/dns-and-networking).

### 2.4 Wildcard *resources* vs wildcard *DNS/certs*

Catch-all Pangolin **wildcard public resources** (`subdomain: *`) are Cloud/Enterprise-only. Self-host still needs wildcard **DNS + DNS-01 certs** for the documented self-host domain model and for `prefer_wildcard_cert`. Day-1 niks3/nixbot are ordinary per-hostname public HTTP resources, not Cloud wildcard resources.

Source: [Wildcard Resources](https://docs.pangolin.net/manage/resources/public/wildcard-resources).

---

## 3. Wildcard DNS vs keep per-host A records

### 3.1 Required vs sufficient for cutover

| Layer | Wildcard `*.zakku.eu` → francois | Keep only per-host A (niks3, ci) → francois |
| --- | --- | --- |
| HTTP(S) reachability for existing public apps | Yes | **Yes** — names already resolve to the edge |
| Pangolin self-host “recommended” DNS | Matches docs | Deviates; still works for listed names |
| New public hostname without a terranix record | Resolves immediately | **NXDOMAIN / no traffic** until a new A/AAAA (or CNAME) is added |
| DNS-01 / wildcard cert issuance | Works (TXT `_acme-challenge`) | **Works** — ACME DNS-01 does not depend on the service A record |
| Per-hostname certs (no `prefer_wildcard_cert`) | Works | Works |
| Privacy: avoid enumerating public service names in the zone | Better (no per-app A rows) | **Worse** — zone lists `niks3`, `ci`, … |
| Privacy: private labels under same base | Any label answers with VPS IP | Unlisted labels do **not** answer; closer to NXDOMAIN for unpublished names |
| `cache.zakku.eu` R2 custom domain | Keep **specific** R2 binding; more-specific names override `*` | Unaffected |

**Verdict for niks3/nixbot cutover:** per-host A→francois is **sufficient for routing those two apps** once Pangolin/Traefik terminate TLS for those Host rules. It is **not** what Pangolin documents as the self-host domain setup, and it fights the standing preference against public service enumeration.

**Recommended shape (research conclusion, not applied):**

1. Add terranix `cloudflare_dns_record` for `*.zakku.eu` → francois IPv4 (and AAAA if/when IPv6 is published), with an explicit proxied/DNS-only policy consistent with Cloudflare Full (Strict) + Gerbil `base_endpoint` requirements.
2. Keep **exception** records that must not hit francois — especially `cache.zakku.eu` (R2) and mail/verification records.
3. Optionally drop or retain explicit `niks3.zakku.eu` / `ci.zakku.eu` A rows; Cloudflare more-specific records override the wildcard. Retaining them is redundant for resolution but harmless; dropping them reduces enumeration only if nothing else lists those names.
4. Do **not** put future private Home-Lab names on the same publicly wild-carded `zakku.eu` if public NXDOMAIN for those labels is required — use aliases / a non-public suffix (prior research §4).

### 3.2 What breaks if we keep today’s per-host records

Nothing in the Pangolin stack **hard-fails** solely because DNS is per-host rather than `*`, for the two already-published names:

- Clients still reach Traefik on `francois` for `niks3.zakku.eu` and `ci.zakku.eu`.
- DNS-01 can still issue `*.zakku.eu` (or per-name) certs via Cloudflare API.

What **does** degrade or break relative to goals:

1. **Zero-touch new public hostnames** — Pangolin resource create ≠ public resolution without a new terranix/DNS change ([DNS & Networking](https://docs.pangolin.net/self-host/dns-and-networking) assumes `*`).
2. **Service enumeration** — explicit A records name every public app in the zone; conflicts with the privacy preference that public wildcard-to-VPS is OK *instead of* listing services.
3. **Dashboard / extra Pangolin hostnames** — e.g. `pangolin.zakku.eu` (or whatever `app.dashboard_url` uses) needs its own record or coverage under `*` ([config file](https://docs.pangolin.net/self-host/advanced/config-file)).
4. **AAAA gap** — there are no AAAA records today; “keep A/AAAA” is moot until IPv6 is published. IPv6-only clients already fail independently of Pangolin.
5. **Proxy + cert mode** — keeping proxied records without moving Traefik to DNS-01 wildcards + Full (Strict) + `gerbil.base_endpoint` breaks or misroutes under Cloudflare proxy ([Cloudflare Proxy](https://docs.pangolin.net/self-host/advanced/cloudflare-proxy)). That is a cert/proxy cutover concern, not a wildcard-vs-per-host concern.

---

## 4. Cert resolver setup required for cutover

Concrete checklist for Pangolin’s Traefik on `francois` (replace standalone Traefik):

| Item | Setting |
| --- | --- |
| Challenge | `dnsChallenge.provider: cloudflare` (replace default HTTP-01) |
| Resolver name | Prefer reuse `cloudflare` to match today’s mental model, **or** Pangolin’s `letsencrypt` — but Pangolin `cert_resolver` must match |
| Wildcard preference | `domains.….prefer_wildcard_cert: true` for `zakku.eu`; optionally `traefik.prefer_wildcard_cert` for UI-created domains |
| Token | Zone Read + DNS Edit; env `CF_DNS_API_TOKEN` / `CLOUDFLARE_DNS_API_TOKEN` (repo already uses `CF_DNS_API_TOKEN`) |
| ACME storage | Traefik `acme.json`; if Pangolin syncs certs, point `acme.acme_json_path` at that file/dir ([config file — ACME](https://docs.pangolin.net/self-host/advanced/config-file)) |
| Cloudflare proxy | Full (Strict); `gerbil.base_endpoint = <VPS IP>`; `trust_proxy: 2`; Badger for real client IP |
| Port 80 | Optional once wildcards + DNS-01 are in place |
| Non-goals for day-1 | Pangolin Cloud NS delegation / CNAME domain types; Enterprise wildcard *resources* |

Cross-check: today’s module already implements the hard part (Cloudflare DNS-01 + token). Cutover is **moving that resolver into Pangolin-managed Traefik** and flipping Pangolin domain flags — not inventing a new ACME path.

---

## 5. Answers (gist)

1. **DNS:** Pangolin self-host docs want `*.zakku.eu` (A, and AAAA if used) → `francois`. For niks3/nixbot alone, existing per-host A→francois records are enough to route those two names. Prefer adding a public wildcard for docs alignment and anti-enumeration; keep `cache.zakku.eu` as the R2 exception.
2. **Certs:** Traefik DNS-01 Cloudflare resolver + Pangolin `cert_resolver` name match + `prefer_wildcard_cert: true`. Reuse `CF_DNS_API_TOKEN` permissions (Zone Read, DNS Edit). With orange-cloud, also Full (Strict) and Gerbil `base_endpoint` = real VPS IP.
3. **If we keep only per-host A:** cutover of the two apps still works; new public names, dashboard hostname coverage, and the “no service enumeration / wildcard OK” privacy bar do not. Cert issuance itself does not break. There are no AAAA records to “keep” today.

---

## Sources

### Pangolin (primary)

- https://docs.pangolin.net/self-host/dns-and-networking
- https://docs.pangolin.net/manage/domains
- https://docs.pangolin.net/self-host/advanced/wild-card-domains
- https://docs.pangolin.net/self-host/advanced/cloudflare-proxy
- https://docs.pangolin.net/self-host/advanced/config-file
- https://docs.pangolin.net/manage/resources/public/wildcard-resources

### ACME / Cloudflare (primary)

- https://doc.traefik.io/traefik/v3.3/https/acme/
- https://go-acme.github.io/lego/dns/cloudflare/

### Repo cross-checks (not normative for Pangolin)

- [`modules/services/niks3/terranix.nix`](../../modules/services/niks3/terranix.nix), [`modules/services/nixbot/terranix.nix`](../../modules/services/nixbot/terranix.nix)
- [`modules/services/traefik/default.nix`](../../modules/services/traefik/default.nix), [`modules/services/traefik/secrets.nix`](../../modules/services/traefik/secrets.nix)
- [`modules/services/terranix/global/providers/ovh.nix`](../../modules/services/terranix/global/providers/ovh.nix)
- Prior: [`docs/research/pangolin-vs-netbird.md`](pangolin-vs-netbird.md)
