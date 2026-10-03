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
curl -sf "http://${GW_IP}/?trace=${TRACE}" > /dev/null || true
sleep 12

LOG_LINE="$(kubectl -n logging exec daemonset/fluentd -- sh -c "grep -h '${TRACE}' /var/log/fluentd/nginx-access*" 2>/dev/null || true)"
# $ экранирован: переменная разворачивается внутри кавычек при eval
check "запрос через Gateway попал в собранные логи" "[ -n \"\$LOG_LINE\" ]"

finish
