{ lib }:
{
  enable ? true,
  package ? null,
  openPencil ? { },
}:
let
  skillPackages = lib.filter (candidate: candidate != null) (
    [ package ]
    ++ lib.optional (lib.attrByPath [ "enable" ] false openPencil) (
      lib.attrByPath [ "package" ] null openPencil
    )
  );
in
lib.optionalAttrs (enable && skillPackages != [ ]) {
  skills.paths = map (candidate: "${candidate}/share/opencode/skills") skillPackages;
}
