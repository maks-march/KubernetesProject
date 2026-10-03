# Этап 2. Пакеты и окружение: containerd + Kubernetes

## Зачем

- **containerd** — container runtime. kubelet не запускает контейнеры сам,
  он приказывает containerd. Это единственный runtime, который ставим.
- **kubelet** — агент на ноде: следит за подами, их состоянием.
- **kubeadm** — инструмент бутстрапа кластера (init/join).
- **kubectl** — CLI для общения с apiserver.

## Что делает скрипт `scripts/02-packages.sh`

1. Ставит базовые пакеты и `containerd` из репо Ubuntu
2. Генерирует дефолтный конфиг containerd и включает **`SystemdCgroup = true`** —
   единственная настройка, без которой ничего не работает: kubelet использует
   systemd-драйвер cgroup, и он обязан совпадать с containerd
3. Добавляет репозиторий `pkgs.kubernetes.io` (GPG-ключ в `/etc/apt/keyrings/`)
4. Ставит `kubelet kubeadm kubectl` и ставит их на **hold** — случайный
   `apt upgrade` не может обновить k8s-компоненты вразнобой

## Порядок работы (TDD)

```bash
sudo bash tests/test-02-packages.sh     # FAIL
sudo bash scripts/02-packages.sh        # ставим (2–4 минуты)
sudo bash tests/test-02-packages.sh     # PASS
```

## Проверить руками

```bash
containerd config dump | grep SystemdCgroup
systemctl status containerd
kubeadm version
```

## Замечания

- Версия репо фиксируется по minor (`v1.37`) — патчи приходят, минорные скачки нет.
- После этого этапа kubelet ещё **не запущен/не работает** — это нормально:
  он стартует после `kubeadm init` (этап 4).
- Если `kubeadm init` потом пожалуется на ядро (bridge-nf-call-iptables,
  ip_forward) — применяем этап 3 (`03-kernel-extras.sh`), он для этого и лежит.
