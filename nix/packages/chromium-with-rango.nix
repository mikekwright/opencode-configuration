{
  lib,
  chromium,
  coreutils,
  writeShellApplication,
  rango-extension,
}:
writeShellApplication {
  name = "chromium-with-rango";

  runtimeInputs = [ chromium coreutils ];

  text = ''
    profile_root="''${XDG_RUNTIME_DIR:-$HOME/.cache}/opencode-rango-chromium"
    mkdir -p "$profile_root"

    exec ${lib.getExe chromium} \
      --load-extension=${rango-extension}/share/rango/chrome \
      --disable-extensions-except=${rango-extension}/share/rango/chrome \
      --no-first-run \
      --no-default-browser-check \
      --password-store=basic \
      --user-data-dir="$profile_root/profile" \
      "$@"
  '';

  meta = {
    description = "Chromium wrapped with the unpacked Rango extension";
    homepage = "https://github.com/david-tejada/rango";
    license = lib.licenses.mit;
    mainProgram = "chromium-with-rango";
    platforms = chromium.meta.platforms or lib.platforms.linux;
  };
}
