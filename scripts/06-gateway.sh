#!/usr/bin/env bash
# ============================================================================
# 06-gateway.sh
# Этап 6: доступ к приложению через Kubernetes Gateway API.
#   1) MetalLB (LoadBalancer для bare-metal) + пул адресов
#   2) Envoy Gateway (реализация Gateway API)
#   3) Gateway + HTTPRoute (k8s/gateway.yaml)
# Запуск: bash scripts/06-gateway.sh   (sudo не нужен)
# ============================================================================

set -euo pipefail

METALLB_VERSION="v0.16.1"
ENVOY_GATEWAY_VERSION="v1.5.0"

cd "$(dirname "$0")/.."

# 1. Kubeconfig (если запустили через sudo)
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    export KUBECONFIG="$USER_HOME/.kube/config"
fi

# 2. MetalLB
# На bare-metal kubeadm нет LoadBalancer — без него Service Gateway
# не получит внешний IP. MetalLB выдаёт IP из пула в L2-режиме.
echo ""
echo "Устанавливаю MetalLB ${METALLB_VERSION}..."
kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl -n metallb-system wait --for=condition=Ready pod --all --timeout=600s

# 3. Пул адресов для MetalLB
# Берём подсеть ноды и выделяем диапазон .200-.250:
# работает в любой сети, где развёрнут кластер.
NODE_IP="$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')"
PREFIX="${NODE_IP%.*}"
echo ""
echo "Пул MetalLB: ${PREFIX}.200-${PREFIX}.250 (подсеть ноды ${PREFIX}.0/24)"
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: gateway-pool
  namespace: metallb-system
spec:
  addresses:
    - ${PREFIX}.200-${PREFIX}.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: gateway-l2
  namespace: metallb-system
EOF

# 4. Envoy Gateway — реализация Gateway API
echo ""
echo "Устанавливаю Envoy Gateway ${ENVOY_GATEWAY_VERSION} (тянутся образы)..."
kubectl apply --server-side -f "https://github.com/envoyproxy/gateway/releases/download/${ENVOY_GATEWAY_VERSION}/install.yaml"
kubectl -n envoy-gateway-system wait --for=condition=Available deployment/envoy-gateway --timeout=600s

# 5. Gateway + HTTPRoute
echo ""
echo "Применяю Gateway и HTTPRoute..."
kubectl apply -f k8s/gateway.yaml
kubectl apply -f k8s/          # манифесты приложения (index-ConfigMap и пр.)

# 6. Ждём внешний IP у Gateway
echo ""
echo "Жду внешний IP у Gateway (MetalLB + Envoy)..."
GW_IP=""
for i in $(seq 1 60); do
    GW_IP="$(kubectl get gateway app-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
    [ -n "$GW_IP" ] && break
    sleep 3
done
if [ -z "$GW_IP" ]; then
    echo "ОШИБКА: Gateway не получил IP за 3 минуты"
    exit 1
fi

echo ""
echo "Готово. Проверка приложения через Gateway API:"
echo "  curl http://${GW_IP}/"
echo "Ожидаемый ответ: Hello World!"
