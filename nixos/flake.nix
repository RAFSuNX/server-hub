# =============================================================================
# NixOS Cluster Flake
# =============================================================================
# Three-node aarch64 cluster on Oracle Cloud.
#
# Nodes:
#   - systema  (k3s init / control-plane / etcd)
#   - systemb  (k3s join / control-plane / etcd)
#   - systemc  (k3s join / control-plane / etcd)
#
# Secrets: managed with agenix, encrypted to each host's SSH host key.
# =============================================================================

{
  description = "NixOS cluster — systema / systemb / systemc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, agenix }: {

    nixosConfigurations =
      let
        nodeIPs = {
          systema = "100.120.228.12";
          systemb = "100.110.116.30";
          systemc = "100.69.17.116";
        };

        mkHost = hostname: nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit nodeIPs; };
          modules = [
            agenix.nixosModules.default
            ./hosts/${hostname}
            ./modules/common.nix
            ./modules/k3s.nix
            ./modules/glusterfs.nix
            ./modules/security.nix
            ./modules/longhorn.nix
            ./modules/rclone.nix
            # ./modules/bandwidth-guard.nix # TODO
          ];
        };
      in {
        systema = mkHost "systema";
        systemb = mkHost "systemb";
        systemc = mkHost "systemc";
      };

  };
}
