#!/usr/bin/env bash
# ============================================================================
# 08-logging.sh
# Этап 8: сбор логов приложения — Fluentd (access/error-логи nginx).
# Запуск: bash scripts/08-logging.sh   (sudo не нужен)
# ============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

# 1. Kubeconfig (если запустили через sudo)
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    export KUBECONFIG="$USER_HOME/.kube/config"
fi

# 2. Применяем манифесты логирования
echo ""
echo "Разворачиваю Fluentd..."
kubectl apply -f k8s/logging/

# 3. Ждём готовности
echo ""
echo "Жду готовности Fluentd (тянутся образы)..."
kubectl -n logging rollout status daemonset/fluentd --timeout=600s

# 4. Сквозная проверка: запрос через Gateway должен попасть в собранные логи
GW_IP="$(kubectl get gateway app-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
if [ -n "$GW_IP" ]; then
    TRACE="k8sproject-$(date +%s)"
    echo ""
    echo "Проверка: запрос http://${GW_IP}/?trace=${TRACE}"
    curl -sf "http://${GW_IP}/?trace=${TRACE}" > /dev/null || true
    echo "Жду сбора лога (10 секунд, flush_interval = 5s)..."
    sleep 10
    if kubectl -n logging exec daemonset/fluentd -- sh -c "grep -h '${TRACE}' /var/log/fluentd/nginx-access*" 2>/dev/null; then
        echo ""
        echo "Запись найдена в собранных логах"
    else
        echo "Запись пока не найдена, прогони тест позже: bash tests/test-08-logging.sh"
    fi
fi

echo ""
echo "Готово. Проверка: bash tests/test-08-logging.sh"
