---
title: istio之VirtualService如何限制CORS请求头
author: VashonNie
date: 2021-03-19 14:10:00 +0800
updated: 2021-03-19 14:10:00 +0800
categories: [Istio]
tags: [Istio,VirtualService]
math: true
---

有的时候服务被访问的时候可能会存在一些CORS漏洞，这里我们就需要设置下Access-Control-Allow-Origin，但是这个服务如果是通过istio来进行管理，那么我们怎么来限制哪些域名可以进行访问我们的服务呢？下面我们来配置下

# 服务部署

首先我们在k8s中部署一个nginx服务

```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: nginx
    qcloud-app: nginx
  name: nginx
  namespace: mesh
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: nginx
      qcloud-app: nginx
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      labels:
        k8s-app: nginx
        qcloud-app: nginx
    spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 250m
            memory: 256Mi
        securityContext:
          privileged: false
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
```

# 部署Gateway

这里我们用公网的ingress作为访问的入口，绑定88端口进行访问
```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: nginx-gw
  namespace: mesh
spec:
  servers:
    - port:
        number: 88
        name: HTTP-88-2qiw
        protocol: HTTP
      hosts:
        - '*'
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
```

# VirtualService不做任何限制

我们正常部署一个VirtualService，不做任何Origin限制，这里返回头Access-Control-Allow-Origin里面应该是*

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: nginx-vs
  namespace: mesh
spec:
  hosts:
    - '*'
  gateways:
    - mesh/nginx-gw
  http:
    - route:
        - destination:
            host: nginx.mesh.svc.cluster.local

```

下面我们测试下看看，access-control-allow-origin返回确实是*

```
[root@VM-0-3-centos grpcurl]# curl -I 106.55.219.93:88
HTTP/1.1 200 OK
server: istio-envoy
date: Sat, 20 Mar 2021 11:18:16 GMT
content-type: text/html; charset=utf-8
content-length: 9593
access-control-allow-origin: *
access-control-allow-credentials: true
x-envoy-upstream-service-time: 2
```

# VirtualService加上Origins限制

这里我们只允许origin带这2个域名才能访问nginx.niewx.cn和test.niewx.cn，注意下这里用的正则匹配，如果有多个域名用|分割开，如果有https和http可以在https后面加个？

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: nginx-vs
  namespace: mesh
spec:
  hosts:
    - '*'
  gateways:
    - mesh/nginx-gw
  http:
    - route:
        - destination:
            host: nginx.mesh.svc.cluster.local
      corsPolicy:
        allowOrigins:
          - regex: 'https?://nginx.niewx.cn|https?://test.niewx.cn'
```

下面我们来测试下，看下请求里面origin带的域名在我们的配置里面会怎么样，不在我们配置的域名会怎么样

```
[root@baron-cvm ~]# curl  -I -v -H 'Origin: https://test.niewx.cn' 106.55.219.93:88
* About to connect() to 106.55.219.93 port 88 (#0)
*   Trying 106.55.219.93...
* Connected to 106.55.219.93 (106.55.219.93) port 88 (#0)
> HEAD / HTTP/1.1
> User-Agent: curl/7.29.0
> Host: 106.55.219.93:88
> Accept: */*
> Origin: https://test.niewx.cn
>
< HTTP/1.1 200 OK
HTTP/1.1 200 OK
< server: istio-envoy
server: istio-envoy
< date: Sun, 21 Mar 2021 12:52:07 GMT
date: Sun, 21 Mar 2021 12:52:07 GMT
< content-type: text/html
content-type: text/html
< content-length: 612
content-length: 612
< last-modified: Tue, 09 Mar 2021 15:27:51 GMT
last-modified: Tue, 09 Mar 2021 15:27:51 GMT
< etag: "604793f7-264"
etag: "604793f7-264"
< accept-ranges: bytes
accept-ranges: bytes
< x-envoy-upstream-service-time: 0
x-envoy-upstream-service-time: 0
< access-control-allow-origin: https://test.niewx.cn
access-control-allow-origin: https://test.niewx.cn

<
* Connection #0 to host 106.55.219.93 left intact
[root@baron-cvm ~]# curl  -I -v -H 'Origin: https://nginx.niewx.cn' 106.55.219.93:88
* About to connect() to 106.55.219.93 port 88 (#0)
*   Trying 106.55.219.93...
* Connected to 106.55.219.93 (106.55.219.93) port 88 (#0)
> HEAD / HTTP/1.1
> User-Agent: curl/7.29.0
> Host: 106.55.219.93:88
> Accept: */*
> Origin: https://nginx.niewx.cn
>
< HTTP/1.1 200 OK
HTTP/1.1 200 OK
< server: istio-envoy
server: istio-envoy
< date: Sun, 21 Mar 2021 12:52:16 GMT
date: Sun, 21 Mar 2021 12:52:16 GMT
< content-type: text/html
content-type: text/html
< content-length: 612
content-length: 612
< last-modified: Tue, 09 Mar 2021 15:27:51 GMT
last-modified: Tue, 09 Mar 2021 15:27:51 GMT
< etag: "604793f7-264"
etag: "604793f7-264"
< accept-ranges: bytes
accept-ranges: bytes
< x-envoy-upstream-service-time: 0
x-envoy-upstream-service-time: 0
< access-control-allow-origin: https://nginx.niewx.cn
access-control-allow-origin: https://nginx.niewx.cn

<
* Connection #0 to host 106.55.219.93 left intact
[root@baron-cvm ~]# curl  -I -v -H 'Origin: https://example.niewx.cn' 106.55.219.93:88
* About to connect() to 106.55.219.93 port 88 (#0)
*   Trying 106.55.219.93...
* Connected to 106.55.219.93 (106.55.219.93) port 88 (#0)
> HEAD / HTTP/1.1
> User-Agent: curl/7.29.0
> Host: 106.55.219.93:88
> Accept: */*
> Origin: https://example.niewx.cn
>
< HTTP/1.1 200 OK
HTTP/1.1 200 OK
< server: istio-envoy
server: istio-envoy
< date: Sun, 21 Mar 2021 12:52:28 GMT
date: Sun, 21 Mar 2021 12:52:28 GMT
< content-type: text/html
content-type: text/html
< content-length: 612
content-length: 612
< last-modified: Tue, 09 Mar 2021 15:27:51 GMT
last-modified: Tue, 09 Mar 2021 15:27:51 GMT
< etag: "604793f7-264"
etag: "604793f7-264"
< accept-ranges: bytes
accept-ranges: bytes
< x-envoy-upstream-service-time: 1
x-envoy-upstream-service-time: 1

<
* Connection #0 to host 106.55.219.93 left intact
```

从上面测试，我们分别用了test.niewx.cn、nginx.test.cn、example.niewx.cn这3个域名的https方式作为origin去请求我们的gateway，发现不在我们配置的allowOrigins白名单里面access-control-allow-origin这个字段是不存在的。但是我们发现example.niewx.cn这个域名不在allowOrigins配置，发起请求还是能正常返回内容，这是因为这里nginx的后端处理逻辑是这样，如果需要response不返回内容，需要在后端代码进行处理下跨域请求才行，配置下不在access-control-allow-origin里面就返回其他错误码。