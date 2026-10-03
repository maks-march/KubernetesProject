#!/usr/bin/env bash
# ============================================================================
# lib.sh
# Функции для тестов этапов.
# Использование: source lib.sh, затем check "описание" "команда" и finish
# ============================================================================

PASS=0
FAIL=0

# --- kubeconfig ---------------------------------------------------------
# Тесты запускают и от пользователя, и через sudo, и из deploy.sh.
# Под sudo у root нет своего ~/.kube/config, и kubectl уходил бы
# на localhost:8080 ("connection refused"). Определяем конфиг явно:
#   KUBECONFIG -> конфиг $SUDO_USER -> ~/.kube/config -> /etc/kubernetes/admin.conf
if [ -z "${KUBECONFIG:-}" ]; then
    if [ -n "${SUDO_USER:-}" ] && \
       [ -f "$(getent passwd "$SUDO_USER" | cut -d: -f6)/.kube/config" ]; then
        export KUBECONFIG="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.kube/config"
    elif [ -f "$HOME/.kube/config" ]; then
        export KUBECONFIG="$HOME/.kube/config"
    elif [ -r /etc/kubernetes/admin.conf ]; then
        export KUBECONFIG=/etc/kubernetes/admin.conf
    fi
fi
KUBECFG="${KUBECONFIG:-$HOME/.kube/config}"

check() {
    # проверка успешна, если команда вернула код 0
    # при провале печатаем вывод команды (первые 3 строки) — видно причину
    local desc="$1"
    local cmd="$2"
    local out
    if out=$(eval "$cmd" 2>&1); then
        PASS=$((PASS + 1))
        echo "  [PASS] $desc"
    else
        FAIL=$((FAIL + 1))
        echo "  [FAIL] $desc"
        if [ -n "$out" ]; then
            echo "$out" | head -3 | sed 's/^/        /'
        fi
    fi
}

retry() {
    # retry <секунды> <команда> — ждём, пока команда начнёт проходить.
    # Нужен там, где состояние появляется с задержкой: прокси Envoy
    # поднимается после выдачи IP, Prometheus скрейпит раз в 15 с,
    # Fluentd сбрасывает буфер раз в 5 с.
    local timeout="$1"; shift
    # FAST_CHECK=1 — без ожиданий (deploy.sh так делает предварительную
    # тихую проверку "этап уже настроен?", иначе каждый ещё не выполненный
    # этап стоил бы минут ожидания)
    [ "${FAST_CHECK:-0}" = 1 ] && timeout=0
    local deadline=$(( SECONDS + timeout ))
    until eval "$@"; do
        [ "$SECONDS" -ge "$deadline" ] && return 1
        sleep 3
    done
    return 0
}

finish() {
    echo "========================================"
    echo "Пройдено: $PASS   Ошибок: $FAIL"
    if [ "$FAIL" -eq 0 ]; then
        echo "ЭТАП ПРОЙДЕН"
        exit 0
    else
        echo "ЕСТЬ ОШИБКИ"
        exit 1
    fi
}
