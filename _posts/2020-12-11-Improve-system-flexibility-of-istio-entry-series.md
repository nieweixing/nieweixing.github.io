---
title: istio入门系列之提升系统弹性能力
author: VashonNie
date: 2020-12-11 14:10:00 +0800
updated: 2020-12-11 14:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes]
math: true
---

本章我们来讲讲如何通过istio来提升系统的弹性能力，弹性能力主要包含如下几个方面，我们今天看看如何用istio中的一些功能去解决这些问题。

* 容错性：重试、幂等
* 伸缩性：自动水平扩展（autoscaling）
* 过载保护：超时、熔断、降级、限流
* 弹性测试：故障注入

今天我们讲讲如何通过istio中的超时、重试、熔断、故障注入来提升服务的弹性能力。

首先我们通过VirtualService来暴露我们之前部署的httpbin服务

```
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
  namespace: demo
spec:
  hosts:
  - "*"
  gateways:
  - httpbin-gateway
  http:
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```

# 超时

首先我们给httpbin配置一个超时

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
  namespace: demo
spec:
  hosts:
  - "*"
  gateways:
  - httpbin-gateway
  http:
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
    timeout: 1s

```

![upload-image](/assets/images/blog/istio-tanxingnengli/1.png) 

我们访问下delay接口，配置一个2s的，会发现有超时错误

# 重试

首先我们给httpbin的VirtualService的增加一个重试配置

```
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
  namespace: demo
spec:
  hosts:
  - "*"
  gateways:
  - httpbin-gateway
  http:
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
    retry:
      attempts: 3
      perTryTimeout: 1s
    timeout: 8s
EOF
```

然后再浏览器中输入http://106.55.219.93/status/500，去httpbin的enovy中查看日志是否有进行重试

![upload-image](/assets/images/blog/istio-tanxingnengli/2.png) 

从日志中我们看出来重试调用了3次/status/500的接口

# 熔断

我们先给httpbin来配置下熔断

```
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin
  namespace: demo
spec:
  host: httpbin
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
      outlierDetection:
        consecutiveErrors: 1
        interval: 1s
        baseEjectionTime: 3m
        maxEjectionPercent: 100
EOF
```

具体的测试方法可以参考之前的熔断详细介绍<https://www.niewx.cn/istio/2020/12/02/istio%E5%85%A5%E9%97%A8%E7%B3%BB%E5%88%97%E4%B9%8B%E7%86%94%E6%96%AD/>

# 故障注入延迟

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
  namespace: demo
spec:
  hosts:
    - '*'
  gateways:
    - httpbin-gateway
  http:
    - route:
        - destination:
            host: httpbin
            port:
              number: 8000
      fault:
        delay:
          fixedDelay: 3000ms
          percentage:
            value: 100
```

这里我们给httpbin服务注入一个3s的延迟，刷新页面可以发现需要3s才能刷新出页面

# 故障注入终止

我们给httpbin配置一个终止故障，刷新页面会发现有出现终止报错

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
  namespace: demo
spec:
  hosts:
    - '*'
  gateways:
    - httpbin-gateway
  http:
    - route:
        - destination:
            host: httpbin
            port:
              number: 8000
      fault:
        abort:
          httpStatus: 500
          percentage:
            value: 100
```

![upload-image](/assets/images/blog/istio-tanxingnengli/3.png) 
