# Этап 6. Gateway API: доступ к приложению снаружи

## Зачем

ТЗ: доступ к приложению организуется через **Kubernetes Gateway API** —
современный стандарт входящего трафика (приемник Ingress). Три ресурса:

- **GatewayClass** — "кто обслуживает Gateway" (реализация контроллера)
- **Gateway** — точка входа: слушатель на порту, получает внешний IP
- **HTTPRoute** — правила маршрутизации HTTP-трафика к Service

## Выбранные компоненты (оба open-source)

| Компонент | Версия | Роль |
|---|---|---|
| Envoy Gateway | v1.5.0 | реализация Gateway API: контроллер + прокси Envoy |
| MetalLB | v0.16.1 | LoadBalancer для bare-metal: выдаёт IP Service типа LoadBalancer |

Почему MetalLB: на кластере kubeadm нет облачного LoadBalancer. Envoy Gateway
создаёт для Gateway Service типа LoadBalancer — без MetalLB он навсегда
останется без внешнего IP (`<pending>`).

Пул адресов скрипт вычисляет сам: берёт подсеть ноды и резервирует
`.200-.250` — решение работает в любой сети, где развёрнут кластер.

## Манифесты (`k8s/gateway.yaml`)

- `Gateway/app-gateway` — слушатель HTTP :80, gatewayClassName `eg`
  (создаётся установщиком Envoy Gateway автоматически)
- `HTTPRoute/nginx-route` — все запросы `/` → Service `nginx` :80

## Что делает скрипт `scripts/06-gateway.sh`

1. Ставит MetalLB из deps/metallb-native.yaml (этап 2), ждёт готовности подов
2. Создаёт IPAddressPool + L2Advertisement (адаптивно под сеть кластера)
3. Ставит Envoy Gateway из deps/envoy-gateway-install.yaml (этап 2), ждёт контроллер
4. Применяет `k8s/gateway.yaml` и манифесты приложения
5. Ждёт внешний IP у Gateway (до 3 минут), печатит команду проверки

Идемпотентен: все шаги — kubectl apply, повторный запуск безопасен.

## Порядок работы (TDD)

```bash
bash tests/test-06-gateway.sh    # FAIL
bash scripts/06-gateway.sh       # тянутся образы, несколько минут
bash tests/test-06-gateway.sh    # PASS
```

## Проверить руками (то, что будет проверять эксперт)

```bash
GW_IP=$(kubectl get gateway app-gateway -o jsonpath='{.status.addresses[0].value}')
curl http://$GW_IP/          # ожидание: HTML со строкой Hello World!
```

## Типовые проблемы

| Симптом | Причина |
|---|---|
| Service envoy... в pending | MetalLB не установлен / пул не создан / подсеть не та |
| Gateway без IP | `kubectl describe gateway app-gateway`; проверь поды metallb и envoy |
| HTTPRoute не Accepted | mismatch parentRef/namespace; смотри `kubectl describe httproute` |
| 503 от Envoy | Service nginx без endpoints — смотри этап 5 |
