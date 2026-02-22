# =============================================================================
# NixOS Fleet Configuration
# =============================================================================
# Flake-based configuration for the server fleet.
#
# Servers:
#   - systema (init node)
#   - systemb (join node)
#   - systemc (join node)
#
# Architecture: aarch64-linux (ARM Neoverse-N1)
# OS: NixOS 26.05 (Yarara)
#
# Author: rafsunx
# Last Modified: 2026-02-08
# =============================================================================

{
  description = "NixOS server fleet configuration";

  # ===========================================================================
  # Inputs
  # ===========================================================================

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  # ===========================================================================
  # Outputs
  # ===========================================================================

  outputs = { self, nixpkgs, ... }:
  let
    # Target architecture for all servers
    system = "aarch64-linux";

    # Helper function to create a NixOS system configuration
    mkHost = hostname: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        # Shared modules (applied to all hosts)
        ./modules/common.nix
        ./modules/security.nix
        ./modules/k3s.nix
        ./modules/glusterfs.nix
        ./modules/bandwidth-guard.nix

        # Host-specific configuration
        ./hosts/${hostname}/default.nix
        ./hosts/${hostname}/hardware-configuration.nix
      ];
    };
  in
  {
    # NixOS system configurations
    nixosConfigurations = {
      systema = mkHost "systema";
      systemb = mkHost "systemb";
      systemc = mkHost "systemc";
    };
  };
}
