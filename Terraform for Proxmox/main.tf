terraform {
    required_providers {
        proxmox = {
            source = "telmate/proxmox"
            version = "3.0.2-rc05"
        }
    }
}

data "local_file" "ssh_pubkey" {
  filename = "${path.module}/ssh_pub.pub"					#использовать публичный SSH-ключ, который лежит в той же папке, что и этот файл и назван ssh_pub.pub
}

provider "proxmox" {
    pm_api_url          = var.proxmox_api_url
    pm_api_token_id     = var.proxmox_api_token_id
    pm_api_token_secret = var.proxmox_api_token_secret
    pm_tls_insecure     = true
    pm_timeout          = 6000   #100 минут таймаута после которого терраформ отваливается (например, если VM создаются на медленных дисках), можно больше 
}