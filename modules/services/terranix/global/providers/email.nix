{
  flake.terranixModules.email-dns-provider =
    {
      config,
      lib,
      utils,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        mkOption
        types
        concatStringsSep
        attrsToList
        listToAttrs
        optional
        concatLists
        foldl'
        recursiveUpdate
        imap
        stringToCharacters
        optionalString
        filter
        concatLines
        ;
      inherit (lib.tf) ref;
      inherit (utils) mkCfZoneIdRef;

      mkResourceName = name: suffix: "email-${name}-${suffix}";

      mkEscapedContent = content: ''"${content}"'';

      mkMxRecords = name: cfg: {
        cloudflare_dns_record =
          cfg.mx_records
          |> imap (
            index: { server, priority }: {
              name = mkResourceName name "mx-${toString index}";
              value = {
                zone_id = mkCfZoneIdRef cfg.zone_name;
                name = cfg.zone_name;
                type = "MX";
                content = server;
                inherit priority;
                proxied = false;
                ttl = 1;
              };
            }
          )
          |> listToAttrs;
      };

      mkSpfRecord = name: cfg: {
        cloudflare_dns_record."${mkResourceName name "spf"}" = {
          zone_id = mkCfZoneIdRef cfg.zone_name;
          name = cfg.zone_name;
          type = "TXT";
          content = mkEscapedContent "v=spf1 ${concatStringsSep " " cfg.spf.terms} ${cfg.spf.policy}";
          proxied = false;
          ttl = 1;
        };
      };

      mkTlsRptRecord = name: cfg: {
        cloudflare_dns_record."${mkResourceName name "tls_rpt"}" = {
          zone_id = mkCfZoneIdRef cfg.zone_name;
          name = "_smtp._tls";
          type = "TXT";
          content = mkEscapedContent "v=TLSRPTv1; rua=${concatStringsSep "," cfg.tls_rpt.rua}";
          proxied = false;
          ttl = 1;
        };
      };

      mkAutodiscoverRecord =
        name: cfg:
        let
          inherit (cfg.autodiscover)
            proto
            priority
            weight
            port
            target
            ;
        in
        {
          cloudflare_dns_record."${mkResourceName name "autodiscover"}" = {
            zone_id = mkCfZoneIdRef cfg.zone_name;
            name = "_autodiscover._${proto}";
            type = "SRV";
            proxied = false;
            ttl = 1;
            inherit priority;
            data = {
              inherit
                priority
                weight
                port
                target
                ;
            };
          };
        };

      mkDmarcRecord =
        name: cfg:
        let
          inherit (cfg.dmarc)
            policy
            alignment
            reports
            ;

          # This works since we have type checking on the option
          toAligment = value: builtins.head (stringToCharacters value);
        in
        {
          cloudflare_dns_record."${mkResourceName name "dmarc"}" = {
            zone_id = mkCfZoneIdRef cfg.zone_name;
            name = "_dmarc";
            type = "TXT";
            content =
              [
                "v=DMARC1;"
                "p=${policy.global};"
                "sp=${policy.subdomain};"
                "np=${policy.non_existent_subdomain};"
                "adkim=${toAligment alignment.dkim};"
                "aspf=${toAligment alignment.spf};"
                (optionalString (reports.aggregate != [ ]) "rua=${concatStringsSep "," reports.aggregate};")
                (optionalString (reports.forensic != [ ]) "ruf=${concatStringsSep "," reports.forensic};")
              ]
              |> filter (v: v != "")
              |> concatStringsSep " "
              |> mkEscapedContent;
            proxied = false;
            ttl = 1;
          };
        };

      mkDkimRecords =
        name: cfg:
        let
          zone_id = mkCfZoneIdRef cfg.zone_name;
        in
        {
          cloudflare_dns_record =
            cfg.dkim
            |> imap (
              index: record: {
                name = mkResourceName name "dkim-${toString index}";
                value = {
                  inherit (record) type;
                  inherit zone_id;
                  name = "${record.selector}._domainkey";
                  content = if record.type == "TXT" then (mkEscapedContent record.content) else record.content;
                  proxied = false;
                  ttl = 1;
                };
              }
            )
            |> listToAttrs;
        };

      mkMtaStsPolicy =
        name: cfg:
        let
          inherit (cfg.mta_sts) mode max_age mx_patterns;

          account_id = ref "var.cf-account-id";
          resource_name = mkResourceName name "mta_sts";
          namespace_id = ref "cloudflare_workers_kv_namespace.${resource_name}.id";

          policy_content = ''
            version: STSv1
            mode: ${mode}
            max_age: ${toString max_age}
            ${mx_patterns |> map (v: "mx: ${v}") |> concatLines}
          '';
          policy_hash = builtins.substring 0 12 (builtins.hashString "sha1" policy_content);
          script_content = /* JavaScript */ ''
            export default {
              async fetch(request, env, ctx) {
                const url = new URL(request.url);

                if (url.pathname !== '/.well-known/mta-sts.txt')
                  return new Response("Not Found", {
                    status: 404,
                    headers: { "Content-Type": "text/plain" }
                  });

                const response = await env.FILES.get('mta-sts.txt');

                if (response)
                  return new Response(response, {
                    status: 200,
                    headers: { "Content-Type": "text/plain" }
                  });
              },
            };
          '';
          script_file = pkgs.writeText "mta-sts.js" script_content;
        in
        {
          cloudflare_dns_record = {
            "${resource_name}" = {
              zone_id = mkCfZoneIdRef cfg.zone_name;
              name = "_mta-sts";
              type = "TXT";
              content = mkEscapedContent "v=STSv1; id=${policy_hash}";
              proxied = false;
              ttl = 1;
            };
          };

          cloudflare_workers_kv_namespace."${resource_name}" = {
            title = "mta-sts.${cfg.zone_name}";
            inherit account_id;
          };
          cloudflare_workers_kv."${resource_name}" = {
            inherit namespace_id account_id;
            key_name = "mta-sts.txt";
            value = policy_content;
          };
          cloudflare_worker."${resource_name}" = {
            inherit account_id;
            name = "mta-sts-${ref ''replace("${cfg.zone_name}", "/[^A-Za-z0-9-]/", "-")''}";
          };
          cloudflare_worker_version."${resource_name}" = {
            inherit account_id;
            worker_id = ref "cloudflare_worker.${resource_name}.name";
            main_module = "mta-sts.js";
            modules = [
              {
                name = "mta-sts.js";
                content_type = "application/javascript+module";
                content_file = "${script_file}";
              }
            ];

            bindings = [
              {
                type = "kv_namespace";
                name = "FILES";
                inherit namespace_id;
              }
            ];
          };
          cloudflare_workers_deployment."${resource_name}" = {
            inherit account_id;
            script_name = ref "cloudflare_worker.${resource_name}.name";
            strategy = "percentage";

            versions = [
              {
                percentage = 100;
                version_id = ref "cloudflare_worker_version.${resource_name}.id";
              }
            ];
          };
          cloudflare_workers_custom_domain."${resource_name}" = {
            inherit account_id;
            zone_id = mkCfZoneIdRef cfg.zone_name;
            hostname = "mta-sts.${cfg.zone_name}";
            service = ref "cloudflare_worker.${resource_name}.name";
            depends_on = [ "cloudflare_workers_deployment.${resource_name}" ];
          };
        };
    in
    {
      options.email = mkOption {
        default = { };
        type = types.attrsOf (
          types.submodule {
            options = {
              zone_name = mkOption {
                description = "The name of the Cloudflare Zone";
                type = types.str;
              };
              mx_records = mkOption {
                description = "A list of the MX records";
                type = types.listOf (
                  types.submodule {
                    options = {
                      server = mkOption {
                        description = "The domain of the mail server";
                        type = types.str;
                      };
                      priority = mkOption {
                        description = "The priority of the mail server";
                        type = types.ints.unsigned;
                      };
                    };
                  }
                );
              };
              spf = mkOption {
                description = "Configuration for the SPF record";
                type = types.submodule {
                  options = {
                    terms = mkOption {
                      description = ''
                        The SPF term follows the following structure:
                          `[qualifier]mechanism ...`

                          - Qualifier	`+`, `-`, `~`, `?` - Determines action (pass, fail, softfail, neutral)
                          - Mechanism	`ip4:`, `mx`, `include:`, `a:` - Defines authorized senders
                      '';
                      type = types.listOf types.str;
                    };
                    policy = mkOption {
                      description = ''
                        SPF “all” policy advises receivers how to treat emails sent on behalf of you, but the senders are not specified on the record.
                          Allow (+all): emails will be accepted
                          Soft fail (~all): emails will be accepted but might be marked as Spam or insecure.
                          Fail (-all): emails will be rejected
                      '';
                      type = types.enum [
                        "+all"
                        "~all"
                        "-all"
                      ];
                    };
                  };
                };
              };
              mta_sts = mkOption {
                description = "Configuration for the MTA-STS policy";
                type = types.submodule {
                  options = {
                    mode = mkOption {
                      description = "The policy mode";
                      default = "testing";
                      type = types.enum [
                        "enforce"
                        "testing"
                        "none"
                      ];
                    };
                    max_age = mkOption {
                      description = "Policy cache duration in seconds";
                      default = 86400;
                      type = types.ints.unsigned;
                    };
                    mx_patterns = mkOption {
                      description = "List of hosts authorized by the policy";
                      type = types.listOf types.str;
                    };
                  };
                };
              };
              tls_rpt = mkOption {
                description = "Configuration for the TLS-RPT record";
                type = types.submodule {
                  options = {
                    rua = mkOption {
                      description = "A list of report destinations";
                      type = types.listOf types.str;
                    };
                  };
                };
              };
              dmarc = mkOption {
                description = "Configuration for the DMARC record";
                type = types.submodule {
                  options = {
                    policy = mkOption {
                      type = types.submodule (
                        { config, ... }: {
                          options = {
                            global = mkOption {
                              description = "The policy for handling of unauthenticated emails";
                              type = types.enum [
                                "none"
                                "quarantine"
                                "reject"
                              ];
                            };
                            subdomain = mkOption {
                              description = "Specific policy for subdomains if different";
                              default = config.global;
                              type = types.enum [
                                "none"
                                "quarantine"
                                "reject"
                              ];
                            };
                            non_existent_subdomain = mkOption {
                              description = "Specific policy for non-existent subdomains if different";
                              default = config.global;
                              type = types.enum [
                                "none"
                                "quarantine"
                                "reject"
                              ];
                            };
                          };
                        }
                      );
                    };
                    alignment = mkOption {
                      type = types.submodule {
                        options = {
                          spf = mkOption {
                            description = ''
                              SPF/From domain match
                              strict - s
                              relaxed - r (default)
                            '';
                            default = "relaxed";
                            type = types.enum [
                              "strict"
                              "relaxed"
                            ];
                          };
                          dkim = mkOption {
                            description = ''
                              DKIM/From domain match
                              strict - s
                              relaxed - r (default)
                            '';
                            default = "relaxed";
                            type = types.enum [
                              "strict"
                              "relaxed"
                            ];
                          };
                        };
                      };
                    };
                    reports = mkOption {
                      type = types.submodule {
                        options = {
                          aggregate = mkOption {
                            description = "A list of Daily XML report destinations";
                            type = types.listOf types.str;
                          };
                          forensic = mkOption {
                            description = "A list of Per-message report destinations";
                            type = types.listOf types.str;
                          };
                        };
                      };
                    };
                  };
                };
              };
              dkim = mkOption {
                description = "Static DKIM DNS records (optional; OVH-backed DKIM can be inlined elsewhere)";
                default = [ ];
                type = types.listOf (
                  types.submodule {
                    options = {
                      selector = mkOption {
                        description = "The DKIM selector";
                        type = types.str;
                      };
                      type = mkOption {
                        description = "The type of the DNS record";
                        type = types.enum [
                          "TXT"
                          "CNAME"
                        ];
                      };
                      content = mkOption {
                        description = "The content of the DNS record";
                        type = types.str;
                      };
                    };
                  }
                );
              };
              autodiscover = mkOption {
                type = types.submodule {
                  options = {
                    proto = mkOption {
                      description = "The transport protocol of the desired service; this is usually either TCP or UDP.";
                      type = types.enum [
                        "tcp"
                        "udp"
                      ];
                    };
                    priority = mkOption {
                      description = "The priority of the target host, lower value means more preferred.";
                      type = types.ints.unsigned;
                    };
                    weight = mkOption {
                      description = "A relative weight for records with the same priority, higher value means higher chance of getting picked.";
                      type = types.ints.unsigned;
                    };
                    port = mkOption {
                      description = "The TCP or UDP port on which the service is to be found.";
                      type = types.port;
                    };
                    target = mkOption {
                      description = "The canonical hostname of the machine providing the service, ending in a dot.";
                      type = types.str;
                    };
                  };
                };
              };
            };
          }
        );
      };

      config = {
        terraform.required_providers.email = {
          source = "zakuciael/email";
          version = "0.1.0";
        };

        provider."email" = {
          cloudflare_api_token = config.provider."cloudflare".api_token;
          ovh_endpoint = config.provider."ovh".endpoint;
          ovh_client_id = config.provider."ovh".client_id;
          ovh_client_secret = config.provider."ovh".client_secret;
        };

        resource =
          config.email
          |> attrsToList
          |> map (
            { name, value }:
            (
              [
                (mkMxRecords name value)
                (mkSpfRecord name value)
                (mkMtaStsPolicy name value)
                (mkTlsRptRecord name value)
                (mkDmarcRecord name value)
                (mkAutodiscoverRecord name value)
              ]
              ++ optional (value.dkim != [ ]) (mkDkimRecords name value)
            )
          )
          |> concatLists
          |> foldl' (acc: val: recursiveUpdate acc val) { };
      };
    };

  perSystem =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      provider = config.packages.terraform-provider-email;
      tofuRc = pkgs.writeText "tofu.rc" ''
        provider_installation {
          filesystem_mirror {
            path    = "${provider}/libexec/terraform-providers"
            include = ["zakuciael/email"]
          }
          direct {
            exclude = ["zakuciael/email"]
          }
        }
      '';
    in
    {
      terranix.terranixConfigurations.nixpedition = {
        terraformWrapper.prefixText = lib.mkBefore ''
          export TF_CLI_CONFIG_FILE="${tofuRc}"
        '';
      };
    };
}
