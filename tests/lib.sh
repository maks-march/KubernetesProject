#!/usr/bin/env bash
# ============================================================================
# lib.sh — мини-фреймворк для тестов этапов (без зависимостей, чистый bash)
# Использование: source lib.sh; check "описание" "команда"; finish
# ============================================================================
PASS=0
FAIL=0

check() {
    # check "описание проверки" "bash-команда, успех = exit 0"
    local desc="$1"
    local cmd="$2"
    if eval "$cmd" > /dev/null 2>&1; then
        PASS=$((PASS + 1))
        echo "  [PASS] $desc"
    else
        FAIL=$((FAIL + 1))
        echo "  [FAIL] $desc"
    fi
}

finish() {
    echo "----------------------------------------"
    echo "Пройдено: $PASS   Ошибок: $FAIL"
    if [ "$FAIL" -eq 0 ]; then
        echo "ЭТАП ПРОЙДЕН ✅"
    else
        echo "ЕСТЬ ОШИБКИ ❌"
        exit 1
    fi
}
