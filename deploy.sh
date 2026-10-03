#!/usr/bin/env bash
# ============================================================================
# deploy.sh
# Полное развёртывание решения (этапы 1-8) одной командой.
# Логика: каждый этап сначала проверяется тестом.
#   тест PASS -> этап уже настроен, пропускаем
#   тест FAIL -> применяем скрипт этапа -> тест снова -> FAIL = остановка
# Запуск: sudo bash deploy.sh [имя-ноды]
#   имя ноды по умолчанию = текущий hostname (менять не нужно)
# ============================================================================

set -euo pipefail

cd "$(dirname "$0")"

# имя ноды: аргумент или текущее (чтобы повторный запуск ничего не переименовал)
# Имя ноды Kubernetes обязано быть RFC 1123: только строчные буквы, цифры,
# "-" и ".". WSL по умолчанию даёт hostname вида DESKTOP-RGBCS78 — kubeadm
# init с таким именем падает на mark-control-plane:
#   error: nodes "DESKTOP-RGBCS78" not found
# (kubelet регистрирует ноду в нижнем регистре). Поэтому нормализуем.
normalize_node_name() {
    local raw="$1" out
    out="$(printf '%s' "$raw" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9.-' '-')"
    out="$(printf '%s' "$out" | sed -E 's/^[^a-z0-9]+//; s/[^a-z0-9]+$//')"
    [ -z "$out" ] && out="k8s-node"
    printf '%s' "$out"
}

NODE_HOSTNAME_RAW="${1:-$(hostname)}"
NODE_HOSTNAME="$(normalize_node_name "$NODE_HOSTNAME_RAW")"
if [ "$NODE_HOSTNAME" != "$NODE_HOSTNAME_RAW" ]; then
    echo "ПРИМЕЧАНИЕ: имя '${NODE_HOSTNAME_RAW}' недопустимо для Kubernetes,"
    echo "            использую '${NODE_HOSTNAME}' (нода будет переименована)"
fi

# деплой идёт под root, но kubectl должен видеть kubeconfig пользователя
REAL_USER="${SUDO_USER:-$(id -un)}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
export KUBECONFIG="${USER_HOME:-/root}/.kube/config"

echo "=============================================="
echo "Деплой KubernetesProject"
echo "Нода: ${NODE_HOSTNAME}"
echo "=============================================="

# stage "заголовок" "скрипт" "тест" [аргументы...]
stage() {
    local title="$1" script="$2" test="$3"
    shift 3

    echo ""
    echo ">>> ${title}"

    # тихая проверка: этап уже пройден?
    if bash "$test" "$@" > /dev/null 2>&1; then
        echo "    уже настроено, пропускаю"
        return 0
    fi

    # применяем этап
    bash "$script" "$@"

    # контрольная проверка с выводом
    if ! bash "$test" "$@"; then
        echo ""
        echo "ОШИБКА: этап не прошёл проверку после применения"
        exit 1
    fi
}

stage "Этап 1/8. Настройка ноды"        "scripts/01-node-base.sh"    "tests/test-01-node-base.sh"    "$NODE_HOSTNAME"
stage "Этап 2/8. Пакеты и окружение"    "scripts/02-packages.sh"     "tests/test-02-packages.sh"
stage "Этап 3/8. Кластер kubeadm"       "scripts/03-cluster-init.sh" "tests/test-03-cluster-init.sh"
stage "Этап 4/8. Pod-сеть (flannel)"    "scripts/04-cni.sh"          "tests/test-04-cni.sh"
stage "Этап 5/8. Приложение (nginx)"    "scripts/05-nginx.sh"        "tests/test-05-nginx.sh"
stage "Этап 6/8. Gateway API"           "scripts/06-gateway.sh"      "tests/test-06-gateway.sh"
stage "Этап 7/8. Мониторинг"            "scripts/07-monitoring.sh"   "tests/test-07-monitoring.sh"
stage "Этап 8/8. Логирование (Fluentd)" "scripts/08-logging.sh"      "tests/test-08-logging.sh"

echo ""
echo "=============================================="
echo "Развёртывание завершено"
echo "=============================================="

GW_IP="$(kubectl get gateway app-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"

echo ""
echo "Приложение:  curl http://${GW_IP:-<Gateway-IP>}/   (ожидание: Hello World!)"
echo "Все тесты:   sudo bash test-deploy.sh"
