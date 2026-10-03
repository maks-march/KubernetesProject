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

# Какой kubeconfig реально используется:
#   1) переменная KUBECONFIG (её выставляет deploy.sh / test-deploy.sh),
#   2) под sudo — конфиг пользователя, вызвавшего sudo (а не /root),
#   3) иначе ~/.kube/config текущего пользователя.
if [ -n "${KUBECONFIG:-}" ]; then
    KUBECFG="$KUBECONFIG"
elif [ -n "${SUDO_USER:-}" ]; then
    KUBECFG="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.kube/config"
    export KUBECONFIG="$KUBECFG"
else
    KUBECFG="$HOME/.kube/config"
fi

# запасной вариант: конфига пользователя нет, но кластер есть и мы root —
# работаем по admin.conf, иначе kubectl ушёл бы на localhost:8080
if [ ! -f "$KUBECFG" ] && [ -r /etc/kubernetes/admin.conf ]; then
    echo "ПРИМЕЧАНИЕ: $KUBECFG не найден, использую /etc/kubernetes/admin.conf"
    export KUBECONFIG=/etc/kubernetes/admin.conf
fi

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
