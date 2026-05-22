{ lib }:
{
  enable ? true,
  enableContext7 ? true,
  computerUse ? { },
  openPencil ? { },
  banani ? { },
}:
let
  enableComputerUse = lib.attrByPath [ "enable" ] false computerUse;
  computerUsePackage = lib.attrByPath [ "package" ] null computerUse;
  computerUseDisplay = lib.attrByPath [ "virtualDisplay" "display" ] null computerUse;
  enableOpenPencil = lib.attrByPath [ "enable" ] false openPencil;
  openPencilUrl = lib.attrByPath [ "url" ] null openPencil;
  enableBanani = lib.attrByPath [ "enable" ] false banani;
  bananiUrl = lib.attrByPath [ "url" ] null banani;
in
assert !enableComputerUse || computerUsePackage != null;
assert !enableOpenPencil || openPencilUrl != null;
assert !enableBanani || bananiUrl != null;
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
        env = lib.optionalAttrs (computerUseDisplay != null) {
          DISPLAY = computerUseDisplay;
        };
        enabled = true;
      };
    }
    // lib.optionalAttrs enableOpenPencil {
      open-pencil = {
        type = "remote";
        url = openPencilUrl;
        enabled = true;
      };
    }
    // lib.optionalAttrs enableBanani {
      banani = {
        type = "remote";
        url = bananiUrl;
        headers = {
          Authorization = "Bearer {env:BANANI_API_KEY}";
        };
        enabled = true;
      };
    };
}
