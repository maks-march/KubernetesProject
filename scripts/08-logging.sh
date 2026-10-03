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
# namespace logging объявлен первым документом в fluentd.yaml,
# но создаём его явно — на случай добавления новых файлов в k8s/logging/
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/logging/

# при изменении ConfigMap под сам не перечитывает конфиг — рестартуем
kubectl -n logging rollout restart daemonset/fluentd

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
    echo "Жду появления записи в собранных логах (до 2 минут)..."
    # запрос повторяем в каждой итерации: Fluentd после старта
    # не сразу обнаруживает файл лога, и единственный ранний запрос
    # мог бы остаться незамеченным
    FOUND=0
    for i in $(seq 1 24); do
        curl -sf "http://${GW_IP}/?trace=${TRACE}" > /dev/null || true
        sleep 5
        if kubectl -n logging exec daemonset/fluentd -- \
               sh -c "grep -qh '${TRACE}' /var/log/fluentd/nginx-access*" 2>/dev/null; then
            FOUND=1
            break
        fi
    done
    if [ "$FOUND" -eq 1 ]; then
        echo "Запись найдена в собранных логах"
    else
        echo "Запись пока не найдена, прогони тест позже: bash tests/test-08-logging.sh"
    fi
fi

echo ""
echo "Готово. Проверка: bash tests/test-08-logging.sh"
