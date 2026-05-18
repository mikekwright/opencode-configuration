{ lib, runCommand }:
let
  skillsSource = ../skills;
in
runCommand "opencode-skills" {
  meta = {
    description = "Bundled opencode skill set";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
} ''
  mkdir -p "$out/share/opencode"
  cp -R ${skillsSource} "$out/share/opencode/skills"
''
