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

check "deployment nginx существует"     "kubectl get deployment nginx -o name"
check "обе реплики готовы"              "[ \"\$(kubectl get deployment nginx -o jsonpath='{.status.readyReplicas}')\" = 2 ]"
check "service nginx существует"        "kubectl get service nginx -o name"
check "у сервиса есть endpoints"        "[ -n \"\$(kubectl get endpoints nginx -o jsonpath='{.subsets[0].addresses[0].ip}')\" ]"
# перед прогоном сносим под с прошлого раза (kubectl run не переиспользует имена)
check "HTTP-запрос через сервис работает" "kubectl delete pod curl-test --ignore-not-found=true; kubectl run curl-test --image=curlimages/curl --restart=Never --rm -i --pod-running-timeout=120s -- curl -sf http://nginx -o /dev/null"

echo ""
echo "Справочно — поды и сервис:"
kubectl get pods -l app=nginx 2>/dev/null || true
kubectl get service nginx 2>/dev/null || true
echo ""

finish
