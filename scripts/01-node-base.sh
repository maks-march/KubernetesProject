#!/usr/bin/env bash
# ============================================================================
# 01-node-base.sh
# Этап 1: настройка ноды под Kubernetes.
#   hostname, /etc/hosts, swap off, модули ядра, sysctl
# Запуск: sudo bash scripts/01-node-base.sh k8s-node
# ============================================================================

set -euo pipefail

NODE_HOSTNAME="${1:?Usage: 01-node-base.sh <hostname>}"

# 1. Без systemd kubeadm работать не будет
if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    echo ""
    echo "ОШИБКА: systemd не является PID 1"
    exit 1
fi

# 2. Имя ноды
# Kubernetes использует hostname как имя ноды в кластере.
hostnamectl set-hostname "$NODE_HOSTNAME"

# 3. Запись в /etc/hosts, если её ещё нет
if ! grep -q "$NODE_HOSTNAME" /etc/hosts; then
    echo ""
    echo "127.0.1.1 $NODE_HOSTNAME" >> /etc/hosts
fi

# 4. Swap
# kubelet не работает со включённым swap, kubeadm проверяет это в preflight.
# Выключаем сейчас и комментируем в fstab, чтобы не вернулся после ребута.
swapoff -a
sed -i.bak '/\bswap\b/s/^/#/' /etc/fstab

# 5. Модули ядра
# overlay      файловая система контейнерных слоёв
# br_netfilter разрешает iptables фильтровать трафик сетевых мостов
# Модуль может быть встроен в ядро (например, в WSL) — тогда modprobe
# ничего не загрузит, но и не нужен. Проверяем фактическую доступность.
modprobe overlay 2>/dev/null || true
if ! grep -qw overlay /proc/filesystems; then
    echo ""
    echo "ОШИБКА: overlayfs недоступна (нет ни модуля, ни встроенной поддержки)"
    exit 1
fi

modprobe br_netfilter 2>/dev/null || true
if [ ! -e /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
    echo ""
    echo "ОШИБКА: br_netfilter недоступен (нет ни модуля, ни встроенной поддержки)"
    exit 1
fi

# прописываем на загрузку только то, что реально является модулем
# (встроенные в ядро в lsmod не попадают и в modules-load.d не нужны)
: > /etc/modules-load.d/k8s.conf
lsmod | grep -q '^overlay'       && echo "\noverlay" >> /etc/modules-load.d/k8s.conf
lsmod | grep -q '^br_netfilter'  && echo "\nbr_netfilter" >> /etc/modules-load.d/k8s.conf

# 6. Параметры сети
# без ip_forward пакеты подов не покидают ноду,
# без bridge-nf-call-* правила iptables не применяются к мостам.
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system > /dev/null

echo ""
echo "Готово. Проверка: sudo bash tests/test-01-node-base.sh $NODE_HOSTNAME"
