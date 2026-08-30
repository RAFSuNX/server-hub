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
# Secrets: managed by Doppler, written to /run/secrets/ at boot.
# =============================================================================

{
  description = "NixOS cluster — systema / systemb / systemc";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }: {

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
            ./hosts/${hostname}
            ./modules/common.nix
            ./modules/k3s.nix
            ./modules/glusterfs.nix
            ./modules/security.nix
            ./modules/longhorn.nix
            ./modules/doppler.nix
          ];
        };
      in {
        systema = mkHost "systema";
        systemb = mkHost "systemb";
        systemc = mkHost "systemc";
      };

  };
}
