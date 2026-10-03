#!/usr/bin/env bash
# ============================================================================
# test-06-gateway.sh
# Тест этапа 6: Gateway API работает, приложение доступно снаружи.
# Запуск БЕЗ sudo: bash tests/test-06-gateway.sh
# ============================================================================

set -uo pipefail

source "$(dirname "$0")/lib.sh"

GW_IP="$(kubectl get gateway app-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)"

echo "Этап 6: Gateway API (Envoy Gateway + MetalLB)"
echo "IP Gateway: ${GW_IP:-не получен}"
echo ""

check "GatewayClass eg существует"                 "kubectl get gatewayclass eg -o name"
check "Gateway app-gateway существует"             "kubectl get gateway app-gateway -o name"
check "Gateway получил внешний IP"                 "[ -n \"$GW_IP\" ]"
check "HTTPRoute nginx-route существует"           "kubectl get httproute nginx-route -o name"
check "HTTPRoute привязан к Gateway (Accepted)"    "[ \"\$(kubectl get httproute nginx-route -o jsonpath='{.status.parents[0].conditions[?(@.type==\"Accepted\")].status}')\" = True ]"
# до 90 с ожидания: прокси Envoy поднимается уже после выдачи IP
check "HTTP через Gateway отвечает 200"            "retry 90 \"curl -sf -o /dev/null --max-time 5 -w '%{http_code}' http://$GW_IP/ | grep -q 200\""
check "Приложение отдаёт Hello World!"             "retry 90 \"curl -sf --max-time 5 http://$GW_IP/ | grep -q 'Hello World'\""

echo ""
echo "Справочно — ресурсы Gateway API:"
kubectl get gatewayclass 2>/dev/null || true
kubectl get gateway 2>/dev/null || true
kubectl get httproute 2>/dev/null || true
echo ""

finish
