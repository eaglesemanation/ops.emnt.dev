{
  inputs,
  lib,
  self,
  ...
}: {
  flake.nixosModules.digitalocean = {modulesPath, pkgs, ...}: {
    imports = [
      "${modulesPath}/virtualisation/digital-ocean-config.nix"
    ];

    # do not use DHCP, as DigitalOcean provisions IPs using cloud-init
    networking.useDHCP = lib.mkForce false;

    services.do-agent.enable = true;

    # Disables all modules that do not work with NixOS
    services.cloud-init = {
      enable = true;
      network.enable = true;
      settings = {
        datasource_list = [
          "ConfigDrive"
          "Digitalocean"
        ];
        datasource.ConfigDrive = {};
        datasource.Digitalocean = {};
        # Based on https://github.com/canonical/cloud-init/blob/main/config/cloud.cfg.tmpl
        cloud_init_modules = [
          "seed_random"
          "bootcmd"
          "write_files"
          "growpart"
          "resizefs"
          "set_hostname"
          "update_hostname"
          # Not support on NixOS
          #"update_etc_hosts"
          # throws error
          #"users-groups"
          # tries to edit /etc/ssh/sshd_config
          #"ssh"
          "set_password"
        ];
        cloud_config_modules = [
          "ssh-import-id"
          "keyboard"
          # doesn't work with nixos
          #"locale"
          "runcmd"
          "disable_ec2_metadata"
        ];
        ## The modules that run in the 'final' stage
        cloud_final_modules = [
          "write_files_deferred"
          "puppet"
          "chef"
          "ansible"
          "mcollective"
          "salt_minion"
          "reset_rmc"
          # install dotty agent fails
          #"scripts_vendor"
          "scripts_per_once"
          "scripts_per_boot"
          # /var/lib/cloud/scripts/per-instance/machine_id.sh has broken shebang
          #"scripts_per_instance"
          "scripts_user"
          "ssh_authkey_fingerprints"
          "keys_to_console"
          "install_hotplug"
          "phone_home"
          "final_message"
        ];
      };
    };

    systemd.services.reserved-ip-egress = {
      description = "Send outbound IPv4 traffic from the DigitalOcean reserved IP";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = with pkgs; [curl iproute2 gawk];
      serviceConfig.Type = "oneshot";
      script = ''
        md=http://169.254.169.254/metadata/v1

        active=$(curl -fsS --max-time 5 "$md/reserved_ip/ipv4/active" || echo false)
        if [ "$active" != true ]; then
        	echo "no reserved IP assigned yet, leaving routes alone"
        	exit 0
        fi

        reserved=$(curl -fsS --max-time 5 "$md/reserved_ip/ipv4/ip_address")
        anchor_gw=$(curl -fsS --max-time 5 "$md/interfaces/public/0/anchor_ipv4/gateway")
        anchor_addr=$(curl -fsS --max-time 5 "$md/interfaces/public/0/anchor_ipv4/address")
        anchor_mask=$(curl -fsS --max-time 5 "$md/interfaces/public/0/anchor_ipv4/netmask")
        public_gw=$(curl -fsS --max-time 5 "$md/interfaces/public/0/ipv4/gateway")

        route=$(ip -4 route get 1.1.1.1)
        current_gw=$(echo "$route" | awk '{for (i=1;i<=NF;i++) if ($i=="via") {print $(i+1); exit}}')
        dev=$(echo "$route" | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')

        if [ "$current_gw" = "$anchor_gw" ]; then
        	exit 0
        fi

        if [ "$anchor_mask" != "255.255.0.0" ]; then
        	echo "unexpected anchor netmask: $anchor_mask" >&2
        	exit 1
        fi

        # Succeeds as soon as one of several independently operated echo services reports the
        # reserved IP, so a single service being down cannot block the switch.
        confirm_egress() {
        	for url in https://checkip.amazonaws.com https://icanhazip.com https://api.ipify.org; do
        		seen=$(curl -4 -fsS --max-time 5 "$url" | tr -d '[:space:]' || true)
        		if [ "$seen" = "$reserved" ]; then
        			return 0
        		fi
        	done
        	return 1
        }

        ip address replace "$anchor_addr/16" dev "$dev"
        ip route replace default via "$anchor_gw" dev "$dev"

        if ! confirm_egress; then
        	echo "no echo service confirmed $reserved as the outbound address; restoring the original route" >&2
        	ip route replace default via "$public_gw" dev "$dev"
        	exit 1
        fi
        echo "outbound traffic now leaves from $reserved"
      '';
    };

    systemd.timers.reserved-ip-egress = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitInactiveSec = "1min";
      };
    };
  };
}
