#!/usr/bin/env bash
# ============================================================================
# 01-node-base.sh — этап 1: hostname + /etc/hosts + swap off
# Запуск:  sudo bash scripts/01-node-base.sh k8s-node
# ============================================================================
set -euo pipefail

NODE_HOSTNAME="${1:?Usage: 01-node-base.sh <hostname>}"

# --- 0. Предусловие: ОС должна работать под systemd -------------------------
if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    echo "ОШИБКА: systemd не является PID 1 — kubeadm-окружение не поддерживается."
    exit 1
fi

# --- 1. Имя ноды -------------------------------------------------------------
hostnamectl set-hostname "$NODE_HOSTNAME"

# --- 2. /etc/hosts (стиль Ubuntu: 127.0.1.1, без дублей) --------------------
if ! grep -q "$NODE_HOSTNAME" /etc/hosts; then
    echo "127.0.1.1 $NODE_HOSTNAME" >> /etc/hosts
fi

# --- 3. Swap off: сейчас + навсегда (комментируем в fstab) ------------------
swapoff -a
# закомментировать все строки со swap в fstab — иначе вернётся после ребута
sed -i.bak '/\bswap\b/s/^/#/' /etc/fstab

echo "Готово! Проверка: sudo bash tests/test-01-node-base.sh $NODE_HOSTNAME"
