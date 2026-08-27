{
  flake.terranixModules.backend.terraform.backend."s3" = {
    bucket = "nixpedition-tf";
    key = "terraform.tfstate";
    skip_credentials_validation = true;
    skip_metadata_api_check = true;
    skip_region_validation = true;
    skip_requesting_account_id = true;
    skip_s3_checksum = true;
    use_path_style = true;
  };

  perSystem = {
    terranix.terranixConfigurations.nixpedition = {
      terraformWrapper.prefixText = ''
        AWS_ACCESS_KEY_ID=$(clan secrets get cf-s3-access-key)
        export AWS_ACCESS_KEY_ID

        AWS_SECRET_ACCESS_KEY=$(clan secrets get cf-s3-secret-key)
        export AWS_SECRET_ACCESS_KEY

        AWS_ENDPOINT_URL_S3=$(clan secrets get cf-s3-endpoint)
        export AWS_ENDPOINT_URL_S3

        AWS_DEFAULT_REGION="auto"
        export AWS_DEFAULT_REGION
      '';
    };
  };
}
