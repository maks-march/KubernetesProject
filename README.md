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
Логи: Fluentd ◄── /var/log/containers (access/error nginx) ──► /var/log/fluentd
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
| Логирование | Fluentd v1.19.2 |

Ресурсы Gateway API: `GatewayClass` (eg, объявлен в k8s/gateway.yaml — установщик
Envoy Gateway v1.5.0 сам его не создаёт), `Gateway` (app-gateway, HTTP :80),
`HTTPRoute` (nginx-route, `/` → Service nginx).

## Требования к среде

- Linux с systemd, рекомендуется Ubuntu 24.04 LTS (проверено: обычная система и WSL2)
- 2+ CPU, 4+ GB RAM, 20+ GB диска, доступ в интернет
- Права sudo, git

## Развёртывание

Склонировать репозиторий и выполнить одну команду:

```bash
sudo bash deploy.sh    # полное развёртывание: этапы 1-8
```

Как это работает: каждый этап сначала проверяется тестом. Тест пройден —
этап пропускается, не пройден — применяется скрипт этапа и тест повторяется.
Повторный запуск `deploy.sh` на развёрнутой системе ничего не меняет
(идемпотентность).

Имя ноды можно задать аргументом: `sudo bash deploy.sh k8s-node`
(по умолчанию используется текущий hostname).

Проверить всё после деплоя:

```bash
bash test-deploy.sh    # тесты этапов 3-8 со сводкой
```

Ручной запуск отдельных этапов — см. docs/.

Этапы развёртывания (каждому соответствует тест `tests/test-NN-*.sh`):

| Этап | Скрипт | Что делает |
|---|---|---|
| 1 | scripts/01-node-base.sh | hostname, swap off, модули ядра, sysctl |
| 2 | scripts/02-packages.sh | containerd, kubeadm/kubelet/kubectl v1.37, манифесты зависимостей → deps/ |
| 3 | scripts/03-cluster-init.sh | kubeadm init, kubeconfig, снятие taint (single-node) |
| 4 | scripts/04-cni.sh | flannel (pod CIDR 10.244.0.0/16) |
| 5 | scripts/05-nginx.sh | Deployment nginx (2 реплики) + Service + ConfigMap |
| 6 | scripts/06-gateway.sh | MetalLB + Envoy Gateway + Gateway/HTTPRoute |
| 7 | scripts/07-monitoring.sh | Prometheus + node-exporter |
| 8 | scripts/08-logging.sh | Fluentd (DaemonSet, сбор логов nginx) |

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

Fluentd v1.19.2 (DaemonSet, namespace `logging`) собирает access/error-логи
nginx из `/var/log/containers` и пишет в `/var/log/fluentd` на ноде
(flush каждые 5 секунд).

```bash
GW_IP=$(kubectl get gateway app-gateway -o jsonpath='{.status.addresses[0].value}')

curl "http://${GW_IP}/?trace=expert-check-123"          # уникальный запрос

sleep 10
kubectl -n logging exec daemonset/fluentd -- \
  sh -c 'grep -h expert-check-123 /var/log/fluentd/nginx-access*'   # запись найдена
```

## Структура репозитория

```
deploy.sh       — деплой всех этапов одной командой (тест → скрипт → тест)
test-deploy.sh  — прогон всех тестов со сводкой
k8s/            — манифесты: приложение, Gateway API, мониторинг, логирование
scripts/        — скрипты этапов (идемпотентные)
tests/          — тесты этапов (bash, без зависимостей)
docs/           — документация по каждому этапу
deps/           — скачанные манифесты зависимостей (создаёт этап 02, в git не хранится)
```

## Известные ограничения

- Кластер single-node: отказоустойчивости нет (учебная архитектура)
- Установка требует интернет: сторонние манифесты качаются этапом 2, образы — при первом apply (офлайн не поддерживается)
- Пул MetalLB `.200–.250` в /24 подсети ноды: при занятом DHCP-диапазоне адреса изменить в `k8s/metallb-pool.yaml.template`
- В WSL2 внешний IP Gateway (MetalLB L2) может не отвечать с Windows-хоста — проверять `curl` с самой Linux-ноды; на обычной Linux-машине IP доступен с любого хоста той же L2-сети
- Если IP ноды меняется между перезагрузками (WSL/DHCP), сертификаты kubeadm сломаются — кластер рассчитан на машину со стабильным IP
- `--pod-network-cidr` (этап 3) обязан совпадать с CIDR flannel
