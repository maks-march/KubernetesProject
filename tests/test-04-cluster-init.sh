#!/usr/bin/env bash
# ============================================================================
# test-04-cluster-init.sh — тест этапа 4: кластер инициализирован
# Запуск БЕЗ sudo (проверяем kubeconfig обычного пользователя):
#   bash tests/test-04-cluster-init.sh
# ============================================================================
set -uo pipefail

source "$(dirname "$0")/lib.sh"
NODE_NAME="$(hostname)"

echo "Этап 4: кластер kubeadm (single-node, taint снят)"
echo "Нода: $NODE_NAME"
echo ""

check "kubeconfig на месте (~/.kube/config)"   "[ -f \"$HOME/.kube/config\" ]"
check "apiserver отвечает (/readyz)"           "kubectl get --raw=/readyz | grep -q ok"
check "нода $NODE_NAME зарегистрирована"       "kubectl get node \"$NODE_NAME\" -o name"
check "taint control-plane снят"               "[ -z \"\$(kubectl get node \"$NODE_NAME\" -o jsonpath='{.spec.taints}' | tr -d '[] \"[:space:]\"')\" ]"

echo ""
echo "Справочно — состояние нод (NotReady = норма, CNI будет на этапе 5):"
kubectl get nodes 2>/dev/null || true
echo ""

finish
