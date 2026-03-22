{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  baseURL = "https://letsencrypt.org/certs/staging";
in
stdenvNoCC.mkDerivation {
  pname = "letsencrypt-staging-cacert";
  version = "2025-11-25";

  # Not a real source archive
  dontUnpack = true;

  srcs = [
    # Pretend Pear X1 - RSA 4096, self-signed
    (fetchurl {
      name = "letsencrypt-stg-root-x1.pem";
      url = "${baseURL}/letsencrypt-stg-root-x1.pem";
      hash = "sha256-Ol4RceX1wtQVItQ48iVgLkI2po+ynDI5mpWSGkroDnM=";
    })
    # Bogus Broccoli X2 - ECDSA P-384, self-signed
    (fetchurl {
      name = "letsencrypt-stg-root-x2.pem";
      url = "${baseURL}/letsencrypt-stg-root-x2.pem";
      hash = "sha256-SXw2wbUMDa/zCHDVkIybl68pIj1VEMXmwklX0MxQL7g=";
    })
    # Yearning Yucca Root YE - ECDSA P-384, self-signed
    (fetchurl {
      name = "letsencrypt-stg-root-ye.pem";
      url = "${baseURL}/gen-y/root-ye.pem";
      hash = "sha256-v0Goxff//BgeRtXfGiuGfw77bhad9vCkW9QGSx0CMIQ=";
    })
    # Yonder Yam Root YR - RSA 4096, self-signed
    (fetchurl {
      name = "letsencrypt-stg-root-yr.pem";
      url = "${baseURL}/gen-y/root-yr.pem";
      hash = "sha256-czke1Vo+sJ8ShPi1SOVA9eJlFJyD6gt53YrpfAFmWdc=";
    })
  ];

  buildPhase = ''
    runHook preBuild

    mkdir -p certs

    for cert in $srcs; do
      cp "$cert" "certs/$(stripHash "$cert")"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm 0444 -t "$out/etc/ssl/certs" certs/*.pem

    # Build a single PEM bundle
    cat certs/*.pem > "$out/etc/ssl/certs/ca-bundle.pem"

    runHook postInstall
  '';

  meta = {
    description = "Let's Encrypt staging root CA certificates";
    homepage = "https://letsencrypt.org/docs/staging-environment/";
    license = lib.licenses.mpl20; # Let's Encrypt certificate policy
    platforms = lib.platforms.all;
  };
}
