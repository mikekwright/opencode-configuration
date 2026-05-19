{
  lib,
  fetchFromGitHub,
  runCommand,
}:
let
  src = fetchFromGitHub {
    owner = "open-pencil";
    repo = "skills";
    rev = "4d308b0b2d477887442737cf1cb7d2c51edb6467";
    hash = "sha256-HDhPGa08wH1sy0H50n0/OyYE/1aQEeebvhqC4oRikO0=";
  };
in
runCommand "open-pencil-skill"
  {
    meta = {
      description = "Upstream OpenPencil opencode skill";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
  ''
    mkdir -p "$out/share/opencode/skills"
    cp -R ${src}/skills/open-pencil "$out/share/opencode/skills/open-pencil"
  ''
