{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "wait-for";
  version = "96130b4";

  src = fetchFromGitHub {
    owner = "dnnrly";
    repo = "wait-for";
    rev = finalAttrs.version;
    hash = "sha256-4/HVoa0AMxjofL6LKWfMKbqsCP/sv9+xxoWwwIqfRsY=";
  };

  vendorHash = "sha256-QTHkma1+H1fa4U7YiSyjmGnqe1mRkoxI/nGZTh/FG1M=";

  meta = {
    mainProgram = "wait-for";
    description = "Super simple tool to help with orchestration of commands on the CLI by waiting on networking resources.";
    homepage = "https://github.com/dnnrly/wait-for";
    license = lib.licenses.asl20;
  };
})
