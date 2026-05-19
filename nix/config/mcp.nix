{ lib }:
{
  enable ? true,
  enableContext7 ? true,
  computerUse ? { },
}:
let
  enableComputerUse = lib.attrByPath [ "enable" ] false computerUse;
  computerUsePackage = lib.attrByPath [ "package" ] null computerUse;
in
assert !enableComputerUse || computerUsePackage != null;
lib.optionalAttrs enable {
  mcp =
    lib.optionalAttrs enableContext7 {
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
        enabled = true;
      };
    }
    // lib.optionalAttrs enableComputerUse {
      computer-use = {
        type = "local";
        command = [ "${lib.getExe computerUsePackage}" ];
        enabled = true;
      };
    };
}
