#!/usr/bin/env bash
# ============================================================================
# 02-packages.sh
# Этап 2: containerd и пакеты Kubernetes.
# Запуск: sudo bash scripts/02-packages.sh
# ============================================================================

set -euo pipefail

K8S_MINOR="v1.37"
export DEBIAN_FRONTEND=noninteractive

# 1. Базовые пакеты и containerd
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg containerd

# 2. Containerd
# kubelet работает с systemd cgroup драйвером, поэтому containerd
# переключаем на него же, иначе kubelet не стартует.
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# 3. Репозиторий Kubernetes
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.kubernetes.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo -e "\n deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.kubernetes.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

# 4. Пакеты Kubernetes
# hold запрещает apt обновлять их при общем apt upgrade:
# компоненты кластера должны обновляться осознанно, а не вразнобой.
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo -e "\n Готово. Проверка: sudo bash tests/test-02-packages.sh"
