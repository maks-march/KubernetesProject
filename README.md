sudo apt update && sudo apt upgrade -y
sudo apt install -y git
git clone https://github.com/maks-march/KubernetesProject.git
cd KubernetesProject

# этап 1
sudo bash tests/test-01-node-base.sh k8s-node    # ожидаем FAIL
sudo bash scripts/01-node-base.sh k8s-node
sudo bash tests/test-01-node-base.sh k8s-node    # ожидаем PASS

