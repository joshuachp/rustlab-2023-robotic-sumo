{
  description = "A rust example flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    serial-monitor = {
      url = "github:joshuachp/serial-monitor";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.crane.follows = "crane";
      inputs.rust-overlay.follows = "rust-overlay";
    };
  };
  outputs =
    { self
    , nixpkgs
    , rust-overlay
    , crane
    , flake-utils
    , serial-monitor
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      overlays = [ (import rust-overlay) ];
      pkgs = import nixpkgs { inherit system overlays; };
      toolchain = pkgs.rust-bin.nightly."2023-06-28".default;
      craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
      # Cross compilation
      crossSystem = "armv6m-none";
      pkgsCross = import nixpkgs { inherit system overlays crossSystem; };
      tool = pkgs.lib.importTOML ./bot/rust-toolchain.toml;
      toolchainCross = toolchain.override {
        inherit (tool.toolchain) targets;
        extensions = tool.toolchain.components;
      };
      craneLibCross = (crane.mkLib pkgsCross).overrideToolchain toolchainCross;
      CARGO_TARGET_THUMBV6M_NONE_EABI_LINKER = "${pkgsCross.stdenv.cc.targetPrefix}cc";
      CARGO_TARGET_THUMBV6M_NONE_EABI_RUNNER = "qemu-arm --cpu cortex-m3";
    in
    {
      #packages.bot = craneLibCross.buildPackage {
      #  src = craneLibCross.cleanCargoSource (craneLibCross.path ./bot);
      #  strictDeps = true;
      #  inherit
      #    CARGO_TARGET_THUMBV6M_NONE_EABI_RUNNER
      #    CARGO_TARGET_THUMBV6M_NONE_EABI_LINKER;
      #};

      devShells.default =
        let
          packages = self.packages.${system};
        in
        pkgs.mkShell {
          inputsFrom = [
            # packages.bot
          ];
          packages = with pkgs; [
            toolchainCross

            pre-commit
            nixpkgs-fmt
            rust-analyzer

            elf2uf2-rs
            serial-monitor.packages.${system}.serial-monitor
          ];
        };
    });
}
