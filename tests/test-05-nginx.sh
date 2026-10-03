#!/usr/bin/env bash
# ============================================================================
# test-05-nginx.sh
# Тест этапа 5: nginx задеплоен и отвечает.
# Запуск БЕЗ sudo: bash tests/test-05-nginx.sh
# ============================================================================

set -uo pipefail

source "$(dirname "$0")/lib.sh"

echo "Этап 5: nginx (Deployment + Service)"
echo ""

replicas_ready() { [ "$(kubectl get deployment nginx -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = 2 ]; }
endpoints_ready() { [ -n "$(kubectl get endpoints nginx -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)" ]; }

check "deployment nginx существует"     "retry 60 \"kubectl get deployment nginx -o name\""
# реплики поднимаются после скачивания образа, endpoints появляются следом
check "обе реплики готовы"              "retry 180 replicas_ready"
check "service nginx существует"        "retry 60 \"kubectl get service nginx -o name\""
check "у сервиса есть endpoints"        "retry 120 endpoints_ready"
# перед прогоном сносим под с прошлого раза (kubectl run не переиспользует имена)
check "HTTP-запрос через сервис работает" "kubectl delete pod curl-test --ignore-not-found=true; kubectl run curl-test --image=curlimages/curl --restart=Never --rm -i --pod-running-timeout=120s -- curl -sf http://nginx -o /dev/null"

echo ""
echo "Справочно — поды и сервис:"
kubectl get pods -l app=nginx 2>/dev/null || true
kubectl get service nginx 2>/dev/null || true
echo ""

finish
