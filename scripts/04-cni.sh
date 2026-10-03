#!/usr/bin/env bash
# ============================================================================
# 04-cni.sh
# Этап 4: CNI flannel — pod-сеть кластера.
# После установки нода становится Ready и запускается CoreDNS.
# Запуск: bash scripts/04-cni.sh   (sudo не нужен)
# ============================================================================

set -euo pipefail

FLANNEL_VERSION="latest"   # для воспроизводимости можно зафиксировать версию, напр. v0.27.0
NODE_NAME="$(hostname)"

# 1. Kubeconfig
# если запустили через sudo, kubectl смотрел бы в /root/.kube — переводим
# на kubeconfig реального пользователя
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    export KUBECONFIG="$USER_HOME/.kube/config"
fi

# 2. Установка flannel
# манифест рассчитан на pod CIDR 10.244.0.0/16,
# он должен совпадать с --pod-network-cidr из kubeadm init (этап 3)
echo -e "\n Устанавливаю flannel..."
kubectl apply -f "https://github.com/flannel-io/flannel/releases/${FLANNEL_VERSION}/download/kube-flannel.yml"

# 3. Ждём поды flannel
# в свежих версиях namespace kube-flannel, в старых kube-system
if kubectl get namespace kube-flannel > /dev/null 2>&1; then
    FLANNEL_NS=kube-flannel
else
    FLANNEL_NS=kube-system
fi
echo -e "\n Жду готовности подов flannel (тянутся образы, может занять пару минут)..."
kubectl -n "$FLANNEL_NS" wait --for=condition=Ready pod -l app=flannel --timeout=600s

# 4. Ждём Ready ноды
echo -e "\n Жду Ready ноды $NODE_NAME..."
kubectl wait --for=condition=Ready "node/$NODE_NAME" --timeout=300s

echo -e "\n Готово. Проверка: bash tests/test-04-cni.sh"
