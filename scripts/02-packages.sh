#!/usr/bin/env bash
# ============================================================================
# 02-packages.sh
# Этап 2: пакеты, окружение и зависимости (манифесты в deps/).
# Запуск: sudo bash scripts/02-packages.sh
# ============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

K8S_MINOR="v1.37"
METALLB_VERSION="v0.16.1"
ENVOY_GATEWAY_VERSION="v1.5.0"
FLANNEL_VERSION="latest"   # можно зафиксировать конкретный релиз, напр. v0.27.0
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
echo ""
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.kubernetes.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

# 4. Пакеты Kubernetes
# hold запрещает apt обновлять их при общем apt upgrade:
# компоненты кластера должны обновляться осознанно, а не вразнобой.
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# 5. Манифесты зависимостей
# Скачиваем заранее в deps/, чтобы этапы 4 и 6 применяли локальные файлы:
# версии закреплены здесь, деплой не зависит от внешних URL.
mkdir -p deps
echo ""
echo "Скачиваю манифесты: flannel, MetalLB, Envoy Gateway..."
curl -fL --retry 3 -o deps/kube-flannel.yml \
  "https://github.com/flannel-io/flannel/releases/${FLANNEL_VERSION}/download/kube-flannel.yml"
curl -fL --retry 3 -o deps/metallb-native.yaml \
  "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
curl -fL --retry 3 -o deps/envoy-gateway-install.yaml \
  "https://github.com/envoyproxy/gateway/releases/download/${ENVOY_GATEWAY_VERSION}/install.yaml"

# скрипт запущен через sudo — файлы принадлежат root, отдаём пользователю
if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER":"$SUDO_USER" deps
fi

echo ""
echo "Готово. Проверка: sudo bash tests/test-02-packages.sh"
