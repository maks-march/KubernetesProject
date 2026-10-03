#!/usr/bin/env bash
# ============================================================================
# test-01-node-base.sh
# Тест этапа 1: настройка ноды (hostname, hosts, swap, ядро)
# Запуск: sudo bash tests/test-01-node-base.sh k8s-node
# ============================================================================

set -uo pipefail

NODE_HOSTNAME="${1:?Usage: test-01-node-base.sh <hostname>}"

source "$(dirname "$0")/lib.sh"

echo "Этап 1: настройка ноды"
echo "Ожидания: hostname=$NODE_HOSTNAME"
echo ""

check "systemd запущен (PID 1)"                       "[ \"\$(ps -p 1 -o comm=)\" = systemd ]"
check "hostname = $NODE_HOSTNAME"                     "[ \"\$(hostname)\" = \"$NODE_HOSTNAME\" ]"
check "в /etc/hosts есть запись ноды"                 "grep -q \"$NODE_HOSTNAME\" /etc/hosts"
check "swap выключен (Swap: 0)"                       "[ \"\$(free -m | awk '/Swap:/{print \$2}')\" = 0 ]"
check "в fstab нет активных swap-строк"               "! grep -vE '^\s*#' /etc/fstab | grep -w swap"

# overlayfs может быть модулем или быть встроенной в ядро (WSL),
# поэтому проверяем /proc/filesystems, а не lsmod
check "overlayfs доступна"                            "grep -qw overlay /proc/filesystems"
check "br_netfilter активен (есть sysctl bridge-nf-call-iptables)" "[ -e /proc/sys/net/bridge/bridge-nf-call-iptables ]"
check "sysctl: bridge-nf-call-iptables = 1"           "[ \"\$(sysctl -n net.bridge.bridge-nf-call-iptables)\" = 1 ]"
check "sysctl: ip_forward = 1"                        "[ \"\$(sysctl -n net.ipv4.ip_forward)\" = 1 ]"

finish
