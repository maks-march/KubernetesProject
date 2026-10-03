# Этап 5. Деплой nginx: Deployment + Service

Первые Kubernetes-ресурсы проекта. Манифесты лежат в `k8s/`.

## Deployment (`k8s/nginx-deployment.yaml`)

Deployment — контроллер, который держит заданное число реплик пода:
умер под → создаёт новый, обновил образ → перекатывает поды по одному.

Ключевые поля:
- `replicas: 2` — желаемое число копий
- `selector.matchLabels` — какие поды считает своими (по меткам)
- `template` — шаблон пода: метки, образ, порты, ресурсы
- `resources.requests/limits` — запросы и потолок CPU/RAM; планировщик
  по requests решает, куда посадить под

Связь: `template.metadata.labels` обязана совпадать с `selector.matchLabels`,
иначе Deployment не найдёт свои поды.

## Service (`k8s/nginx-service.yaml`)

Service — стабильная точка входа: имя `nginx` и постоянный IP внутри кластера.
Он сам следит за подами (через `selector`) и балансирует трафик между ними.
`ClusterIP` = доступ только изнутри кластера; наружу откроем на этапе 6 (ingress).

Endpoints — внутренний объект: список IP подов, куда Service реально шлёт
трафик. Если endpoints пустой — селектор не нашёл поды.

## Что делает скрипт `scripts/05-nginx.sh`

1. `kubectl apply -f k8s/` — применяет все манифесты папки (идемпотентно)
2. `kubectl rollout status deployment/nginx` — ждёт готовности реплик

## Порядок работы (TDD)

```bash
bash tests/test-05-nginx.sh    # FAIL
bash scripts/05-nginx.sh
bash tests/test-05-nginx.sh    # PASS
```

## Проверить руками

```bash
kubectl get pods -l app=nginx -o wide    # 2 пода, Running
kubectl get endpoints nginx              # IP подов
kubectl port-forward service/nginx 8080:80
curl -I http://localhost:8080            # 200 OK
```

## Типовые проблемы

| Симптом | Причина |
|---|---|
| Pending | не хватает ресурсов — смотри `kubectl describe pod` |
| ImagePullBackOff | нет доступа к docker.io |
| endpoints пустой | метки подов не совпадают с selector сервиса |
| поды есть, curl падает | `kubectl logs <pod>` |
