{
  services.terranix.providers.public_ip.nixos =
    { pkgs, ... }:
    {
      services.terranix = {
        terraform.providers = with pkgs.terraform-providers; [ hashicorp_http ];

        config =
          { lib, ... }:
          {
            terraform.required_providers.http.source = "hashicorp/http";
            data."http"."public_ip".url = "https://ipv4.icanhazip.com";
            locals.public_ip = lib.tfRef "chomp(data.http.public_ip.response_body)";
          };
      };
    };
}
