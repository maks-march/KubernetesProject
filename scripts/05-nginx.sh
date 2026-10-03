#!/usr/bin/env bash
# ============================================================================
# 05-nginx.sh
# Этап 5: деплой nginx (Deployment + Service).
# Запуск: bash scripts/05-nginx.sh   (sudo не нужен)
# ============================================================================

set -euo pipefail

# скрипт можно запускать из любой папки — переходим в корень репозитория
cd "$(dirname "$0")/.."

# 1. Kubeconfig (если запустили через sudo)
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    export KUBECONFIG="$USER_HOME/.kube/config"
fi

# 2. Применяем манифесты
# kubectl apply идемпотентен: повторный запуск обновляет состояние
echo ""
echo "Применяю манифесты приложения ..."
# применяем только манифесты приложения, по файлам.
# ВАЖНО: не `kubectl apply -f k8s/` — туда попадает gateway.yaml, а CRD
# Gateway API ставятся только на этапе 6, из-за чего apply падал
# ("no matches for kind GatewayClass ... ensure CRDs are installed first")
# и обрывал deploy.sh.
kubectl apply -f k8s/nginx-deployment.yaml \
               -f k8s/nginx-index.yaml \
               -f k8s/nginx-service.yaml

# 3. Ждём готовности деплоя
echo ""
echo "Жду готовности подов nginx (тянутся образы)..."
kubectl rollout status deployment/nginx --timeout=300s

echo ""
echo "Готово. Проверка: bash tests/test-05-nginx.sh"
