variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
}

variable "vm_config" {
  description = "ВМ, которые задаём вручную"
  type = map(object({
    name        = string
    vm_id       = number
    cores       = number
    memory      = number

    vm_state    = optional(string, "stopped")
    onboot      = optional(bool, true)
    startup     = optional(string)

    ipconfig    = optional(string)
    bridge      = optional(string, "vmbr0")
    network_tag = optional(number, 0)

    ciuser      = optional(string, "имя_пользователя_внутри_VM")
    cipassword  = optional(string, "пароль_этого_пользователя")
  }))
  default = {}
}