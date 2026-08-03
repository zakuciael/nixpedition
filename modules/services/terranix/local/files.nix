{
  services.terranix.terranix.local.configuration =
    { lib, config, ... }:
    let
      inherit (lib) mkOption types;

      mkLocalFile = fileCfg: {
        inherit (fileCfg) content;
        filename = fileCfg.path;
        file_permission = toString fileCfg.permissions;
        directory_permission = toString 751;
      };
    in
    {
      options.files = mkOption {
        description = "";
        default = { };
        type = types.lazyAttrsOf (
          types.submodule (
            { name, config, ... }:
            {
              options = {
                name = mkOption {
                  description = "The name of the Terraform resource";
                  type = types.str;
                };
                path = mkOption {
                  description = "The path to the file.";
                  type = types.str;
                };
                content = mkOption {
                  description = "The contents of the file";
                  type = types.str;
                };
                secret = mkOption {
                  description = "Specifies if the generated file is a secret or regular file.";
                  type = types.bool;
                  default = false;
                };

                owner = mkOption {
                  description = "The owner of the generated file.";
                  type = types.nullOr types.str;
                  default = null;
                };
                group = mkOption {
                  description = "The group of the generated file.";
                  type = types.nullOr types.str;
                  default = null;
                };
                permissions = mkOption {
                  description = "The permissions (in octal) of the generated file.";
                  type = lib.types.ints.positive;
                };
              };

              config = {
                inherit name;
                permissions = if config.secret then 400 else 644;
              };
            }
          )
        );
      };

      config = {
        terraform.required_providers = {
          local.source = "hashicorp/local";
          null.source = "hashicorp/null";
        };

        resource = {
          "local_file" =
            config.files |> lib.filterAttrs (_: val: !val.secret) |> lib.mapAttrs (_: mkLocalFile);
          "local_sensitive_file" =
            config.files |> lib.filterAttrs (_: val: val.secret) |> lib.mapAttrs (_: mkLocalFile);

          "null_resource" =
            config.files
            |> lib.filterAttrs (_: val: val.owner != null || val.group != null)
            |> lib.mapAttrs' (
              name: val:
              let
                resourceName = if val.secret then "local_sensitive_file.${name}" else "local_file.${name}";

                owner = lib.optionalString (val.owner != null) val.owner;
                group = lib.optionalString (val.group != null) val.group;
              in
              {
                name = "chown_${name}";
                value = {
                  depends_on = [
                    resourceName
                  ];

                  triggers = {
                    filename = lib.tfRef "${resourceName}.filename";
                    content_hash = lib.tfRef "${resourceName}.content_sha256";
                  };

                  provisioner."local-exec".command =
                    "chown ${owner}:${group} ${lib.tfRef "${resourceName}.filename"}";
                };
              }
            );
        };
      };
    };
}
