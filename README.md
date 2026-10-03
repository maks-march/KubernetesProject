# KubernetesProject

Single-node кластер Kubernetes (kubeadm) с веб-приложением nginx, доступным через **Kubernetes Gateway API**. Каждый этап развёртывания автоматизирован скриптом и покрыт тестом.

## Архитектура

```
Пользователь
   │  HTTP :80
   ▼
Gateway API (Envoy Gateway)  ◄── IP выдаёт MetalLB
   │  HTTPRoute /
   ▼
Service nginx ──► Deployment nginx (2 реплики, Hello World!)

Мониторинг: Prometheus ◄── node-exporter (метрики ноды)
```

## Технологии и версии

| Компонент | Версия |
|---|---|
| ОС (тестировалось) | Ubuntu 24.04 LTS (в т.ч. WSL2) |
| Kubernetes | v1.37 (kubeadm, репозиторий pkgs.kubernetes.io) |
| Container runtime | containerd (репозиторий Ubuntu, SystemdCgroup) |
| CNI | flannel (pod CIDR 10.244.0.0/16) |
| Реализация Gateway API | **Envoy Gateway v1.5.0** |
| LoadBalancer | MetalLB v0.16.1 (L2) |
| Приложение | nginx:1.27-alpine |
| Мониторинг | Prometheus v3.1.0, node-exporter v1.8.2 |

Ресурсы Gateway API: `GatewayClass` (eg, создаётся установщиком), `Gateway` (app-gateway, HTTP :80), `HTTPRoute` (nginx-route, `/` → Service nginx).

## Требования к среде

- Linux с systemd, рекомендуется Ubuntu 24.04 LTS (проверено: обычная система и WSL2)
- 2+ CPU, 4+ GB RAM, 20+ GB диска, доступ в интернет
- Права sudo, git

## Развёртывание

Склонировать репозиторий и выполнять этапы по порядку. Каждый этап:
тест (ожидаем FAIL) → скрипт → тест (ожидаем PASS).

**Подготовка ноды и кластера (sudo):**

```bash
sudo bash scripts/01-node-base.sh k8s-node      # hostname, swap, ядро
sudo bash tests/test-01-node-base.sh k8s-node

sudo bash scripts/02-packages.sh                # containerd, kubeadm/kubelet/kubectl,
                                                # + скачивание манифестов зависимостей в deps/
sudo bash tests/test-02-packages.sh

sudo bash scripts/03-cluster-init.sh            # kubeadm init + снятие taint
bash tests/test-03-cluster-init.sh              # без sudo
```

**Инфраструктура в кластере (без sudo):**

```bash
bash scripts/04-cni.sh                          # flannel, нода становится Ready
bash tests/test-04-cni.sh

bash scripts/05-nginx.sh                        # Deployment + Service nginx
bash tests/test-05-nginx.sh

bash scripts/06-gateway.sh                      # MetalLB + Envoy Gateway + Gateway/HTTPRoute
bash tests/test-06-gateway.sh

bash scripts/07-monitoring.sh                   # Prometheus + node-exporter
bash tests/test-07-monitoring.sh
```

Все скрипты идемпотентны: повторный запуск не приводит систему
в некорректное состояние.

## Проверка приложения (через Gateway API)

```bash
GW_IP=$(kubectl get gateway app-gateway -o jsonpath='{.status.addresses[0].value}')
curl http://$GW_IP/        # ожидание: страница со строкой "Hello World!"
```

## Проверка мониторинга

Собираемые метрики (Prometheus v3.1.0):

- **node-exporter** — метрики ноды: `node_cpu_seconds_total` (CPU),
  `node_memory_MemAvailable_bytes` (память), `node_filesystem_avail_bytes` (диск)
- **prometheus** — сам Prometheus

Проверка:

```bash
kubectl -n monitoring port-forward svc/prometheus 9090:9090
```

- `http://localhost:9090/targets` — оба target в состоянии UP
- PromQL-запрос `up{job="node-exporter"}` возвращает `1`
- PromQL-запрос `node_cpu_seconds_total` возвращает серии метрик

## Проверка логирования

Этап 8 (Fluentd) — в разработке, будет описано здесь.

## Структура репозитория

```
k8s/       — манифесты Kubernetes (приложение, Gateway API)
scripts/   — скрипты этапов (идемпотентные)
tests/     — тесты этапов (bash, без зависимостей)
docs/      — документация по каждому этапу
deps/      — скачанные манифесты зависимостей (создаёт этап 02, в git не хранится)
```

## Известные ограничения

- Кластер single-node: отказоустойчивости нет (учебная архитектура)
- Пул MetalLB `.200–.250` в /24 подсети ноды: при занятом DHCP-диапазоне адреса изменить в `scripts/06-gateway.sh`
- Если IP ноды меняется между перезагрузками (WSL/DHCP), сертификаты kubeadm сломаются — кластер рассчитан на машину со стабильным IP
- `--pod-network-cidr` (этап 3) обязан совпадать с CIDR flannel
