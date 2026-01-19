{
  description = "NixOS server fleet configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "aarch64-linux";

    # Helper function to create a NixOS system
    mkHost = hostname: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./modules/common.nix
        ./modules/security.nix
        ./modules/k3s.nix
        ./modules/glusterfs.nix
        ./hosts/${hostname}/default.nix
        ./hosts/${hostname}/hardware-configuration.nix
      ];
    };
  in
  {
    nixosConfigurations = {
      systema = mkHost "systema";
      systemb = mkHost "systemb";
      systemc = mkHost "systemc";
    };
  };
}
