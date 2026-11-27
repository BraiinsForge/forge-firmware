{
  description = "Firmware builds for Braiins Forge products";

  inputs = {
    self.submodules = true;
    forge-micro.url = "path:./forge-micro";
    nixpkgs.follows = "forge-micro/nixpkgs";
  };

  outputs =
    {
      self,
      forge-micro,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # forge-micro reads the same variable when it evaluates its images,
      # so the label here and the version baked into the image agree.
      requestedVersion = builtins.getEnv "UBOS_FW_VERSION";
      firmwareVersion = if requestedVersion == "" then "1" else requestedVersion;
      validVersion =
        builtins.match "[1-9][0-9]*" firmwareVersion != null
        && builtins.stringLength firmwareVersion <= 10
        && builtins.fromJSON firmwareVersion <= 4294967295;
      label = if requestedVersion == "" then "master" else "v${firmwareVersion}";

      inherit (forge-micro.packages.${system}) forge-axe-image forge-axe-uf2;

      forgeAxe =
        assert pkgs.lib.assertMsg validVersion "UBOS_FW_VERSION must be a positive decimal u32";
        assert pkgs.lib.assertMsg (builtins.getEnv "POOL_USER" == "") "POOL_USER must be unset";
        pkgs.runCommand "forge-axe-${label}" { } ''
          mkdir -p "$out"
          cp ${forge-axe-image}/forge-axe-v${firmwareVersion}-*.bin "$out/forge-axe-${label}.bin"
          cp ${forge-axe-uf2}/forge-axe-v${firmwareVersion}-*.uf2 "$out/forge-axe-${label}.uf2"
        '';
    in
    {
      packages.${system} = {
        default = forgeAxe;
        forge-axe = forgeAxe;
        inherit forge-axe-image forge-axe-uf2;
      };
      checks.${system}.forge-axe = forgeAxe;
      formatter.${system} = pkgs.nixfmt;
    };
}
