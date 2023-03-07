variable "controlplane_count" {
  type    = number
  default = 1
}

variable "worker_count" {
  type    = number
  default = 1
}

variable "storage_pool_path" {
  type        = string
  default     = "/mnt/erie"
  description = "Mounted path of storage pool"

  validation {
    condition = length(var.storage_pool_path) == 0 || can(regex("^/", var.storage_pool_path))
    error_message = "The storage_pool_path must be an absolute path"
  }
  validation {
    condition = can(regex("[^/]$", var.storage_pool_path))
    error_message = "The storage_pool_path must not end with a slash"
  }
}

variable "talos_iso_path" {
  type        = string
  default     = "iso/talos-v1.3.5-amd64.iso"
  description = "Path to Talos ISO relative to storage pool"
}

variable "vm_disks_path" {
  type        = string
  default     = "vm"
  description = "Path to datavol with VM disks relative to storage pool"
}

