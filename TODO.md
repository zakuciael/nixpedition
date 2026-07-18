- Refactor terranix module to split configurations that require "waitable" resources and does that do not.
  For example setting up cloudflare resources (e.g. DNS records) doesn't require waiting for any internal resources to succeed.
  But `zitadel` provider requires a Zitdel server to be present, thus it needs to wait for it to become available.
