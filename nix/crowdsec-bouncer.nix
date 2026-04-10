{
  inputs,
  lib,
  self,
  ...
}: {
  flake.nixosModules.crowdsecBouncer = {
    pkgs,
    config,
    ...
  }: {
    sops.secrets."crowdsecBouncer/apikey" = {};
    services.crowdsec-firewall-bouncer = {
      enable = true;
      settings.api_url = "https://crowdsec.emnt.dev";
      secrets.apiKeyPath = config.sops.secrets."crowdsecBouncer/apikey".path;
    };
  };
}
