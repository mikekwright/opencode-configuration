{
  lib,
  autoPatchelfHook,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  pkg-config,
  python3,
  stdenv,
  vips,
  xorg,
}:
buildNpmPackage rec {
  pname = "computer-use-mcp";
  version = "1.8.0";

  src = fetchFromGitHub {
    owner = "domdomegg";
    repo = "computer-use-mcp";
    rev = "v${version}";
    hash = "sha256-ENhucd45rrjJ2yfqm2rj+zOzn3hD9x5P9G+fY3+q+eM=";
  };

  npmDepsHash = "sha256-A9Q2xauiP3D7x/8E7rMXU8rl5CFv0+IHdZAnXQh2x+A=";

  nativeBuildInputs = [
    makeWrapper
  ] ++ lib.optionals stdenv.isLinux [
    autoPatchelfHook
    pkg-config
    python3
  ];

  buildInputs = [
    vips
  ] ++ lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
    xorg.libX11
    xorg.libXtst
  ];

  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    libexec="$out/libexec/${pname}"
    mkdir -p "$libexec" "$out/bin"

    cp -r dist node_modules package.json "$libexec/"

    makeWrapper ${lib.getExe nodejs} "$out/bin/computer-use-mcp" \
      --add-flags "$libexec/dist/main.js"

    runHook postInstall
  '';

  postFixup = lib.optionalString stdenv.isLinux ''
    wrapProgram "$out/bin/computer-use-mcp" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
        stdenv.cc.cc.lib
        xorg.libX11
        xorg.libXtst
      ]}"
  '';

  meta = {
    description = "MCP server for full computer control";
    homepage = "https://github.com/domdomegg/computer-use-mcp";
    license = lib.licenses.mit;
    mainProgram = "computer-use-mcp";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
