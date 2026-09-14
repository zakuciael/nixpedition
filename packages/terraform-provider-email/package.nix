{
  lib,
  buildGoModule,
  go,
}:
let
  version = "0.1.0";
  providerSourceAddress = "registry.opentofu.org/zakuciael/email";
in
buildGoModule {
  pname = "terraform-provider-email";
  inherit version;

  src = ./.;

  vendorHash = "sha256-OA7Gw3Xsusc10RKRv8evc9qeMKE9XlfZJBikjoFpUi4=";

  subPackages = [ "." ];

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  # Layout expected by opentofu.withPlugins / filesystem mirrors.
  postInstall = ''
    dir="$out/libexec/terraform-providers/${providerSourceAddress}/${version}/${go.GOOS}_${go.GOARCH}"
    mkdir -p "$dir"
    mv "$out/bin"/terraform-provider-email* \
      "$dir/terraform-provider-email_${version}"
    rmdir "$out/bin" || true
  '';

  passthru = {
    provider-source-address = providerSourceAddress;
  };

  meta = {
    description = "OpenTofu provider for Cloudflare DMARC Management and OVH Email Pro DKIM";
    homepage = "https://github.com/zakuciael/nixpedition";
    license = lib.licenses.mit;
    mainProgram = "terraform-provider-email";
  };
}
