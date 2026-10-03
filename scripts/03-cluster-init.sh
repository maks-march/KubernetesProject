#!/usr/bin/env bash
# ============================================================================
# 03-cluster-init.sh
# Этап 3: kubeadm init (single-node) и снятие taint.
# Если kubeadm падает на preflight (swap, bridge-nf-call-iptables),
# значит этап 1 (01-node-base.sh) выполнен не полностью.
# Запуск: sudo bash scripts/03-cluster-init.sh
# ============================================================================

set -euo pipefail

# имя ноды — только нижний регистр (требование RFC 1123 для Kubernetes);
# hostname вида DESKTOP-XXXX kubelet зарегистрирует как desktop-xxxx
NODE_NAME="$(hostname | tr 'A-Z' 'a-z')"
NODE_IP="$(hostname -I | awk '{print $1}')"
POD_CIDR="10.244.0.0/16"

# 1. Инициализация control-plane
# admin.conf создаётся при первом init, по нему понимаем что кластер уже есть.
if [ -f /etc/kubernetes/admin.conf ]; then
    echo ""
    echo "Кластер уже инициализирован, пропускаю kubeadm init."
else
    echo ""
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

# 3. Kubeconfig для kubectl внутри скрипта и ожидание apiserver
# скрипт запущен через sudo, kubectl смотрит в /root/.kube/config,
# которого нет — явно указываем admin.conf.
# После init apiserver поднимается не сразу: без ожидания kubectl падает
# по connection refused и taint не снимается.
export KUBECONFIG=/etc/kubernetes/admin.conf
echo ""
echo "Жду готовности apiserver (может занять до минуты)..."
until kubectl get --raw=/readyz > /dev/null 2>&1; do
    sleep 2
done
echo ""
echo "apiserver готов"

# 4. Taint
# kubeadm запрещает обычным подам работать на control-plane (taint NoSchedule).
# Нода одна, поэтому taint снимаем, иначе поды навсегда останутся в Pending.
# нода регистрируется kubelet-ом через несколько секунд после init
for i in $(seq 1 60); do
    kubectl get node "$NODE_NAME" > /dev/null 2>&1 && break
    sleep 2
done
if ! kubectl get node "$NODE_NAME" > /dev/null 2>&1; then
    echo ""
    echo "ОШИБКА: нода $NODE_NAME не найдена в кластере"
    exit 1
fi
if kubectl get node "$NODE_NAME" -o jsonpath='{.spec.taints}' | grep -q "control-plane"; then
    kubectl taint nodes "$NODE_NAME" node-role.kubernetes.io/control-plane-
fi

echo ""
echo "Готово. Проверка (без sudo): bash tests/test-03-cluster-init.sh"
