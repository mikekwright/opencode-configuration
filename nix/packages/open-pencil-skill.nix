{
  lib,
  fetchFromGitHub,
  runCommand,
}:
let
  src = fetchFromGitHub {
    owner = "ZSeven-W";
    repo = "openpencil-skill";
    rev = "13122f0ca037c58a49a069f472e5ad6461977335";
    hash = "sha256-dUCFFfG9hOVf+JjoOEgPZ5imvkmxiY5F2iBIyaFxvUU=";
  };
in
runCommand "open-pencil-skill"
  {
    meta = {
      description = "ZSeven-W OpenPencil opencode skill";
      homepage = "https://github.com/ZSeven-W/openpencil-skill";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
  ''
    mkdir -p "$out/share/opencode/skills"
    cp -R ${src}/skills/. "$out/share/opencode/skills/"
  ''
