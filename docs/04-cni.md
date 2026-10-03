# Этап 4. CNI: pod-сеть (flannel)

## Зачем

`kubeadm init` не ставит сеть для подов. Без CNI у ноды нет pod-сети:

- нода висит в **NotReady** — планировщик не может размещать поды
- **CoreDNS** и все остальные поды висят в **Pending**
- поды не имеют IP и не могут общаться

CNI-плагин создаёт на ноде виртуальную сеть: каждому поду выдаётся IP из
pod-диапазона, трафик между подами заворачивается в overlay (VXLAN).

## Почему flannel и про CIDR

Flannel — самый простой CNI: один DaemonSet, минимум настроек. Для учебного
single-node кластера достаточно.

Главное правило: **CIDR в манифесте flannel обязан совпадать** с
`--pod-network-cidr` из `kubeadm init`. У нас это `10.244.0.0/16` — дефолт
манифеста flannel, поэтому ничего менять не надо. Если совпадёт плохо —
сеть будет работать криво или не будет вовсе.

## Что делает скрипт `scripts/04-cni.sh`

1. `kubectl apply` официального манифеста flannel
2. Ждёт Ready подов flannel (образы тянутся с docker.io, первый раз пару минут)
3. Ждёт Ready ноды

Идемпотентен: `kubectl apply` повторно не ломает, ожидания просто проходят
мгновенно.

## Порядок работы (TDD)

```bash
bash tests/test-04-cni.sh      # FAIL (нода NotReady, CoreDNS Pending)
bash scripts/04-cni.sh         # sudo не нужен
bash tests/test-04-cni.sh      # PASS
```

## Проверить руками

```bash
kubectl get nodes                              # Ready
kubectl get pods -A | grep -E 'flannel|coredns' # Running
ip a show flannel.1                             # vxlan-интерфейс на ноде
```

## Типовые проблемы

| Симптом | Причина |
|---|---|
| flannel CrashLoop: `failed to find plugin` | образы докачиваются, подожди |
| Нода всё ещё NotReady | `kubectl describe node` — смотри условия; проверь, что flannel Running |
| Поды flannel ImagePullBackOff | нет доступа к docker.io — проверь интернет/DNS на ноде |
| Хочу переделать | `kubectl delete -f <манифест flannel>` и apply заново |
