#!/usr/bin/env bash
# ============================================================================
# test-07-monitoring.sh
# Тест этапа 7: Prometheus работает и собирает метрики node-exporter.
# Запуск БЕЗ sudo: bash tests/test-07-monitoring.sh
# ============================================================================

set -uo pipefail

source "$(dirname "$0")/lib.sh"

echo "Этап 7: мониторинг (Prometheus + node-exporter)"
echo ""

check "deployment prometheus готов"            "[ \"\$(kubectl -n monitoring get deployment prometheus -o jsonpath='{.status.readyReplicas}')\" = 1 ]"
check "node-exporter запущен"                  "kubectl -n monitoring get pods -l app=node-exporter --no-headers | grep -q Running"
check "service prometheus существует"          "kubectl -n monitoring get service prometheus -o name"
check "service node-exporter существует"       "kubectl -n monitoring get service node-exporter -o name"

# запросы к API Prometheus изнутри пода
# первый скрейп приходит не мгновенно (scrape_interval 15s) — ждём до 90 с
check "Prometheus видит target node-exporter"  "retry 90 \"kubectl exec -n monitoring deployment/prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=up' | grep -q node-exporter\""
check "target node-exporter UP (up = 1)"       "retry 90 \"kubectl exec -n monitoring deployment/prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22node-exporter%22%7D' | grep -q '\\\"1\\\"'\""
check "метрика node_cpu_seconds_total отдаётся" "retry 90 \"kubectl exec -n monitoring deployment/prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=node_cpu_seconds_total' | grep -q node_cpu_seconds_total\""

echo ""
echo "Справочно — поды мониторинга:"
kubectl -n monitoring get pods 2>/dev/null || true
echo ""

finish
