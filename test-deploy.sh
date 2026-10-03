#!/usr/bin/env bash
# ============================================================================
# run-all.sh
# Прогон всех тестов кластера (этапы 3-8) со сводкой.
# Тесты 1-2 системные, запускаются с sudo отдельно (см. README).
# Запуск БЕЗ sudo: bash tests/run-all.sh
# ============================================================================

set -uo pipefail

cd "$(dirname "$0")/.."

TOTAL=0
PASSED=0
declare -a SUMMARY

for t in tests/test-03-cluster-init.sh \
         tests/test-04-cni.sh \
         tests/test-05-nginx.sh \
         tests/test-06-gateway.sh \
         tests/test-07-monitoring.sh \
         tests/test-08-logging.sh; do
    TOTAL=$((TOTAL + 1))
    echo ""
    echo ">>> ${t}"
    if bash "$t"; then
        PASSED=$((PASSED + 1))
        SUMMARY+=("[PASS] ${t}")
    else
        SUMMARY+=("[FAIL] ${t}")
    fi
done

echo ""
echo "=============================================="
echo "СВОДКА: ${PASSED}/${TOTAL} этапов пройдено"
echo "=============================================="
printf '  %s\n' "${SUMMARY[@]}"
echo ""

[ "$PASSED" -eq "$TOTAL" ] && exit 0 || exit 1
