# Этап 8. Логирование: Fluentd

## Зачем

ТЗ: собрать access/error-логи приложения с помощью Fluentd или Filebeat,
передать в хранилище и уметь показать, что после обращения к приложению
запись появляется в собранных логах.

## Как это устроено

1. nginx пишет access-лог в stdout, error-лог в stderr контейнера
2. containerd сохраняет их на ноде в `/var/log/containers/*.log`
   (симлинки на `/var/log/pods/...`)
3. **Fluentd DaemonSet** (namespace `logging`, образ fluent/fluentd:v1.19.2-2.3):
   - плагин `tail` следит за `*nginx*.log`, позиция чтения — в pos-файле
     (после рестарта пода логи не дублируются)
   - плагин `file` пишет собранное в `/var/log/fluentd/nginx-access.*` на ноде
     (hostPath, flush каждые 5 секунд)
4. Проверка сквозная: `curl http://<Gateway>/?trace=<метка>` → через ~10 секунд
   метка находится в собранных логах

## Что делает скрипт `scripts/08-logging.sh`

1. Применяет `k8s/logging/`
2. Ждёт готовности DaemonSet
3. Делает сквозную проверку сам (уникальный trace-запрос → grep по логам)

Идемпотентен.

## Порядок работы (TDD)

```bash
bash tests/test-08-logging.sh    # FAIL
bash scripts/08-logging.sh
bash tests/test-08-logging.sh    # PASS
```

## Проверить руками (то, что будет проверять эксперт)

```bash
GW_IP=$(kubectl get gateway app-gateway -o jsonpath='{.status.addresses[0].value}')

# 1. уникальный запрос в приложение
curl "http://${GW_IP}/?trace=expert-check-123"

# 2. подождать ~10 секунд и искать метку в собранных логах
kubectl -n logging exec daemonset/fluentd -- \
  sh -c 'grep -h expert-check-123 /var/log/fluentd/nginx-access*'
```

Либо посмотреть весь собранный лог:
`kubectl -n logging exec daemonset/fluentd -- sh -c 'tail -5 /var/log/fluentd/nginx-access*'`

## Типовые проблемы

| Симптом | Причина |
|---|---|
| Fluentd не пишет файлы | `kubectl -n logging logs ds/fluentd` — обычно права на /var/log/fluentd |
| Метка не находится | не прошло 10 сек (flush_interval 5s) или Gateway недоступен |
| Логи дублируются после рестарта | сломан pos-файл — проверь, что /var/log/fluentd на hostPath |
