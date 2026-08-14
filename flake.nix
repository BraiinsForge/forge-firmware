{
  description = "Firmware builds for Braiins Forge products";

  inputs = {
    self.submodules = true;
    forge-micro.url = "path:./forge-micro";
    nixpkgs.follows = "forge-micro/nixpkgs";
    rust-overlay.follows = "forge-micro/rust-overlay";
    crane.follows = "forge-micro/crane";
  };

  outputs =
    {
      self,
      forge-micro,
      nixpkgs,
      rust-overlay,
      crane,
    }:
    let
      system = "x86_64-linux";
      target = "thumbv8m.main-none-eabihf";
      slotBytes = 952 * 1024;

      requestedVersion = builtins.getEnv "FORGE_FW_VERSION";
      firmwareVersion = if requestedVersion == "" then "1" else requestedVersion;
      validVersion =
        builtins.match "[1-9][0-9]*" firmwareVersion != null
        && builtins.stringLength firmwareVersion <= 10
        && builtins.fromJSON firmwareVersion <= 4294967295;
      label = if requestedVersion == "" then "master" else "v${firmwareVersion}";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (import rust-overlay)
          forge-micro.overlays.probe-rs
        ];
      };

      toolchains = import forge-micro.lib.modules.toolchains {
        inherit
          pkgs
          nixpkgs
          system
          crane
          ;
      };
      inherit (toolchains) craneLib;

      patchedCrates = import forge-micro.lib.modules.patched-crates { inherit pkgs; };
      forgeMicroSource = builtins.path {
        path = forge-micro;
        name = "forge-micro-source";
      };
      sources = import forge-micro.lib.modules.source {
        inherit pkgs craneLib patchedCrates;
        root = forgeMicroSource;
      };
      helpers = import forge-micro.lib.modules.helpers {
        inherit pkgs patchedCrates;
        webuiBuildEnv = {
          UBOS_WEBUI_BUILD_REV = forge-micro.shortRev or "dirty";
          UBOS_WEBUI_BUILD_TIME = toString forge-micro.lastModified;
        };
        espToolchain = null;
        xtensaEspToolchain = null;
      };
      guards = import forge-micro.lib.modules.guards { };
      armAttrs = helpers.armCc target;

      mkArtifacts =
        name:
        craneLib.buildDepsOnly (
          {
            src = sources.src;
            doCheck = false;
            cargoBuildCommand = "cargo build --release";
            cargoExtraArgs = "-p ${name} --target ${target}";
            nativeBuildInputs = [ pkgs.gcc-arm-embedded ];
          }
          // armAttrs
        );

      appArtifacts = mkArtifacts "braiins-axe";
      bootArtifacts = mkArtifacts "rp2350-bootloader";

      appImage = craneLib.cargoBuild (
        {
          src = sources.srcFor [ "braiins-axe" ];
          cargoArtifacts = appArtifacts;
          cargoBuildCommand = "cargo build --release";
          cargoExtraArgs = "-p braiins-axe --target ${target}";
          nativeBuildInputs = [
            pkgs.gcc-arm-embedded
            pkgs.esbuild
          ];
          UBOS_FW_VERSION = firmwareVersion;
          doInstallCargoArtifacts = false;
          installPhaseCommand = ''
            mkdir -p "$out"
            arm-none-eabi-objcopy -O binary \
              target/${target}/release/braiins-axe \
              "$out/app.bin"
          ''
          + guards.imageGuard {
            name = "forge-axe";
            bin = ''"$out/app.bin"'';
            maxBytes = slotBytes;
          };
        }
        // armAttrs
        // helpers.webuiEnvAttrs
      );

      bootloader = craneLib.cargoBuild (
        {
          src = sources.srcFor [ "rp2350-bootloader" ];
          cargoArtifacts = bootArtifacts;
          cargoBuildCommand = "cargo build --release";
          cargoExtraArgs = "-p rp2350-bootloader --target ${target}";
          nativeBuildInputs = [ pkgs.gcc-arm-embedded ];
          doInstallCargoArtifacts = false;
          installPhaseCommand = ''
            mkdir -p "$out"
            cp target/${target}/release/rp2350-bootloader "$out/boot.elf"
          '';
        }
        // armAttrs
      );

      forgeAxe =
        assert pkgs.lib.assertMsg validVersion "FORGE_FW_VERSION must be a positive decimal u32";
        assert pkgs.lib.assertMsg (builtins.getEnv "POOL_USER" == "") "POOL_USER must be unset";
        pkgs.runCommand "forge-axe-${label}" { nativeBuildInputs = [ pkgs.picotool ]; } ''
          mkdir -p "$out"
          cp ${appImage}/app.bin "$out/forge-axe-${label}.bin"
          picotool uf2 convert ${bootloader}/boot.elf boot.uf2
          picotool uf2 convert ${appImage}/app.bin \
            -t bin app.uf2 -o 0x10021000 --family rp2350-arm-s
          cat boot.uf2 app.uf2 >"$out/forge-axe-${label}.uf2"
        '';
    in
    {
      packages.${system} = {
        default = forgeAxe;
        forge-axe = forgeAxe;
      };
      checks.${system}.forge-axe = forgeAxe;
      formatter.${system} = pkgs.nixfmt;
    };
}
