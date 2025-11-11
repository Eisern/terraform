resource "proxmox_vm_qemu" "cloud-init" {
  for_each    = local.all_vms
  name        = each.value.name
  vmid        = each.value.vm_id
  target_node = "NODE-NAME"

  clone      = "CLOUD-INIT-TEMPLATE-NAME-IN-PROXMOX"
  full_clone = true

  agent   = 1
  scsihw  = "virtio-scsi-single"
  os_type = "cloud-init"
  bootdisk = "scsi0"
  boot     = "order=scsi0"

  memory = each.value.memory

  vm_state = try(each.value.vm_state, "stopped")
  onboot   = try(each.value.onboot, true)
  startup  = try(each.value.startup, null)

  # cloud-init сеть и учётка
  ipconfig0  = each.value.ipconfig
  skip_ipv6  = true

  ciuser     = each.value.ciuser
  cipassword = each.value.cipassword


  sshkeys = data.local_file.ssh_pubkey.content

  cpu {
    type    = "x86-64-v2-AES"
    sockets = 1
    cores   = each.value.cores
  }

  serial {
    id   = 0
    type = "socket"
  }

  network {
    id       = 0
    model    = "virtio"
    bridge   = each.value.bridge
    firewall = false
    tag      = each.value.network_tag
  }

  # основной диск
  disk {
    slot      = "scsi0"               
    size      = "40G"
    type      = "disk"
    storage   = "STORE-NAME-IN-PROXMOX"
    replicate = true
  }

  # cloud-init диск (аналог твоего ide0: cloudinit)
  disk {
    slot    = "scsi1"
    type    = "cloudinit"
    storage = "store"
  }
}



locals {
  # то, что пришло из variables.tf (если нужно создать руками 5 ВМ с другими параметрами)
  user_vms = var.vm_config

  # автогенерация пачки однотипных ВМ (например, 5 штук)
  generated_vms = {
    for i in range(1, 6) : format("vm-%02d", i) => {
      vm_id       = 200 + i
      name        = format("vm-%02d", i)
      cores       = 2
      memory      = 3072
      vm_state    = "stopped"
      onboot      = true
      bridge      = "vmbr0"
      ipconfig    = format("ip=10.10.10.%d/24,gw=10.10.10.1", 247 + i)					#с какого IP-адреса начинать раздачу для создаваемых машин (в данном случае-раздача с 10.10.10.248)
      ciuser      = "имя_пользователя_внутри_VM"
      cipassword  = "пароль_этого_пользователя"
      network_tag = 0
    }
  }

  # В итоге создадутся шаблонные виртуалки из секции generated_vms и кастомные из секции user_vms
  # если имена совпадут — то что в var.vm_config перетрет то что в generated_vms
  all_vms = merge(local.generated_vms, local.user_vms)
}
