terraform {
  required_providers {
    truenas = {
      source  = "dariusbakunas/truenas"
      version = "0.11.1"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.3.0"
    }
  }

  backend "s3" {
    endpoint                    = "https://emnt-nas.local:9000"
    region                      = "us-west-1"
    bucket                      = "terraform-state"
    key                         = "talos-cluster.tfstate"
    shared_credentials_file     = "./s3creds.toml"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}

data "sops_file" "secrets" {
  source_file = "secrets.sops.yaml"
}

provider "truenas" {
  api_key  = data.sops_file.secrets.data["truenas-api-key"]
  base_url = "https://emnt-nas.local/api/v2.0"
}

resource "truenas_vm" "controlplane" {
  count = var.controlplane_count

  name = "talos_controlplane_${count.index}"

  vcpus   = 1
  cores   = 1
  threads = 2
  memory  = 1024 * 1024 * 1024 * 2 // 2GB

  bootloader       = "UEFI"
  shutdown_timeout = 90
  autostart        = true
  time             = "LOCAL"

  device {
    type = "NIC"
    attributes = {
      type       = "VIRTIO"
      nic_attach = "br0"
    }
  }

  device {
    type = "DISK"
    attributes = {
      type = "VIRTIO"
      path = "${var.storage_pool_path}/${var.vm_disks_path}/talos_controlplane_${count.index}"
    }
  }

  device {
    type = "CDROM"
    attributes = {
      path = "${var.storage_pool_path}/${var.talos_iso_path}"
    }
  }

  device {
    type = "DISPLAY"
    attributes = {
      wait       = false
      port       = 5900
      resolution = "1024x768"
      bind       = "0.0.0.0"
      password   = "" 
      web        = true
      type       = "VNC"
    }
  }
}
