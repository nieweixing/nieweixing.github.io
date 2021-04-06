---
title: istio入门系列之流量镜像
author: VashonNie
date: 2020-12-03 10:10:00 +0800
updated: 2020-12-03 10:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes]
math: true
---

流量镜像，也称为影子流量，是一个以尽可能低的风险为生产带来变化的强大的功能。镜像会将实时流量的副本发送到镜像服务。镜像流量发生在主服务的关键请求路径之外。

![upload-image](/assets/images/blog/istio-liuliangjingxiang/1.png) 

我们会经常遇到一些这样的问题，就是在本地测试是正常的，一上线就出问题了，测试覆盖率很高，但是为什么，还是会出现问题，这是因为线上的访问环境和本地有很大差异，特别是流量和数据。这里我们可以用流量镜像来解决这个问题。

首先部署2个httpbin的版本，把流量全部路由到v1版本的测试服务。然后，执行规则将一部分流量镜像到v2版本

httpbin-v1

```
cat <<EOF | istioctl kube-inject -f - | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: ["gunicorn", "--access-logfile", "-", "-b", "0.0.0.0:80", "httpbin:app"]
        ports:
        - containerPort: 80
EOF
```

httpbin-v2

```
cat <<EOF | istioctl kube-inject -f - | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v2
  template:
    metadata:
      labels:
        app: httpbin
        version: v2
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: ["gunicorn", "--access-logfile", "-", "-b", "0.0.0.0:80", "httpbin:app"]
        ports:
        - containerPort: 80
EOF
```

查看下pod的运行情况,这里v1和v2版本都已经运行

```
[root@VM-0-13-centos istio-1.5.1]# kubectl get pod  | grep httpbin-v
httpbin-v1-649dfb4766-kscz5       2/2     Running   0          51s
httpbin-v2-76dcc56c5-99q65        2/2     Running   0          26s
```

接下来我们给httpbin部署一个service

```
$ kubectl create -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: httpbin
EOF
```

部署一个sleep服务用来执行curl请求

```
cat <<EOF | istioctl kube-inject -f - | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: tutum/curl
        command: ["/bin/sleep","infinity"]
        imagePullPolicy: IfNotPresent
EOF
```

默认svc会将流量负载到v1和v2版本，这里我们配置将流量只转发到v1版本

```
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
EOF
```

下面我们来对httpbin发起请求来测试一下

```
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-krj9n -c sleep -- sh -c 'curl  http://httpbin:8000/headers' | python -m json.tool
{
    "headers": {
        "Accept": "*/*",
        "Content-Length": "0",
        "Host": "httpbin:8000",
        "User-Agent": "curl/7.69.1",
        "X-B3-Parentspanid": "fe987c2ce7e2b1ed",
        "X-B3-Sampled": "1",
        "X-B3-Spanid": "2ad53d6b71ccbc6c",
        "X-B3-Traceid": "ebc0ec67ece15107fe987c2ce7e2b1ed",
        "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/default/sa/default;Hash=fc446005ac6e411b601b432459d05464eb3355fb081401eddce96ee810a5074a;Subject=\"\";URI=spiffe://cluster.local/ns/default/sa/sleep"
    }
}
[root@VM-0-13-centos istio-1.5.1]# kubectl logs -f httpbin-v1-649dfb4766-kscz5 -c httpbin
[2020-12-07 02:54:26 +0000] [1] [INFO] Starting gunicorn 19.9.0
[2020-12-07 02:54:26 +0000] [1] [INFO] Listening at: http://0.0.0.0:80 (1)
[2020-12-07 02:54:26 +0000] [1] [INFO] Using worker: sync
[2020-12-07 02:54:26 +0000] [9] [INFO] Booting worker with pid: 9
127.0.0.1 - - [07/Dec/2020:03:00:37 +0000] "GET /headers HTTP/1.1" 200 516 "-" "curl/7.69.1"



[root@VM-0-13-centos istio-1.5.1]# kubectl logs -f httpbin-v2-76dcc56c5-99q65 -c httpbin
[2020-12-07 02:54:40 +0000] [1] [INFO] Starting gunicorn 19.9.0
[2020-12-07 02:54:40 +0000] [1] [INFO] Listening at: http://0.0.0.0:80 (1)
[2020-12-07 02:54:40 +0000] [1] [INFO] Using worker: sync
[2020-12-07 02:54:40 +0000] [8] [INFO] Booting worker with pid: 8
```

从上面的日志可以发下，只有httpbin v1中有产生日志，这里说明流量只转发到v1版本，接下来我们改变流量规则将流量镜像到v2

```
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
    mirror:
      host: httpbin
      subset: v2
    mirror_percent: 100
EOF
```

这个路由规则发送 100% 流量到 v1。最后一段mirror字段表示你将镜像流量到 httpbin:v2 服务。当流量被镜像时，请求将发送到镜像服务中，并在 headers 中的 Host/Authority 属性值上追加 -shadow。例如cluster-1变为cluster-1-shadow。

此外，重点注意这些被镜像的流量是『即发即弃』的，就是说镜像请求的响应会被丢弃。

您可以使用mirror_percent属性来设置镜像流量的百分比，而不是镜像全部请求。为了兼容老版本，如果这个属性不存在，将镜像所有流量。

下面我们来进行测试下，对httpbin发起请求，看看v1和v2版本是否会收到请求

```
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-krj9n -c sleep -- sh -c 'curl  http://httpbin:8000/headers' | python -m json.tool
{
    "headers": {
        "Accept": "*/*",
        "Content-Length": "0",
        "Host": "httpbin:8000",
        "User-Agent": "curl/7.69.1",
        "X-B3-Parentspanid": "cb8d626990ce882b",
        "X-B3-Sampled": "1",
        "X-B3-Spanid": "3f57b73d4468f2a2",
        "X-B3-Traceid": "a61409e7f4c4d713cb8d626990ce882b",
        "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/default/sa/httpbin;Hash=fc446005ac6e411b601b432459d05464eb3355fb081401eddce96ee810a5074a;Subject=\"\";URI=spiffe://cluster.local/ns/default/sa/sleep"
    }
}
[root@VM-0-13-centos istio-1.5.1]# kubectl logs -f httpbin-v1-649dfb4766-kscz5 -c httpbin
[2020-12-07 02:54:26 +0000] [1] [INFO] Starting gunicorn 19.9.0
[2020-12-07 02:54:26 +0000] [1] [INFO] Listening at: http://0.0.0.0:80 (1)
[2020-12-07 02:54:26 +0000] [1] [INFO] Using worker: sync
[2020-12-07 02:54:26 +0000] [9] [INFO] Booting worker with pid: 9
127.0.0.1 - - [07/Dec/2020:03:00:37 +0000] "GET /headers HTTP/1.1" 200 516 "-" "curl/7.69.1"
^C
[root@VM-0-13-centos istio-1.5.1]# kubectl logs -f httpbin-v2-76dcc56c5-99q65 -c httpbin
[2020-12-07 02:54:40 +0000] [1] [INFO] Starting gunicorn 19.9.0
[2020-12-07 02:54:40 +0000] [1] [INFO] Listening at: http://0.0.0.0:80 (1)
[2020-12-07 02:54:40 +0000] [1] [INFO] Using worker: sync
[2020-12-07 02:54:40 +0000] [8] [INFO] Booting worker with pid: 8
127.0.0.1 - - [07/Dec/2020:03:06:36 +0000] "GET /headers HTTP/1.1" 200 556 "-" "curl/7.69.1"
```

可以发现，我们对httpbin发起访问，v1和v2版本日志都会打印，说明都会有流量进来，如果需要检查内部流量，我们可以通过如下方法


```
[root@VM-0-13-centos istio-1.5.1]# export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})
[root@VM-0-13-centos istio-1.5.1]# export V1_POD_IP=$(kubectl get pod -l app=httpbin,version=v1 -o jsonpath={.items..status.podIP})
[root@VM-0-13-centos istio-1.5.1]# export V2_POD_IP=$(kubectl get pod -l app=httpbin,version=v2 -o jsonpath={.items..status.podIP})
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it $SLEEP_POD -c istio-proxy -- sudo tcpdump -A -s 0 host $V1_POD_IP or host $V2_POD_IP
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
05:47:50.159513 IP sleep-7b9f8bfcd-2djx5.38836 > 10-233-75-11.httpbin.default.svc.cluster.local.80: Flags [P.], seq 4039989036:4039989832, ack 3139734980, win 254, options [nop,nop,TS val 77427918 ecr 76730809], length 796: HTTP: GET /headers HTTP/1.1
E..P2.X.X.X.
.K.
.K....P..W,.$.......+.....
..t.....GET /headers HTTP/1.1
host: httpbin:8000
user-agent: curl/7.35.0
accept: */*
x-forwarded-proto: http
x-request-id: 571c0fd6-98d4-4c93-af79-6a2fe2945847
x-envoy-decorator-operation: httpbin.default.svc.cluster.local:8000/*
x-b3-traceid: 82f3e0a76dcebca2
x-b3-spanid: 82f3e0a76dcebca2
x-b3-sampled: 0
x-istio-attributes: Cj8KGGRlc3RpbmF0aW9uLnNlcnZpY2UuaG9zdBIjEiFodHRwYmluLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwKPQoXZGVzdGluYXRpb24uc2VydmljZS51aWQSIhIgaXN0aW86Ly9kZWZhdWx0L3NlcnZpY2VzL2h0dHBiaW4KKgodZGVzdGluYXRpb24uc2VydmljZS5uYW1lc3BhY2USCRIHZGVmYXVsdAolChhkZXN0aW5hdGlvbi5zZXJ2aWNlLm5hbWUSCRIHaHR0cGJpbgo6Cgpzb3VyY2UudWlkEiwSKmt1YmVybmV0ZXM6Ly9zbGVlcC03YjlmOGJmY2QtMmRqeDUuZGVmYXVsdAo6ChNkZXN0aW5hdGlvbi5zZXJ2aWNlEiMSIWh0dHBiaW4uZGVmYXVsdC5zdmMuY2x1c3Rlci5sb2NhbA==
content-length: 0


05:47:50.159609 IP sleep-7b9f8bfcd-2djx5.49560 > 10-233-71-7.httpbin.default.svc.cluster.local.80: Flags [P.], seq 296287713:296288571, ack 4029574162, win 254, options [nop,nop,TS val 77427918 ecr 76732809], length 858: HTTP: GET /headers HTTP/1.1
E.....X.X...
.K.
.G....P......l......e.....
..t.....GET /headers HTTP/1.1
host: httpbin-shadow:8000
user-agent: curl/7.35.0
accept: */*
x-forwarded-proto: http
x-request-id: 571c0fd6-98d4-4c93-af79-6a2fe2945847
x-envoy-decorator-operation: httpbin.default.svc.cluster.local:8000/*
x-b3-traceid: 82f3e0a76dcebca2
x-b3-spanid: 82f3e0a76dcebca2
x-b3-sampled: 0
x-istio-attributes: Cj8KGGRlc3RpbmF0aW9uLnNlcnZpY2UuaG9zdBIjEiFodHRwYmluLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwKPQoXZGVzdGluYXRpb24uc2VydmljZS51aWQSIhIgaXN0aW86Ly9kZWZhdWx0L3NlcnZpY2VzL2h0dHBiaW4KKgodZGVzdGluYXRpb24uc2VydmljZS5uYW1lc3BhY2USCRIHZGVmYXVsdAolChhkZXN0aW5hdGlvbi5zZXJ2aWNlLm5hbWUSCRIHaHR0cGJpbgo6Cgpzb3VyY2UudWlkEiwSKmt1YmVybmV0ZXM6Ly9zbGVlcC03YjlmOGJmY2QtMmRqeDUuZGVmYXVsdAo6ChNkZXN0aW5hdGlvbi5zZXJ2aWNlEiMSIWh0dHBiaW4uZGVmYXVsdC5zdmMuY2x1c3Rlci5sb2NhbA==
x-envoy-internal: true
x-forwarded-for: 10.233.75.12
content-length: 0


05:47:50.166734 IP 10-233-75-11.httpbin.default.svc.cluster.local.80 > sleep-7b9f8bfcd-2djx5.38836: Flags [P.], seq 1:472, ack 796, win 276, options [nop,nop,TS val 77427925 ecr 77427918], length 471: HTTP: HTTP/1.1 200 OK
E....3X.?...
.K.
.K..P...$....ZH...........
..t...t.HTTP/1.1 200 OK
server: envoy
date: Fri, 15 Feb 2019 05:47:50 GMT
content-type: application/json
content-length: 241
access-control-allow-origin: *
access-control-allow-credentials: true
x-envoy-upstream-service-time: 3

{
  "headers": {
    "Accept": "*/*",
    "Content-Length": "0",
    "Host": "httpbin:8000",
    "User-Agent": "curl/7.35.0",
    "X-B3-Sampled": "0",
    "X-B3-Spanid": "82f3e0a76dcebca2",
    "X-B3-Traceid": "82f3e0a76dcebca2"
  }
}

05:47:50.166789 IP sleep-7b9f8bfcd-2djx5.38836 > 10-233-75-11.httpbin.default.svc.cluster.local.80: Flags [.], ack 472, win 262, options [nop,nop,TS val 77427925 ecr 77427925], length 0
E..42.X.X.\.
.K.
.K....P..ZH.$.............
..t...t.
05:47:50.167234 IP 10-233-71-7.httpbin.default.svc.cluster.local.80 > sleep-7b9f8bfcd-2djx5.49560: Flags [P.], seq 1:512, ack 858, win 280, options [nop,nop,TS val 77429926 ecr 77427918], length 511: HTTP: HTTP/1.1 200 OK
E..3..X.>...
.G.
.K..P....l....;...........
..|...t.HTTP/1.1 200 OK
server: envoy
date: Fri, 15 Feb 2019 05:47:49 GMT
content-type: application/json
content-length: 281
access-control-allow-origin: *
access-control-allow-credentials: true
x-envoy-upstream-service-time: 3

{
  "headers": {
    "Accept": "*/*",
    "Content-Length": "0",
    "Host": "httpbin-shadow:8000",
    "User-Agent": "curl/7.35.0",
    "X-B3-Sampled": "0",
    "X-B3-Spanid": "82f3e0a76dcebca2",
    "X-B3-Traceid": "82f3e0a76dcebca2",
    "X-Envoy-Internal": "true"
  }
}

05:47:50.167253 IP sleep-7b9f8bfcd-2djx5.49560 > 10-233-71-7.httpbin.default.svc.cluster.local.80: Flags [.], ack 512, win 262, options [nop,nop,TS val 77427926 ecr 77429926], length 0
E..4..X.X...
.K.
.G....P...;..n............
..t...|.
```

