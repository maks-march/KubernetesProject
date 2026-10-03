# Этап 3. Кластер: kubeadm init (single-node) + снятие taint

## Что делает `kubeadm init`

Одна команда разворачивает весь control-plane:

1. Генерирует **сертификаты** CA + сертификаты компонентов (apiserver, etcd,
   kubelet) — IP ноды вшивается в SAN сертификатов
2. Поднимает **static pods** (etcd, kube-apiserver, controller-manager,
   scheduler) — манифесты кладутся в `/etc/kubernetes/manifests/`, их читает kubelet
3. Пишет **kubeconfig**-файлы для компонентов и `admin.conf` для нас
4. Запускает **kubelet**, регистрирует ноду
5. Поднимает базовые надстройки: CoreDNS, kube-proxy

Аргументы:
- `--apiserver-advertise-address` — IP, на котором apiserver ждёт kubelet/клиентов
- `--pod-network-cidr 10.244.0.0/16` — адреса подов; **обязан совпадать** с CIDR CNI (этап 4 — flannel)
- `--node-name` — имя ноды в кластере

## Single-node: снятие taint

По умолчанию kubeadm вешает на control-plane taint `node-role.kubernetes.io/control-plane:NoSchedule`
— обычным подам там жить запрещено (control-plane берегут). Нода у нас одна,
поэтому taint снимаем — иначе nginx вечно повиснет в Pending.

## Kubeconfig

`admin.conf` копируется в `~/.kube/config` пользователя (владелец — пользователь,
права 600). После этого `kubectl` без sudo.

## Порядок работы

```bash
sudo bash tests/test-03-cluster-init.sh 2>/dev/null || true   # понять, что кластера ещё нет
sudo bash scripts/03-cluster-init.sh
bash tests/test-03-cluster-init.sh     # БЕЗ sudo
```

## Ожидаемые ошибки (это часть плана!)

- **`[ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]`** —
  ядро не настроено → значит этап 1 (`01-node-base.sh`) выполнен не полностью
  и повтори этап 3
- После успешного init: нода будет **NotReady** — так и должно быть, pod-сеть
  появится на этапе 4 (CNI). CoreDNS тоже Pending по этой же причине.

## Проверить руками

```bash
kubectl get nodes                      # NotReady — норма
kubectl get pods -n kube-system        # coredns Pending — норма
sudo ls /etc/kubernetes/manifests/     # static pods
```

## Замечание про IP

IP ноды вшивается в сертификаты. На машине со стабильным IP (физический Linux,
статическая ВМ) — без проблем. Если IP машины меняется между перезагрузками
(частый случай WSL/DHCP) — kubelet потеряет apiserver. Решение — фиксированный
вторичный IP, добавим опциональным этапом, если столкнёмся.
