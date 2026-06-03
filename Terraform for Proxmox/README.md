# Terraform for Proxmox

Декларативное развёртывание ВМ в Proxmox VE из cloud-init шаблона.
Используется в рабочем процессе для пакетного создания машин для Kubernetes-кластера
(3 control-plane + 2 worker), плюс отдельные ВМ под вспомогательные сервисы.

## Что делает

Из подготовленного cloud-init шаблона Proxmox создаёт N виртуальных машин:

- full-clone из шаблона
- 40 ГБ основной диск + cloud-init диск на указанном storage
- сеть virtio с поддержкой VLAN-тегов
- последовательное авто-назначение IP-адресов из заданной подсети
- инициализация cloud-init: пользователь, пароль, SSH-ключ из `ssh_pub.pub`
- QEMU guest agent
- управление жизненным циклом: state, autostart, порядок старта

## Два режима использования

**Пакетный + кастомные** (`main.tf` + `variables.tf` + `cloud-init.tf`)
Авто-генерация однотипных нод (по умолчанию 5 штук с именами `vm-01..vm-05`
и IP `10.10.10.248..252`). Дополнительно через `var.vm_config` можно описать
уникальные ВМ - при пересечении имён они перетирают сгенерированные.
Удобно для k8s-кластера + одной-двух не-кластерных ВМ.

**Только кастомные** (`*.for_manual_VM_params`)
Без авто-генерации: каждая ВМ описана отдельно в `vm_config`.
Удобно для разнородной инфраструктуры (LB / DB / app с разными ресурсами).

Чтобы переключиться - переименовать пары файлов местами.

## Требования

- Proxmox VE 7.x / 8.x с готовым cloud-init шаблоном
- Terraform >= 1.5
- Provider: [`telmate/proxmox`](https://registry.terraform.io/providers/Telmate/proxmox) `3.0.2-rc05`
- API-токен Proxmox с правами на datacenter / pool / storage

## Структура

```
Terraform for Proxmox/
├── main.tf                              # provider + чтение ssh_pubkey
├── variables.tf                         # API-креды + vm_config
├── cloud-init.tf                        # ресурс ВМ + generated_vms (5 шт.)
├── credentials.auto.tfvars              # пример API-кредов (заменить своими)
│
├── variables.tf.for_manual_VM_params    # альт. набор: только ручное описание
├── cloud-init.tf.for_manual_VM_params   # альт. набор: без авто-генерации
│
└── ssh_pub.pub                          # ваш публичный SSH-ключ (создать)
```

## Quick start

1. Склонировать репо, зайти в папку:
   ```bash
   cd "Terraform for Proxmox"
   ```

2. Положить публичный SSH-ключ:
   ```bash
   cp ~/.ssh/id_ed25519.pub ssh_pub.pub
   ```

3. Заполнить `credentials.auto.tfvars` (URL Proxmox, API token id/secret).

4. В `cloud-init.tf` подставить под свою инсталляцию:
   - `target_node` - имя ноды Proxmox-кластера
   - `clone` - имя cloud-init шаблона
   - `storage` в `disk` - имя дискового storage
   - в `generated_vms` - количество и стартовый IP

5. Применить:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Параметры ВМ (`vm_config`)

| Поле          | Тип    | По умолчанию | Назначение |
|---------------|--------|--------------|------------|
| `name`        | string | -            | Имя ВМ в Proxmox |
| `vm_id`       | number | -            | VMID |
| `cores`       | number | -            | vCPU |
| `memory`      | number | -            | RAM, МБ |
| `vm_state`    | string | `"stopped"`  | `running` / `stopped` |
| `onboot`      | bool   | `true`       | Автостарт при загрузке хоста |
| `startup`     | string | -            | Порядок старта, например `"order=2"` |
| `ipconfig`    | string | -            | `"ip=X.X.X.X/24,gw=X.X.X.1"` |
| `bridge`      | string | `"vmbr0"`    | Сетевой бридж |
| `network_tag` | number | `0`          | VLAN tag |
| `ciuser`      | string | -            | Cloud-init user |
| `cipassword`  | string | -            | Cloud-init password (основной доступ - по SSH-ключу) |

## Что разворачивается (типовая инсталляция на 5 нод)

```
┌──────────────────────────────────────────────────────┐
│  Proxmox cluster · target_node = NODE-NAME           │
│                                                      │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌──────┐│
│  │ vm-01  │ │ vm-02  │ │ vm-03  │ │ vm-04  │ │vm-05 ││
│  │ 2 vCPU │ │ 2 vCPU │ │ 2 vCPU │ │ 2 vCPU │ │2 vCPU││
│  │ 3 GB   │ │ 3 GB   │ │ 3 GB   │ │ 3 GB   │ │3 GB  ││
│  │ 40 GB  │ │ 40 GB  │ │ 40 GB  │ │ 40 GB  │ │40 GB ││
│  │ .248   │ │ .249   │ │ .250   │ │ .251   │ │.252  ││
│  └────┬───┘ └────┬───┘ └────┬───┘ └────┬───┘ └──┬───┘│
│       └─────────┴──────────┴──────────┴────────┘     │
│                          │                           │
│                  vmbr0 · VLAN 0                      │
└─────────────────────────┬────────────────────────────┘
                          │
                   gw 10.10.10.1
```