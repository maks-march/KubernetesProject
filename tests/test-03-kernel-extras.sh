#!/usr/bin/env bash
# ============================================================================
# test-03-kernel-extras.sh — тест этапа 2: модули ядра + sysctl
# Запуск:  sudo bash tests/test-03-kernel-extras.sh
# ============================================================================
set -uo pipefail

source "$(dirname "$0")/lib.sh"

echo "Этап 2: ядро для Kubernetes (модули + sysctl)"
echo ""

check "модуль overlay загружен"                     "lsmod | grep -q '^overlay'"
check "модуль br_netfilter загружен"                "lsmod | grep -q '^br_netfilter'"
check "модули прописаны на загрузку: overlay"        "grep -q overlay /etc/modules-load.d/k8s.conf"
check "модули прописаны на загрузку: br_netfilter"   "grep -q br_netfilter /etc/modules-load.d/k8s.conf"
check "sysctl: bridge-nf-call-iptables = 1"         "[ \"\$(sysctl -n net.bridge.bridge-nf-call-iptables)\" = 1 ]"
check "sysctl: bridge-nf-call-ip6tables = 1"        "[ \"\$(sysctl -n net.bridge.bridge-nf-call-ip6tables)\" = 1 ]"
check "sysctl: ip_forward = 1"                      "[ \"\$(sysctl -n net.ipv4.ip_forward)\" = 1 ]"
check "sysctl-конфиг k8s.conf существует"           "[ -f /etc/sysctl.d/k8s.conf ]"

finish
