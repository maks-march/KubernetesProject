#!/usr/bin/env bash
# ============================================================================
# test-08-logging.sh
# Тест этапа 8: Fluentd собирает логи nginx (сквозная проверка).
# Запуск БЕЗ sudo: bash tests/test-08-logging.sh
# Требует пройденный этап 6 (Gateway).
# ============================================================================

set -uo pipefail

source "$(dirname "$0")/lib.sh"

echo "Этап 8: логирование (Fluentd)"
echo ""

check "namespace logging существует"        "kubectl get namespace logging -o name"
check "fluentd запущен"                     "kubectl -n logging get pods -l app=fluentd --no-headers | grep -q Running"
check "configmap fluentd-config существует" "kubectl -n logging get configmap fluentd-config -o name"

# сквозная проверка: уникальный запрос → запись в собранных логах
GW_IP="$(kubectl get gateway app-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
if [ -z "$GW_IP" ]; then
    echo ""
    echo "ВНИМАНИЕ: Gateway без IP — сначала выполни этап 6"
    finish
fi

TRACE="k8sproject-$(date +%s)"

# запрос повторяем на каждой итерации: если Fluentd ещё не обнаружил файл лога,
# единственный ранний запрос мог бы не попасть в сбор
check "запрос через Gateway попал в собранные логи" \
      "retry 120 \"curl -sf --max-time 5 'http://${GW_IP}/?trace=${TRACE}' > /dev/null; kubectl -n logging exec daemonset/fluentd -- sh -c \\\"grep -qh '${TRACE}' /var/log/fluentd/nginx-access*\\\"\""

finish
