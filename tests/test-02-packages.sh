#!/usr/bin/env bash
# ============================================================================
# test-02-packages.sh — тест этапа 2: containerd + пакеты Kubernetes
# Запуск:  sudo bash tests/test-02-packages.sh
# ============================================================================
set -uo pipefail

source "$(dirname "$0")/lib.sh"

echo "Этап 2: пакеты и окружение (containerd + kubeadm/kubelet/kubectl)"
echo ""

check "containerd установлен"                    "command -v containerd"
check "containerd-сервис запущен"                "systemctl is-active --quiet containerd"
check "containerd: SystemdCgroup = true"         "grep -q 'SystemdCgroup = true' /etc/containerd/config.toml"
check "репозиторий Kubernetes добавлен"          "[ -f /etc/apt/sources.list.d/kubernetes.list ]"
check "kubeadm установлен"                       "command -v kubeadm"
check "kubelet установлен"                       "command -v kubelet"
check "kubectl установлен"                       "command -v kubectl"
check "пакеты k8s зафиксированы (hold)"          "apt-mark showhold | grep -q kubelet"
check "версии kubeadm и kubelet совпадают"       "[ \"\$(kubeadm version -o short 2>/dev/null)\" = \"\$(kubelet --version | awk '{print \$2}')\" ]"

finish
