{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonApplication {
  pname = "dmarcreport";
  version = "1.0.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "joho1968";
    repo = "dmarcreport";
    rev = "f51503b5add614b22fda7b251246de9eb607c1ca";
    hash = "sha256-Cy1a9Tim+GVz1A4IFApPkYe0iYkB9QKAZWxBsafwg4c=";
  };

  build-system = with python3Packages; [ hatchling ];

  dependencies = with python3Packages; [
    dnspython
    pydantic
    pyyaml
    typer
    rich
  ];

  # Upstream ships no automated test suite in-tree for packaging.
  doCheck = false;

  meta = {
    description = "CLI pipeline for DMARC, forensic, and TLS-RPT reports with static dashboards";
    homepage = "https://github.com/joho1968/dmarcreport";
    license = lib.licenses.agpl3Only;
    mainProgram = "dmarcreport";
  };
}
