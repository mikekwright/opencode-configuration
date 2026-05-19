{ lib }:
{
  enable ? true,
  package ? null,
}:
lib.optionalAttrs (enable && package != null) {
  skills.paths = [ "${package}/share/opencode/skills" ];
}
