{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "rango-extension";
  version = "0.8.7";

  src = fetchFromGitHub {
    owner = "david-tejada";
    repo = "rango";
    rev = "v${version}";
    hash = "sha256-8VBqUbaRXzIX1tL9txw5Y0TOaSVol+R9SggLq1DaxHc=";
  };

  npmDepsHash = "sha256-ao+UE6oVQ4pWmwirTHmRPLRG+zQ0SB/0dznepQIbc+g=";

  npmBuildScript = "build:chrome";

  PUPPETEER_SKIP_DOWNLOAD = "true";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/rango"
    cp -r dist/chrome "$out/share/rango/chrome"

    runHook postInstall
  '';

  meta = {
    description = "Rango Chromium extension bundle";
    homepage = "https://github.com/david-tejada/rango";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
