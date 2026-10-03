#!/usr/bin/env bash
# ============================================================================
# test-deploy.sh
# Прогон всех тестов решения (этапы 1-8) со сводкой.
#   этапы 1-2 — системные, запускаются с sudo (root)
#   этапы 3-8 — кластерные, запускаются от обычного пользователя
#               (нужен его ~/.kube/config)
#
# Запуск (любой вариант):
#   bash test-deploy.sh [имя-ноды]        # sudo будет запрошен сам
#   sudo bash test-deploy.sh [имя-ноды]   # этапы 3-8 уйдут под $SUDO_USER
#
# имя ноды по умолчанию = текущий hostname
# ============================================================================

set -uo pipefail

cd "$(dirname "$0")"

NODE_HOSTNAME="${1:-$(hostname)}"

# --- как повышать/понижать права -------------------------------------------
# пользователь, под которым должны идти кластерные тесты
REAL_USER="${SUDO_USER:-$(id -un)}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

if [ "$(id -u)" -eq 0 ]; then
    AS_ROOT=()                                  # уже root
    if [ "$REAL_USER" != "root" ]; then
        AS_USER=(sudo -u "$REAL_USER" env "HOME=$USER_HOME" \
                 "KUBECONFIG=$USER_HOME/.kube/config")
    else
        AS_USER=()
    fi
else
    if ! command -v sudo >/dev/null 2>&1; then
        echo "ОШИБКА: нужен sudo или запуск от root (этапы 1-2 системные)" >&2
        exit 1
    fi
    AS_ROOT=(sudo)
    AS_USER=()
fi

# заранее спросим пароль sudo, чтобы он не всплыл посреди сводки
if [ ${#AS_ROOT[@]} -gt 0 ]; then
    sudo -v || { echo "ОШИБКА: нет прав sudo" >&2; exit 1; }
fi

TOTAL=0
PASSED=0
declare -a SUMMARY

# run_test <режим root|user> <файл теста> [аргументы теста...]
run_test() {
    local mode="$1" t="$2"; shift 2
    TOTAL=$((TOTAL + 1))
    echo ""
    echo ">>> ${t}"
    local rc=0
    if [ "$mode" = root ]; then
        "${AS_ROOT[@]}" bash "$t" "$@" || rc=$?
    else
        "${AS_USER[@]}" bash "$t" "$@" || rc=$?
    fi
    if [ "$rc" -eq 0 ]; then
        PASSED=$((PASSED + 1))
        SUMMARY+=("[PASS] ${t}")
    else
        SUMMARY+=("[FAIL] ${t}")
    fi
}

echo "=============================================="
echo "Тесты KubernetesProject (этапы 1-8)"
echo "Нода: ${NODE_HOSTNAME}   Пользователь кластера: ${REAL_USER}"
echo "=============================================="

run_test root tests/test-01-node-base.sh "$NODE_HOSTNAME"
run_test root tests/test-02-packages.sh
run_test user tests/test-03-cluster-init.sh
run_test user tests/test-04-cni.sh
run_test user tests/test-05-nginx.sh
run_test user tests/test-06-gateway.sh
run_test user tests/test-07-monitoring.sh
run_test user tests/test-08-logging.sh

echo ""
echo "=============================================="
echo "СВОДКА: ${PASSED}/${TOTAL} этапов пройдено"
echo "=============================================="
printf '  %s\n' "${SUMMARY[@]}"
echo ""

[ "$PASSED" -eq "$TOTAL" ] && exit 0 || exit 1
