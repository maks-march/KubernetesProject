#!/usr/bin/env bash
# ============================================================================
# 02-packages.sh — этап 2: containerd + пакеты Kubernetes
# Запуск:  sudo bash scripts/02-packages.sh
# ============================================================================
set -euo pipefail

K8S_MINOR="v1.37"   # актуальный minor: https://pkgs.kubernetes.io
export DEBIAN_FRONTEND=noninteractive

# --- 1. Базовые пакеты + containerd ------------------------------------------
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg containerd

# --- 2. containerd: дефолтный конфиг + systemd cgroup driver ------------------
# kubelet работает с systemd-драйвером cgroup; если у containerd другой —
# kubelet не стартует. Поэтому обязательно true.
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# --- 3. Репозиторий Kubernetes -----------------------------------------------
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.kubernetes.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.kubernetes.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

# --- 4. Пакеты k8s + фиксация версий ------------------------------------------
apt-get update
apt-get install -y kubelet kubeadm kubectl
# hold: случайный apt upgrade не должен обновить k8s-компоненты сами по себе
apt-mark hold kubelet kubeadm kubectl

echo "Готово! Проверка: sudo bash tests/test-02-packages.sh"
