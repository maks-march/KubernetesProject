# Этап 1. База ноды: hostname + /etc/hosts + swap off

## Зачем

- **hostname** — Kubernetes использует имя ноды как её identity в кластере
  (`kubectl get nodes`). Задаётся до `kubeadm init` и не меняется.
- **/etc/hosts** — компоненты кластера (kubelet, etcd, CNI) резолвят ноду по имени.
- **swap off** — kubelet отказывается работать со включённым swap: память подов,
  ушедшая в свап, ломает представления планировщика о ресурсах. `kubeadm init`
  проверяет это в preflight и не стартует.

## Что делает скрипт `scripts/01-node-base.sh <hostname>`

1. Проверяет, что PID 1 = systemd (без него kubeadm-окружение не поддерживается).
2. `hostnamectl set-hostname` — имя ноды (на обычном Linux переживает ребут).
3. Добавляет `127.0.1.1 <hostname>` в `/etc/hosts` (без дублей).
4. `swapoff -a` — выключает свап прямо сейчас;
   `sed -i.bak '/swap/s/^/#/' /etc/fstab` — комментирует swap-строки в fstab,
   чтобы свап не вернулся после перезагрузки (бэкап fstab → `fstab.bak`).

## Порядок работы (TDD)

```bash
sudo bash tests/test-01-node-base.sh k8s-node    # 1. тест ДО — ожидаем FAIL
sudo bash scripts/01-node-base.sh k8s-node       # 2. применяем
sudo bash tests/test-01-node-base.sh k8s-node    # 3. тест ПОСЛЕ — ожидаем PASS
```

## Требования к окружению

- Linux с systemd (Ubuntu 22.04/24.04 LTS рекомендуется)
- Права root (запуск через sudo)

## Замечания

- Скрипт идемпотентен: повторный запуск ничего не ломает.
- Проверить swap вручную: `free -h` → строка Swap: 0B.
