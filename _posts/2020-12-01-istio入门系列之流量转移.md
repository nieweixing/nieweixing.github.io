---
title: istio入门系列之流量转移
author: VashonNie
date: 2020-12-01 10:10:00 +0800
updated: 2020-12-01 10:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes]
math: true
---

一个常见的用例是将流量从一个版本的微服务逐渐迁移到另一个版本。在 Istio 中，您可以通过配置一系列规则来实现此目标， 这些规则将一定百分比的流量路由到一个或另一个服务。在本任务中，您将会把 50％ 的流量发送到 reviews:v1，另外 50％ 的流量发送到 reviews:v3。然后，再把 100％ 的流量发送到 reviews:v3 来完成迁移。

istio中的流量转移常用于蓝绿部署中

![upload-image](/assets/images/blog/liuliangzhuanyi/1.png) 

首先我们将访问bokinfo所有的流量都指向v1版本

```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml
virtualservice.networking.istio.io/productpage created
virtualservice.networking.istio.io/reviews configured
virtualservice.networking.istio.io/ratings created
virtualservice.networking.istio.io/details created
[root@VM-0-13-centos istio-1.5.1]# cat samples/bookinfo/networking/virtual-service-all-v1.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: productpage
spec:
  hosts:
  - productpage
  http:
  - route:
    - destination:
        host: productpage
        subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - route:
    - destination:
        host: ratings
        subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: details
spec:
  hosts:
  - details
  http:
  - route:
    - destination:
        host: details
        subset: v1
---

```

然后我们把50%的流量转到v1版本，50%的流量转到v3版本

```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml
virtualservice.networking.istio.io/reviews configured
[root@VM-0-13-centos istio-1.5.1]# cat samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 50
    - destination:
        host: reviews
        subset: v3
      weight: 50
```

刷新浏览器中的 /productpage 页面，大约有50%的几率会看到页面中出带红色星级的评价内容。这是因为v3版本的reviews访问了带星级评级的 ratings 服务，但v1版本却没有。
