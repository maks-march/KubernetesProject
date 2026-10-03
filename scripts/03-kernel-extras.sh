#!/usr/bin/env bash
# ============================================================================
# 03-kernel-extras.sh
# Этап 3 (применяется при ошибках kubeadm/CNI): модули ядра и sysctl.
# Ошибки, при которых нужен этот скрипт:
#   bridge-nf-call-iptables is not set  -> нужен br_netfilter и sysctl
#   ip_forward is not enabled           -> нужен sysctl
# Запуск: sudo bash scripts/03-kernel-extras.sh
# ============================================================================

set -euo pipefail

# 1. Модули ядра
# overlay      файловая система контейнерных слоёв
# br_netfilter разрешает iptables фильтровать трафик сетевых мостов
# modprobe грузит модуль сейчас, modules-load.d грузит его при старте системы.
modprobe overlay
modprobe br_netfilter

cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

# 2. Параметры сети
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system > /dev/null

echo "Готово. Проверка: sudo bash tests/test-03-kernel-extras.sh"
