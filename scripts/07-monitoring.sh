#!/usr/bin/env bash
# ============================================================================
# 07-monitoring.sh
# Этап 7: мониторинг — Prometheus + node-exporter (метрики ноды).
# Запуск: bash scripts/07-monitoring.sh   (sudo не нужен)
# ============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

# 1. Kubeconfig (если запустили через sudo)
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    export KUBECONFIG="$USER_HOME/.kube/config"
fi

# 2. Применяем манифесты мониторинга
echo ""
echo "Разворачиваю Prometheus и node-exporter..."
kubectl apply -f k8s/monitoring/

# 3. Ждём готовности
echo ""
echo "Жду готовности Prometheus (тянутся образы)..."
kubectl -n monitoring rollout status deployment/prometheus --timeout=600s

echo ""
echo "Жду готовности node-exporter..."
kubectl -n monitoring rollout status daemonset/node-exporter --timeout=600s

# 4. Даём время первому сбору метрик (scrape_interval 15s)
echo ""
echo "Жду первый цикл сбора метрик (30 секунд)..."
sleep 30

echo ""
echo "Готово. Проверка: bash tests/test-07-monitoring.sh"
echo "Дашборд вручную: kubectl -n monitoring port-forward svc/prometheus 9090:9090"
echo "Затем в браузере: http://localhost:9090/targets"
