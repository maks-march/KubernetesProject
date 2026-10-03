#!/usr/bin/env bash
# ============================================================================
# 01-node-base.sh
# Этап 1: hostname, /etc/hosts, выключение swap.
# Запуск: sudo bash scripts/01-node-base.sh k8s-node
# ============================================================================

set -euo pipefail

NODE_HOSTNAME="${1:?Usage: 01-node-base.sh <hostname>}"

# 1. Без systemd kubeadm работать не будет
if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    echo "ОШИБКА: systemd не является PID 1"
    exit 1
fi

# 2. Имя ноды
hostnamectl set-hostname "$NODE_HOSTNAME"

# 3. Запись в /etc/hosts, если её ещё нет
if ! grep -q "$NODE_HOSTNAME" /etc/hosts; then
    echo "127.0.1.1 $NODE_HOSTNAME" >> /etc/hosts
fi

# 4. Swap
# kubelet не работает со включённым swap.
# Выключаем сейчас и комментируем в fstab, чтобы не вернулся после ребута.
swapoff -a
sed -i.bak '/\bswap\b/s/^/#/' /etc/fstab

echo "Готово. Проверка: sudo bash tests/test-01-node-base.sh $NODE_HOSTNAME"
