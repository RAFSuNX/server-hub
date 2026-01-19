# K3s High Availability cluster configuration (Tailscale only)
{ config, lib, pkgs, ... }:

let
  initNode = "systema";
  allNodes = [ "systema" "systemb" "systemc" ];
  hostname = config.networking.hostName;
  isInitNode = hostname == initNode;

  # TLS SANs for all nodes (allows connecting to any node)
  tlsSans = lib.concatMap (n: [ "--tls-san=${n}" ]) allNodes;

  commonFlags = [
    "--disable=traefik"
    "--disable=servicelb"
    "--flannel-iface=tailscale0"
  ] ++ tlsSans;
in
{
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = "/etc/nixos/secrets/k3s_token";

    extraFlags = if isInitNode then
      [ "--cluster-init" ] ++ commonFlags
    else
      [ "--server=https://${initNode}:6443" ] ++ commonFlags;
  };

  # Set KUBECONFIG globally
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  environment.systemPackages = with pkgs; [
    kubectl
    k9s
  ];
}
