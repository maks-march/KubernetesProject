# Этап 7. Мониторинг: Prometheus + node-exporter

## Зачем

ТЗ: Prometheus должен собирать метрики минимум одного компонента решения.
Мы собираем два target'а:

- **node-exporter** — метрики ноды кластера (CPU, память, диск, сеть):
  `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`,
  `node_filesystem_avail_bytes` и все остальные `node_*`
- **prometheus** — сам Prometheus (счётчики запросов, потребление памяти)

## Как устроено (`k8s/monitoring/`)

- **prometheus.yaml** — Namespace `monitoring`, ConfigMap с `prometheus.yml`
  (список целей), Deployment Prometheus v3.1.0, Service :9090
- **node-exporter.yaml** — DaemonSet node-exporter v1.8.2
  (читает /proc, /sys ноды через hostPath) + Service :9100

Сбор настраивается в ConfigMap `prometheus-config`, раздел `scrape_configs`.
Данные Prometheus хранит в emptyDir — переживает рестарт контейнера, но не под
(учебная архитектура, см. ограничения в README).

## Что делает скрипт `scripts/07-monitoring.sh`

1. Применяет `k8s/monitoring/`
2. Ждёт готовности Deployment prometheus и DaemonSet node-exporter
3. Ждёт первый цикл сбора (scrape_interval = 15s)

Идемпотентен.

## Порядок работы (TDD)

```bash
bash tests/test-07-monitoring.sh    # FAIL
bash scripts/07-monitoring.sh
bash tests/test-07-monitoring.sh    # PASS
```

## Проверить руками (то, что будет проверять эксперт)

```bash
kubectl -n monitoring port-forward svc/prometheus 9090:9090
```

- Браузер: `http://localhost:9090/targets` — оба target в состоянии **UP**
- Запрос PromQL в браузере: `up{job="node-exporter"}` → `1`
- Реальная метрика: `node_cpu_seconds_total` — серии по ядрам CPU
- Или через curl:
  `curl 'http://localhost:9090/api/v1/query?query=up{job="node-exporter"}'`

## Типовые проблемы

| Симптом | Причина |
|---|---|
| target DOWN в /targets | под node-exporter не Running — смотри `kubectl -n monitoring get pods` |
| запрос up пустой | не прошло 15s после старта — подожди scrape_interval |
| Prometheus CrashLoop | `kubectl logs -n monitoring deploy/prometheus` (обычно ошибка в конфиге) |
