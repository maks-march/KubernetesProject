#!/usr/bin/env bash
# ============================================================================
# 06-gateway.sh
# Этап 6: доступ к приложению через Kubernetes Gateway API.
#   1) MetalLB (LoadBalancer для bare-metal) + пул адресов
#   2) Envoy Gateway (реализация Gateway API)
#   3) Gateway + HTTPRoute (k8s/gateway.yaml)
# Манифесты MetalLB и Envoy Gateway скачаны на этапе 2 (deps/).
# Запуск: bash scripts/06-gateway.sh   (sudo не нужен)
# ============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

# 1. Kubeconfig (если запустили через sudo)
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    export KUBECONFIG="$USER_HOME/.kube/config"
fi

# 2. Проверяем зависимости из этапа 2
for f in deps/metallb-native.yaml deps/envoy-gateway-install.yaml; do
    if [ ! -s "$f" ]; then
        echo ""
        echo "ОШИБКА: $f не найден. Сначала выполни scripts/02-packages.sh"
        exit 1
    fi
done

# 3. MetalLB
# На bare-metal kubeadm нет LoadBalancer — без него Service Gateway
# не получит внешний IP. MetalLB выдаёт IP из пула в L2-режиме.
echo ""
echo "Устанавливаю MetalLB из deps/metallb-native.yaml..."
kubectl apply -f deps/metallb-native.yaml
kubectl -n metallb-system wait --for=condition=Ready pod --all --timeout=600s

# 4. Пул адресов для MetalLB
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

# 5. Envoy Gateway — реализация Gateway API
echo ""
echo "Устанавливаю Envoy Gateway из deps/envoy-gateway-install.yaml (тянутся образы)..."
kubectl apply --server-side -f deps/envoy-gateway-install.yaml
kubectl -n envoy-gateway-system wait --for=condition=Available deployment/envoy-gateway --timeout=600s

# 6. Gateway + HTTPRoute
echo ""
echo "Применяю Gateway и HTTPRoute..."
kubectl apply -f k8s/nginx-deployment.yaml \
               -f k8s/nginx-index.yaml \
               -f k8s/nginx-service.yaml   # приложение (на случай запуска этапа отдельно)
kubectl apply -f k8s/gateway.yaml          # GatewayClass + Gateway + HTTPRoute (CRD уже есть)

# 7. Ждём внешний IP у Gateway
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
    echo ""
    echo "Диагностика:"
    echo "--- GatewayClass (ожидаем: eg с контроллером envoy)"
    kubectl get gatewayclass 2>&1 || true
    echo "--- Поды Envoy Gateway"
    kubectl -n envoy-gateway-system get pods 2>&1 || true
    echo "--- Service envoy (LOADBALANCER: ждём внешний IP)"
    kubectl get svc 2>/dev/null | grep -E 'NAME|envoy' || true
    echo "--- Поды MetalLB (controller + speaker)"
    kubectl -n metallb-system get pods 2>&1 || true
    echo "--- Пул адресов и L2"
    kubectl get ipaddresspool,l2advertisement -n metallb-system 2>&1 || true
    echo "--- События Service envoy"
    ENVOY_SVC="$(kubectl get svc 2>/dev/null | awk '/^envoy/{print $1}' | head -1)"
    [ -n "$ENVOY_SVC" ] && kubectl describe svc "$ENVOY_SVC" 2>&1 | tail -15 || true
    exit 1
fi

# 8. Ждём, пока Gateway станет PROGRAMMED и поднимется его прокси Envoy
# IP выдаётся сразу, но data plane (Deployment envoy-<gw>) создаётся следом:
# без этого ожидания первый же curl получает connection refused,
# и тест этапа падает, хотя через минуту всё работает.
echo ""
echo "Жду готовности Gateway (condition Programmed)..."
kubectl wait --for=condition=Programmed gateway/app-gateway --timeout=300s || true

echo "Жду поды прокси Envoy для app-gateway..."
for i in $(seq 1 60); do
    PROXY_DEPLOY="$(kubectl -n envoy-gateway-system get deploy \
        -l gateway.envoyproxy.io/owning-gateway-name=app-gateway \
        -o name 2>/dev/null | head -1)"
    [ -n "$PROXY_DEPLOY" ] && break
    sleep 3
done
if [ -n "${PROXY_DEPLOY:-}" ]; then
    kubectl -n envoy-gateway-system rollout status "$PROXY_DEPLOY" --timeout=300s || true
fi

# 9. Ждём реального ответа 200 по внешнему IP (до 3 минут)
echo ""
echo "Проверяю ответ http://${GW_IP}/ ..."
HTTP_OK=0
for i in $(seq 1 60); do
    if curl -sf -o /dev/null --max-time 5 "http://${GW_IP}/"; then
        HTTP_OK=1
        break
    fi
    sleep 3
done
if [ "$HTTP_OK" -ne 1 ]; then
    echo "ОШИБКА: Gateway получил IP ${GW_IP}, но HTTP не отвечает за 3 минуты"
    echo ""
    echo "Диагностика:"
    kubectl get gateway app-gateway -o wide 2>&1 || true
    kubectl describe gateway app-gateway 2>&1 | tail -20 || true
    kubectl -n envoy-gateway-system get pods 2>&1 || true
    exit 1
fi
echo "HTTP 200 получен"

echo ""
echo "Готово. Проверка приложения через Gateway API:"
echo "  curl http://${GW_IP}/"
echo "Ожидаемый ответ: Hello World!"
