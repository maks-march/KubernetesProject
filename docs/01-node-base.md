# Этап 1. Настройка ноды

Hostname, /etc/hosts, swap off, модули ядра, sysctl. Всё, что kubeadm
проверяет в preflight и без чего kubelet/pod-сеть не работают.

## Зачем каждый пункт

- **hostname** — Kubernetes использует имя ноды как её identity в кластере
  (`kubectl get nodes`). Задаётся до `kubeadm init`.
- **/etc/hosts** — компоненты кластера (kubelet, etcd, CNI) резолвят ноду по имени.
- **swap off** — kubelet отказывается работать со включённым swap: память подов
  в свапе ломает представления планировщика о ресурсах. Проверяется в preflight.
- **модуль `overlay`** — файловая система overlayFS, из неё containerd собирает
  слои образов контейнеров.
- **модуль `br_netfilter`** — даёт iptables/nftables видеть трафик сетевых
  мостов. Pod-сеть Kubernetes построена на мостах, CNI пишет правила файрвола
  именно туда.
- **`ip_forward`** — разрешает ядру пересылать пакеты между интерфейсами.
  Поды сидят в своей сети (veth/мост), без форвардинга их пакеты не уходят.
- **`bridge-nf-call-iptables/ip6tables`** — без этих параметров правила
  iptables не применяются к трафику с мостов.

Пара «сейчас + навсегда»:
- `modprobe` грузит модуль немедленно; `/etc/modules-load.d/k8s.conf` — при
  каждом старте системы.
- `sysctl --system` применяет конфиги немедленно; `/etc/sysctl.d/k8s.conf` —
  при каждой загрузке.

Нюанс: модуль может быть **встроен в ядро** (типично для WSL: overlayfs
вкомпилирована, а не собирается модулем). Тогда `lsmod` его не покажет, и это
нормально — проверять надо фактическую доступность: overlay через
`/proc/filesystems`, br_netfilter через наличие
`/proc/sys/net/bridge/bridge-nf-call-iptables`. Скрипт пишет в modules-load.d
только те модули, которые реально являются модулями.

## Что делает скрипт `scripts/01-node-base.sh <hostname>`

1. Проверяет, что PID 1 = systemd
2. `hostnamectl set-hostname`
3. Добавляет `127.0.1.1 <hostname>` в `/etc/hosts` (без дублей)
4. `swapoff -a` + комментирует swap в fstab (бэкап: `fstab.bak`)
5. `modprobe overlay br_netfilter` + запись в modules-load.d
6. `/etc/sysctl.d/k8s.conf` + `sysctl --system`

## Порядок работы (TDD)

```bash
sudo bash tests/test-01-node-base.sh k8s-node    # тест ДО — часть FAIL
sudo bash scripts/01-node-base.sh k8s-node       # применяем
sudo bash tests/test-01-node-base.sh k8s-node    # тест ПОСЛЕ — PASS
```

## Проверить руками

```bash
free -h
grep overlay /proc/filesystems
sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
```
