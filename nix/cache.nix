{
  flake-file.nixConfig = {
    extra-substituters = [ "https://cache.zakku.eu" ];
    extra-trusted-public-keys = [
      "cache.zakku.eu-1:X219JrBeYMjhvMb0BXYci2gyAAiOQj4dGizzf+yCVcI="
    ];
  };
}
