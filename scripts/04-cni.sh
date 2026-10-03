#!/usr/bin/env bash
# ============================================================================
# 04-cni.sh
# Этап 4: CNI flannel — pod-сеть кластера.
# После установки нода становится Ready и запускается CoreDNS.
# Запуск: bash scripts/04-cni.sh   (sudo не нужен)
# ============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

# 1. Kubeconfig
# если запустили через sudo, kubectl смотрел бы в /root/.kube — переводим
# на kubeconfig реального пользователя
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    export KUBECONFIG="$USER_HOME/.kube/config"
fi

# 2. Установка flannel
# манифест скачан на этапе 2 в deps/
if [ ! -s deps/kube-flannel.yml ]; then
    echo ""
    echo "ОШИБКА: deps/kube-flannel.yml не найден. Сначала выполни scripts/02-packages.sh"
    exit 1
fi
echo ""
echo "Устанавливаю flannel из deps/kube-flannel.yml..."
kubectl apply -f deps/kube-flannel.yml

# 3. Ждём поды flannel
# в свежих версиях namespace kube-flannel, в старых kube-system
if kubectl get namespace kube-flannel > /dev/null 2>&1; then
    FLANNEL_NS=kube-flannel
else
    FLANNEL_NS=kube-system
fi
echo ""
echo "Жду создания подов flannel..."
# kubectl wait сразу после apply падает с "no matching resources found":
# DaemonSet ещё не успел создать поды. Сначала дожидаемся их появления.
for i in $(seq 1 60); do
    if [ -n "$(kubectl -n "$FLANNEL_NS" get pods -l app=flannel \
                 -o name 2>/dev/null)" ]; then
        break
    fi
    sleep 2
done

echo "Жду готовности подов flannel (тянутся образы, может занять пару минут)..."
kubectl -n "$FLANNEL_NS" wait --for=condition=Ready pod -l app=flannel --timeout=600s

# 4. Ждём Ready ноды
NODE_NAME="$(hostname | tr 'A-Z' 'a-z')"
echo ""
echo "Жду Ready ноды $NODE_NAME..."
kubectl wait --for=condition=Ready "node/$NODE_NAME" --timeout=300s

# 5. Ждём интерфейс flannel.1 и CoreDNS
# нода становится Ready раньше, чем поднимается vxlan-интерфейс
# и доезжают поды CoreDNS, — без ожидания тест этапа падает с первого раза
echo ""
echo "Жду интерфейс flannel.1..."
for i in $(seq 1 60); do
    ip link show flannel.1 > /dev/null 2>&1 && break
    sleep 3
done

echo "Жду готовности CoreDNS..."
kubectl -n kube-system rollout status deployment/coredns --timeout=300s

echo ""
echo "Готово. Проверка: bash tests/test-04-cni.sh"
