{
  flake.terranixModules.emails =
    {
      lib,
      utils,
      config,
      ...
    }:
    let
      inherit (lib)
        foldl'
        recursiveUpdate
        listToAttrs
        attrsToList
        ;
      inherit (lib.tf) ref;
      inherit (utils) mkCfZoneIdRef;
    in
    {
      email =
        [
          {
            name = "personal";
            zone_name = "krzysztofsaczuk.pl";
          }
          {
            name = "system";
            zone_name = "zakku.eu";
          }
        ]
        |> map (
          { name, zone_name }: {
            inherit name;
            value = rec {
              inherit zone_name;
              mx_records = [
                {
                  server = "mx0.mail.ovh.net";
                  priority = 1;
                }
                {
                  server = "mx1.mail.ovh.net";
                  priority = 5;
                }
                {
                  server = "mx2.mail.ovh.net";
                  priority = 50;
                }
                {
                  server = "mx3.mail.ovh.net";
                  priority = 100;
                }
                {
                  server = "mx4.mail.ovh.net";
                  priority = 200;
                }
              ];
              spf = {
                terms = [ "include:mx.ovh.com" ];
                policy = "-all";
              };
              mta_sts = {
                mode = "enforce";
                max_age = 86400;
                mx_patterns = mx_records |> map (v: v.server);
              };
              tls_rpt.rua = [ "mailto:tlsrpt@${zone_name}" ];
              dmarc = {
                policy.global = "reject";
                alignment = {
                  spf = "strict";
                  dkim = "strict";
                };
                reports =
                  let
                    report_emails = [
                      "mailto:${ref "email_cloudflare_dmarc_reports.email-${name}-dmarc.rua_prefix"}@dmarc-reports.cloudflare.net"
                    ];
                  in
                  {
                    forensic = report_emails;
                    aggregate = report_emails;
                  };
              };
              autodiscover = {
                proto = "tcp";
                priority = 0;
                weight = 0;
                port = 443;
                target = "pro1.mail.ovh.net";
              };
            };
          }
        )
        |> listToAttrs;

      resource =
        config.email
        |> attrsToList
        |> map (
          { name, value }:
          let
            inherit (value) zone_name;
            zone_id = mkCfZoneIdRef zone_name;
            dkim_resource_name = "email-${name}-dkim";
            dmarc_resource_name = "email-${name}-dmarc";
          in
          {
            email_ovh_pro_dkim.${dkim_resource_name} = {
              domain = zone_name;
              # provider auto-discovers service for this domain
              service = null;
            };

            email_cloudflare_dmarc_reports.${dmarc_resource_name} = {
              enabled = true;
              inherit zone_id;
            };

            cloudflare_dns_record.${dkim_resource_name} = {
              for_each = ref "toset(email_ovh_pro_dkim.${dkim_resource_name}.selector_names)";
              inherit zone_id;
              name = "\${each.value}._domainkey";
              type = "CNAME";
              content = ref "[for s in email_ovh_pro_dkim.${dkim_resource_name}.selectors : s.content if s.selector == each.value][0]";
              proxied = false;
              ttl = 1;
            };
          }
        )
        |> foldl' (acc: val: recursiveUpdate acc val) { };
    };
}
