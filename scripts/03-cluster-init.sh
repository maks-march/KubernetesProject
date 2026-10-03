#!/usr/bin/env bash
# ============================================================================
# 03-cluster-init.sh
# Этап 3: kubeadm init (single-node) и снятие taint.
# Если kubeadm падает на preflight (swap, bridge-nf-call-iptables),
# значит этап 1 (01-node-base.sh) выполнен не полностью.
# Запуск: sudo bash scripts/03-cluster-init.sh
# ============================================================================

set -euo pipefail

NODE_NAME="$(hostname)"
NODE_IP="$(hostname -I | awk '{print $1}')"
POD_CIDR="10.244.0.0/16"

# 1. Инициализация control-plane
# admin.conf создаётся при первом init, по нему понимаем что кластер уже есть.
if [ -f /etc/kubernetes/admin.conf ]; then
    echo -e "\n Кластер уже инициализирован, пропускаю kubeadm init."
else
    echo -e "\n Инициализирую control-plane: $NODE_NAME ($NODE_IP), pod CIDR $POD_CIDR"
    kubeadm init \
        --apiserver-advertise-address="$NODE_IP" \
        --pod-network-cidr="$POD_CIDR" \
        --node-name="$NODE_NAME"
fi

# 2. Kubeconfig
# admin.conf копируем пользователю, чтобы kubectl работал без sudo.
REAL_USER="${SUDO_USER:-$(id -un)}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
mkdir -p "$USER_HOME/.kube"
cp -f /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.kube/config"
chmod 600 "$USER_HOME/.kube/config"

# 3. Taint
# kubeadm запрещает обычным подам работать на control-plane (taint NoSchedule).
# Нода одна, поэтому taint снимаем, иначе поды навсегда останутся в Pending.
# Сначала проверяем, что taint вообще есть: повторный запуск не должен падать.
export KUBECONFIG=/etc/kubernetes/admin.conf
if kubectl get node "$NODE_NAME" -o jsonpath='{.spec.taints}' | grep -q "control-plane"; then
    kubectl taint nodes "$NODE_NAME" node-role.kubernetes.io/control-plane-
fi

echo -e "\n Готово. Проверка (без sudo): bash tests/test-03-cluster-init.sh"
