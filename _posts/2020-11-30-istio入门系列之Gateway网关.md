---
title: istio入门系列之Gateway网关
author: VashonNie
date: 2020-11-30 14:10:00 +0800
updated: 2020-11-30 14:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes,Gateway]
math: true
---

在Kubernetes环境中，使用Kubernetes Ingress资源来指定需要暴露到集群外的服务。 在 Istio 服务网格中，更好的选择（同样适用于 Kubernetes 及其他环境）是使用一种新的配置模型，名为 Istio Gateway。 Gateway 允许应用一些诸如监控和路由规则的 Istio 特性来管理进入集群的流量。

![upload-image](/assets/images/blog/gateway/1.png) 

# ingress网关

ingress是一个入口网关，给服务提供一个访问入口，下面我们来给bookinfo配置一个访问的入口来访问details。

![upload-image](/assets/images/blog/gateway/2.png) 

```
[root@VM-0-13-centos bookinfo]# kubectl create -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: test-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: test-gateway
spec:
  hosts:
  - "*"
  gateways:
  - test-gateway
  http:
  - match:
    - uri:
        prefix: /details
    - uri:
        exact: /health
    route:
    - destination:
        host: details
        port:
          number: 9080
EOF
```

我们在网关只配置访问入口，具体的路由规则在VirtualService进行配置。

下面我们再来做一个测试，通过配置ingress网关来访问我们部署的httpbin服务

首先部署一个httpbin的服务
```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/httpbin/httpbin.yaml
```

查看一下ingressgateway的svc对应的公网ip，假如你没有负载均衡也可以用nodeport来进行配置

```
[root@VM-0-13-centos istio-1.5.1]# kubectl get svc -n istio-system | grep gateway
istio-ingressgateway        LoadBalancer   172.16.99.203    42.194.246.130   15020:32289/TCP,80:30066/TCP,443:32311/TCP,15029:31532/TCP,15030:31660/TCP,15031:30183/TCP,15032:30388/TCP,31400:30952/TCP,15443:31259/TCP   3d19h
```

部署ingressgateway来访问httpbin

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.example.com"
EOF
```

为通过 Gateway 的入口流量配置路由

```
$ kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - "httpbin.example.com"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - uri:
        prefix: /status
    - uri:
        prefix: /delay
    route:
    - destination:
        port:
          number: 8000
        host: httpbin
EOF
```

已为 httpbin 服务创建了虚拟服务配置，包含两个路由规则，允许流量流向路径 /status 和 /delay。

gateways 列表规约了哪些请求允许通过 httpbin-gateway 网关。 所有其他外部请求均被拒绝并返回 404 响应。

我们来通过网关svc的公网ip来进行测试一下

```
[root@VM-0-13-centos istio-1.5.1]# curl -I -HHost:httpbin.example.com http://42.194.246.130/status/200
HTTP/1.1 200 OK
server: istio-envoy
date: Thu, 03 Dec 2020 04:04:34 GMT
content-type: text/html; charset=utf-8
access-control-allow-origin: *
access-control-allow-credentials: true
content-length: 0
x-envoy-upstream-service-time: 6

[root@VM-0-13-centos istio-1.5.1]# curl -I -HHost:httpbin.example.com http://42.194.246.130/headers
HTTP/1.1 404 Not Found
date: Thu, 03 Dec 2020 04:04:48 GMT
server: istio-envoy
transfer-encoding: chunked
```

使用 -H 标识将 HTTP 头部参数 Host 设置为 “httpbin.example.com”。 该操作为必须操作，因为 ingress Gateway 已被配置用来处理 “httpbin.example.com” 的服务请求，而在测试环境中并没有为该主机绑定 DNS 而是简单直接地向 ingress IP 发送请求

# egress网关

由于默认情况下，来自 Istio-enable Pod 的所有出站流量都会重定向到其 Sidecar 代理，群集外部 URL 的可访问性取决于代理的配置。默认情况下，Istio 将 Envoy 代理配置为允许传递未知服务的请求。尽管这为入门 Istio 带来了方便，但是，通常情况下，配置更严格的控制是更可取的。

![upload-image](/assets/images/blog/gateway/3.png) 

三种访问外部服务的方法：

* 允许 Envoy 代理将请求传递到未在网格内配置过的服务。
* 配置 service entries 以提供对外部服务的受控访问。
* 对于特定范围的 IP，完全绕过 Envoy 代理。

下面我们将httpbin注册为网格内部的服务，并配置流控策略。

## 创建一个sleep服务访问httpbin接口
```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/sleep/sleep.yaml
serviceaccount/sleep created
service/sleep created
deployment.apps/sleep created
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f - << EOF 
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-ext
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
  location: MESH_EXTERNAL
EOF
serviceentry.networking.istio.io/httpbin-ext created
[root@VM-0-13-centos istio-1.5.1]# kubectl get se
NAME          HOSTS           LOCATION        RESOLUTION   AGE
httpbin-ext   [httpbin.org]   MESH_EXTERNAL   DNS          11s

[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-krj9n -c sleep -- curl http://httpbin.org/ip
{
  "origin": "106.53.155.140"
}

```
## 配置egress网关

```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: istio-egressgateway
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - httpbin.org
EOF
```

## 配置VirtualService和DestinationRule
```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: vs-for-egressgateway
spec:
  hosts:
  - httpbin.org
  gateways:
  - istio-egressgateway
  - mesh
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        subset: httpbin
        port:
          number: 80
      weight: 100
  - match:
    - gateways:
      - istio-egressgateway
      port: 80
    route:
    - destination:
        host: httpbin.org
        port:
          number: 80
      weight: 100
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: dr-for-egressgateway
spec:
  host: istio-egressgateway.istio-system.svc.cluster.local
  subsets:
  - name: httpbin
EOF
```

## 进行测试

```
[root@VM-0-13-centos istio-1.5.1]# kubectl exec -it sleep-5b7bf56c54-krj9n -c sleep -- curl http://httpbin.org/ip
{
  "origin": "10.0.1.38, 106.53.152.241"
}

[root@VM-0-13-centos tke]# kubectl logs -f istio-egressgateway-666956b747-zp4vh -n istio-system

[2020-12-02T12:51:35.467Z] "GET /ip HTTP/2" 200 - "-" "-" 0 44 462 461 "10.0.1.38" "curl/7.69.1" "fdfc6cbd-a888-96b1-a45e-e6edfe68caec" "httpbin.org" "3.230.36.204:80" outbound|80||httpbin.org 10.0.2.116:38220 10.0.2.116:80 10.0.1.38:37650 - -
```

从上面发现，我们发现到httpbind的请求都是通过egress去访问的。
