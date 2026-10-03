#!/usr/bin/env bash
# ============================================================================
# test-deploy.sh
# Прогон всех тестов решения (этапы 1-8).
#   этапы 1-2 — системные, запускаются с sudo (root)
#   этапы 3-8 — кластерные, запускаются от обычного пользователя
#               (нужен его ~/.kube/config)
#
# Вывод: по ходу прогона — одна строка на этап (OK / ошибки),
#        в конце — все ошибки подробно + общая сводка.
#        Полные логи каждого этапа: --verbose или файл в /tmp (путь в конце).
#
# Запуск:
#   bash test-deploy.sh [имя-ноды] [--verbose]
#   sudo bash test-deploy.sh [имя-ноды]   # этапы 3-8 уйдут под $SUDO_USER
# ============================================================================

set -uo pipefail

# ровные колонки для кириллицы (без UTF-8 локали bash считает байты)
if locale -a 2>/dev/null | grep -qi '^C\.utf-?8$'; then
    export LC_ALL=C.UTF-8
elif locale -a 2>/dev/null | grep -qi '^en_US\.utf-?8$'; then
    export LC_ALL=en_US.UTF-8
fi

cd "$(dirname "$0")"

VERBOSE=0
ARGS=()
for a in "$@"; do
    case "$a" in
        -v|--verbose) VERBOSE=1 ;;
        *) ARGS+=("$a") ;;
    esac
done
NODE_HOSTNAME="${ARGS[0]:-$(hostname)}"

# --- как повышать/понижать права -------------------------------------------
REAL_USER="${SUDO_USER:-$(id -un)}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

if [ "$(id -u)" -eq 0 ]; then
    AS_ROOT=()
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

if [ ${#AS_ROOT[@]} -gt 0 ]; then
    sudo -v || { echo "ОШИБКА: нет прав sudo" >&2; exit 1; }
fi

# логи текущего прогона: один фиксированный каталог, очищается при каждом старте
# (не копится мусор; каталог в .gitignore)
LOG_DIR="logs/test-deploy"
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
# чтобы логи не остались принадлежать root после sudo-запуска
[ "$(id -u)" -eq 0 ] && [ "$REAL_USER" != root ] && chown -R "$REAL_USER" logs 2>/dev/null
trap 'echo ""; echo "Логи этапов (перезаписываются при следующем запуске): $LOG_DIR/"' EXIT

TOTAL=0            # всего этапов
STAGES_OK=0        # этапов пройдено
CHECKS_OK=0        # проверок пройдено
CHECKS_FAIL=0      # проверок провалено
declare -a SUMMARY
declare -a ERRORS

# run_test <root|user> <название> <файл теста> [аргументы...]
run_test() {
    local mode="$1" title="$2" t="$3"; shift 3
    TOTAL=$((TOTAL + 1))
    local log="${LOG_DIR}/$(basename "$t").log"
    local rc=0

    printf '  %s%*s ... ' "$title" $(( ${#title} < 34 ? 34 - ${#title} : 1 )) ''

    if [ "$mode" = root ]; then
        "${AS_ROOT[@]}" bash "$t" "$@" > "$log" 2>&1 || rc=$?
    else
        "${AS_USER[@]}" bash "$t" "$@" > "$log" 2>&1 || rc=$?
    fi

    local p f
    p="$(grep -c '^  \[PASS\]' "$log")"
    f="$(grep -c '^  \[FAIL\]' "$log")"
    CHECKS_OK=$((CHECKS_OK + p))
    CHECKS_FAIL=$((CHECKS_FAIL + f))

    if [ "$rc" -eq 0 ]; then
        STAGES_OK=$((STAGES_OK + 1))
        echo "OK (проверок: ${p})"
        SUMMARY+=("$(printf '[PASS] %s%*s проверок: %s' "$title" $(( ${#title} < 32 ? 32 - ${#title} : 1 )) '' "$p")")
    else
        echo "ОШИБКИ (${f} из $((p + f)))"
        SUMMARY+=("$(printf '[FAIL] %s%*s ошибок: %s из %s' "$title" $(( ${#title} < 32 ? 32 - ${#title} : 1 )) '' "$f" "$((p + f))")")
        ERRORS+=("### ${title}   (${t}, лог: ${log})")
        if [ "$f" -gt 0 ]; then
            # строки [FAIL] вместе с их пояснениями (отступ 8 пробелов)
            # строка [FAIL] + её пояснения (следующие отступные строки)
            ERRORS+=("$(awk '/^  \[FAIL\]/{show=1;print;next} /^  \[PASS\]/{show=0;next} /^        /{if(show)print;next} {show=0}' "$log")")
        else
            # тест упал до/вне проверок — показываем хвост лога
            ERRORS+=("$(tail -5 "$log" | sed 's/^/      /')")
        fi
        ERRORS+=("")
    fi

    [ "$VERBOSE" -eq 1 ] && { sed 's/^/      /' "$log"; echo ""; }
    return 0
}

echo "=============================================="
echo "Тесты KubernetesProject (этапы 1-8)"
echo "Нода: ${NODE_HOSTNAME}   Пользователь кластера: ${REAL_USER}"
echo "=============================================="
echo ""

run_test root "Этап 1. Настройка ноды"      tests/test-01-node-base.sh "$NODE_HOSTNAME"
run_test root "Этап 2. Пакеты и окружение"  tests/test-02-packages.sh
run_test user "Этап 3. Кластер kubeadm"     tests/test-03-cluster-init.sh
run_test user "Этап 4. Pod-сеть (flannel)"  tests/test-04-cni.sh
run_test user "Этап 5. Приложение (nginx)"  tests/test-05-nginx.sh
run_test user "Этап 6. Gateway API"         tests/test-06-gateway.sh
run_test user "Этап 7. Мониторинг"          tests/test-07-monitoring.sh
run_test user "Этап 8. Логирование"         tests/test-08-logging.sh

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo ""
    echo "=============================================="
    echo "ОШИБКИ (подробно)"
    echo "=============================================="
    printf '%s\n' "${ERRORS[@]}"
fi

echo ""
echo "=============================================="
echo "ИТОГ"
echo "=============================================="
printf '  %s\n' "${SUMMARY[@]}"
echo "  ----------------------------------------------"
printf '  Этапов пройдено:  %s/%s\n' "$STAGES_OK" "$TOTAL"
printf '  Проверок пройдено: %s   ошибок: %s\n' "$CHECKS_OK" "$CHECKS_FAIL"
if [ "$STAGES_OK" -eq "$TOTAL" ]; then
    echo "  РЕЗУЛЬТАТ: ВСЁ ПРОЙДЕНО"
    exit 0
else
    echo "  РЕЗУЛЬТАТ: ЕСТЬ ОШИБКИ"
    exit 1
fi
