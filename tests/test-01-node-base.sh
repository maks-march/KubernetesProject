#!/usr/bin/env bash
# ============================================================================
# test-01-node-base.sh — тест этапа 1: hostname + hosts + swap off
# Запуск:  sudo bash tests/test-01-node-base.sh k8s-node
# ============================================================================
set -uo pipefail

NODE_HOSTNAME="${1:?Usage: test-01-node-base.sh <hostname>}"

source "$(dirname "$0")/lib.sh"

echo "Этап 1: база ноды (hostname + hosts + swap off)"
echo "Ожидания: hostname=$NODE_HOSTNAME"
echo ""

check "systemd запущен (PID 1 = systemd)"              "[ \"\$(ps -p 1 -o comm=)\" = systemd ]"
check "hostname сейчас = $NODE_HOSTNAME"               "[ \"\$(hostname)\" = \"$NODE_HOSTNAME\" ]"
check "в /etc/hosts есть запись ноды"                  "grep -q \"$NODE_HOSTNAME\" /etc/hosts"
check "swap выключен сейчас (Swap: 0)"                 "[ \"\$(free -m | awk '/Swap:/{print \$2}')\" = 0 ]"
check "в fstab нет активных swap-строк"                "! grep -vE '^\s*#' /etc/fstab | grep -w swap"

finish
