{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
}:
buildNpmPackage rec {
  pname = "open-pencil-mcp";
  version = "0.12.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@open-pencil/mcp/-/mcp-${version}.tgz";
    hash = "sha256-P7B2minGUFs/ePAmq9/ti6sdNEqmbexsS56PkxShiEo=";
  };

  npmDepsHash = "sha256-5dhMVWIWB1VgLzgE+0/PysOjoUGvfQVNLEVAf/1bF9U=";

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    cp ${./open-pencil-mcp-package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    libexec="$out/libexec/${pname}"
    mkdir -p "$libexec" "$out/bin"

    cp -r dist node_modules package.json "$libexec/"

    makeWrapper ${lib.getExe nodejs} "$out/bin/openpencil-mcp" \
      --add-flags "$libexec/dist/stdio.js"

    makeWrapper ${lib.getExe nodejs} "$out/bin/openpencil-mcp-http" \
      --add-flags "$libexec/dist/index.js"

    runHook postInstall
  '';

  meta = {
    description = "OpenPencil MCP server";
    homepage = "https://github.com/open-pencil/open-pencil";
    license = lib.licenses.mit;
    mainProgram = "openpencil-mcp";
    platforms = lib.platforms.all;
  };
}
