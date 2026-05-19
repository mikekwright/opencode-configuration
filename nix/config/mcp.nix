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
  openPencilPackage = lib.attrByPath [ "package" ] null openPencil;
  openPencilRoot = lib.attrByPath [ "root" ] null openPencil;
in
assert !enableComputerUse || computerUsePackage != null;
assert !enableOpenPencil || openPencilPackage != null;
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
        type = "local";
        command = [ "${lib.getExe openPencilPackage}" ];
        enabled = true;
      }
      // lib.optionalAttrs (openPencilRoot != null) {
        environment.OPENPENCIL_MCP_ROOT = toString openPencilRoot;
      };
    };
}
