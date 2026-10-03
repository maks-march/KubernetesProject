#!/usr/bin/env bash
# ============================================================================
# 04-cluster-init.sh
# Этап 4: kubeadm init (single-node) и снятие taint.
# Запуск: sudo bash scripts/04-cluster-init.sh
# ============================================================================

set -euo pipefail

NODE_NAME="$(hostname)"
NODE_IP="$(hostname -I | awk '{print $1}')"
POD_CIDR="10.244.0.0/16"

# 1. Инициализация control-plane
# admin.conf создаётся при первом init, по нему понимаем что кластер уже есть.
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "Кластер уже инициализирован, пропускаю kubeadm init."
else
    echo "Инициализирую control-plane: $NODE_NAME ($NODE_IP), pod CIDR $POD_CIDR"
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
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl taint nodes --all node-role.kubernetes.io/control-plane- --ignore-not-found

echo "Готово. Проверка (без sudo): bash tests/test-04-cluster-init.sh"
