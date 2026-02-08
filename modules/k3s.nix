# =============================================================================
# K3s Kubernetes Cluster Configuration
# =============================================================================
# High-availability k3s cluster with embedded etcd.
# All traffic flows over Tailscale VPN for security.
#
# Topology:
#   - systema: Init node (--cluster-init)
#   - systemb: Join node (--server=https://systema:6443)
#   - systemc: Join node (--server=https://systema:6443)
#
# Author: rafsunx
# Last Modified: 2026-02-08
# =============================================================================

{ config, lib, pkgs, ... }:

let
  # Cluster configuration
  initNode = "systema";
  allNodes = [ "systema" "systemb" "systemc" ];

  # Runtime variables
  hostname = config.networking.hostName;
  isInitNode = hostname == initNode;

  # TLS SANs for all nodes (allows connecting to any control plane node)
  tlsSans = lib.concatMap (n: [ "--tls-san=${n}" ]) allNodes;

  # Common flags for all nodes
  commonFlags = [
    "--disable=traefik"              # Use Cloudflare Tunnels for ingress
    "--disable=servicelb"            # Use external load balancing
    "--flannel-iface=tailscale0"    # Route pod traffic over Tailscale VPN
  ] ++ tlsSans;
in
{
  # ===========================================================================
  # K3s Service Configuration
  # ===========================================================================

  services.k3s = {
    enable = true;
    role = "server";  # All nodes are control-plane + worker
    tokenFile = "/etc/nixos/secrets/k3s_token";

    # Node-specific flags
    extraFlags = if isInitNode then
      # Init node: Bootstrap etcd cluster
      [ "--cluster-init" ] ++ commonFlags
    else
      # Join nodes: Connect to init node
      [ "--server=https://${initNode}:6443" ] ++ commonFlags;
  };

  # ===========================================================================
  # Environment Configuration
  # ===========================================================================

  # Set KUBECONFIG globally for all users
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  # ===========================================================================
  # System Packages
  # ===========================================================================

  environment.systemPackages = with pkgs; [
    kubectl  # Kubernetes CLI
    k9s      # Terminal UI for Kubernetes
  ];
}
