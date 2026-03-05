{ config, lib, pkgs, nodeIPs, ... }:

let
  initNode   = "systema";
  hostname   = config.networking.hostName;
  isInitNode = hostname == initNode;

  allNodes = [ "systema" "systemb" "systemc" ];
  tlsSans  = lib.concatMap (n: [ "--tls-san=${n}" ]) allNodes;

  commonFlags = [
    "--disable=traefik"
    "--disable=servicelb"
    "--disable-cloud-controller"
    "--flannel-iface=tailscale0"
    "--node-ip=${nodeIPs.${hostname}}"
  ] ++ tlsSans;
in
{
  age.secrets.k3s_token.file = ../secrets/k3s_token.age;

  services.k3s = {
    enable    = true;
    role      = "server";
    tokenFile = config.age.secrets.k3s_token.path;

    extraFlags = if isInitNode then
      [ "--cluster-init" ] ++ commonFlags
    else
      [ "--server=https://${initNode}:6443" ] ++ commonFlags;
  };

  # Ensure k3s starts after Tailscale tunnel is up
  systemd.services.k3s = {
    after  = [ "tailscaled.service" ];
    wants  = [ "tailscaled.service" ];
  };

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  environment.systemPackages = with pkgs; [ kubectl k9s ];
}
