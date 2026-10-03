# Этап 3. Ядро для Kubernetes: модули + sysctl

## Зачем

- **`overlay`** — файловая система overlayFS: из неё containerd собирает слои
  образов контейнеров. Без неё контейнеры не запустятся.
- **`br_netfilter`** — даёт iptables/nftables видеть трафик, проходящий через
  сетевые мосты (bridge). Pod-сеть Kubernetes построена на мостах: CNI-плагин
  пишет правила файрвола, и без модуля эти правила не срабатывают.
- **`net.ipv4.ip_forward = 1`** — разрешает ядру пересылать пакеты между
  интерфейсами. Поды сидят в своей сети (veth/мост) — без форвардинга их пакеты
  не покидают ноду.

Пара «сейчас + навсегда»:
- `modprobe` грузит модуль немедленно (до перезагрузки);
- `/etc/modules-load.d/k8s.conf` — systemd грузит эти модули при каждом старте системы.

Аналогично для sysctl: файл `/etc/sysctl.d/k8s.conf` + `sysctl --system`.

## Что делает скрипт `scripts/03-kernel-extras.sh`

1. `modprobe overlay br_netfilter` + запись их в `/etc/modules-load.d/k8s.conf`
2. Пишет `/etc/sysctl.d/k8s.conf` с тремя параметрами
3. `sysctl --system` — применяет

## Порядок работы (TDD)

```bash
sudo bash tests/test-03-kernel-extras.sh     # 1. тест ДО — часть проверок FAIL
sudo bash scripts/03-kernel-extras.sh        # 2. применяем
sudo bash tests/test-03-kernel-extras.sh     # 3. тест ПОСЛЕ — PASS
```

## Проверить руками

```bash
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
```

## Замечания

- В некоторых средах (WSL2, свежие ядра) `br_netfilter` уже загружен — скрипт
  это не ломает: `modprobe` для загруженного модуля — no-op.
- Если `modprobe overlay` падает с «not found» — ядро собрано без модуля,
  нужно обновить среду (в WSL: `wsl --update`).
