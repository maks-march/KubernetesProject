#!/usr/bin/env bash
# ============================================================================
# test-03-cluster-init.sh — тест этапа 3: кластер инициализирован
# Запуск БЕЗ sudo (проверяем kubeconfig обычного пользователя):
#   bash tests/test-03-cluster-init.sh
# Под sudo / из deploy.sh тоже корректно: берётся KUBECONFIG или
# конфиг пользователя из $SUDO_USER, а не несуществующий /root/.kube/config.
# ============================================================================
set -uo pipefail

source "$(dirname "$0")/lib.sh"
NODE_NAME="$(hostname)"

echo "Этап 3: кластер kubeadm (single-node, taint снят)"
echo "Нода: $NODE_NAME"
echo ""

check "kubeconfig на месте ($KUBECFG)"        "[ -f \"$KUBECFG\" ]"
check "apiserver отвечает (/readyz)"           "kubectl get --raw=/readyz | grep -q ok"
check "нода $NODE_NAME зарегистрирована"       "kubectl get node \"$NODE_NAME\" -o name"
# проверяем именно control-plane: у NotReady-ноды есть ещё служебный taint
# node.kubernetes.io/not-ready, он уйдёт сам после установки CNI
check "taint control-plane снят"               "kubectl get node \"$NODE_NAME\" -o jsonpath='{.spec.taints}' > /tmp/.taints.\$\$ 2>/dev/null && ! grep -q control-plane /tmp/.taints.\$\$; rc=\$?; rm -f /tmp/.taints.\$\$; exit \$rc"

echo ""
echo "Справочно — состояние нод (NotReady = норма, CNI будет на этапе 4):"
kubectl get nodes 2>/dev/null || true
echo ""

finish
