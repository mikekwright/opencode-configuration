{ lib }:
{
  enable ? true,
  enableContext7 ? true,
  computerUse ? { },
  openPencil ? { },
}:
let
  enableComputerUse = lib.attrByPath [ "enable" ] false computerUse;
  computerUsePackage = lib.attrByPath [ "package" ] null computerUse;
  enableOpenPencil = lib.attrByPath [ "enable" ] false openPencil;
  openPencilUrl = lib.attrByPath [ "url" ] null openPencil;
in
assert !enableComputerUse || computerUsePackage != null;
assert !enableOpenPencil || openPencilUrl != null;
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
    }
    // lib.optionalAttrs enableOpenPencil {
      open-pencil = {
        type = "remote";
        url = openPencilUrl;
        enabled = true;
      };
    };
}
