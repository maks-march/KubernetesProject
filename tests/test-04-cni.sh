#!/usr/bin/env bash
# ============================================================================
# test-04-cni.sh
# Тест этапа 4: CNI flannel установлен, нода Ready.
# Запуск БЕЗ sudo: bash tests/test-04-cni.sh
# ============================================================================

set -uo pipefail

source "$(dirname "$0")/lib.sh"
NODE_NAME="$(hostname | tr 'A-Z' 'a-z')"

echo "Этап 4: CNI (pod-сеть)"
echo "Нода: $NODE_NAME"
echo ""

# ожидания: нода становится Ready раньше, чем поднимается vxlan-интерфейс
# flannel.1 и доезжают поды CoreDNS
check "поды flannel запущены"      "retry 180 \"kubectl get pods -A --no-headers | grep flannel | grep -q Running\""
check "интерфейс flannel.1 есть"   "retry 120 \"ip link show flannel.1\""
node_ready() { [ "$(kubectl get node "$NODE_NAME" --no-headers 2>/dev/null | awk '{print $2}')" = Ready ]; }
check "нода Ready"                 "retry 180 node_ready"
check "CoreDNS запущен"            "retry 180 \"kubectl get pods -n kube-system --no-headers | grep coredns | grep -q Running\""

echo ""
echo "Справочно — состояние нод и системных подов:"
kubectl get nodes 2>/dev/null || true
kubectl get pods -A 2>/dev/null | grep -E "flannel|coredns" || true
echo ""

finish
