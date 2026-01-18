# VPS configuration
{
  constants,
  # deadnix: skip
  __findFile ? __findFile,
  ...
}:
{
  den.hosts.x86_64-linux.francois.users = {
    "${constants.username}" = {
      hashedPassword = "$6$nCtzLAPQUu7StH/H$jmJctHePYNIhHYWfnJCFhtoC.oh/trRIZRHJNre9hnGOceo4GLz6ym5WTQutg7D.6ftZgcVUrHBz/2rM056n61";
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK/0NjCiXQOofWXgpjrrep1xr4GQOfvukzwydB/G5XIq"
      ];
    };
    "wittano" = {
      hashedPassword = "$6$B5oTifVrQHGHnzdH$ITvYQTJ39KbOmiUKojz31zl.doKnc7.ElMP2Gx3MunrvbghOJz1ERphDNHOy3u1VgOgfwO1DNWY6ZFBDkihMM0";
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIWEx3CLNKr82fffjdp7FhIqw/l7iUpj8fC4fkAAtfY0"
      ];
    };
  };

  den.aspects.francois = {
    includes = [
      <services/openssh>
    ];
  };
}
