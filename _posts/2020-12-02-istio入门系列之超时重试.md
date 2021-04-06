---
title: istio入门系列之超时重试
author: VashonNie
date: 2020-12-02 10:10:00 +0800
updated: 2020-12-02 10:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes]
math: true
---

对于一个系统来说弹性能力很重要，比如出现了超时故障，系统如何去重试，下面我们来讲讲istio中的超时重试。

![upload-image](/assets/images/blog/istio-chaoshi/1.png) 

下面我们在VirtualService中添加超时和重试的配置项，我们将流量打到v2版本，并且给Ratings服务配置一个延迟。

![upload-image](/assets/images/blog/istio-chaoshi/2.png) 


首先我们将流量打到v2版本

```
# kubectl apply -f - << EOF
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
        subset: v2
EOF
```

页面刷新查看只能查看到有黑色星标的v2版本

![upload-image](/assets/images/blog/istio-chaoshi/3.png) 

接下来我们给ratings服务注入一个2s的延迟。

```
# kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percent: 100
        fixedDelay: 2s
    route:
    - destination:
        host: ratings
        subset: v1
EOF
```

下面我们给reviews服务注入一个1s超时设置，其实就是配置一个timeout的字段

```
# kubectl apply -f - << EOF
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
        subset: v2
    timeout: 1s
EOF
```

我们再进行测试刷新会失败，我们设置的延迟是2s，超时时间是1s，所以这里会失败。

![upload-image](/assets/images/blog/istio-chaoshi/4.png) 


下面我们来进行重试的配置，首先需要把reviews的超时配置去掉。

```
# kubectl apply -f - << EOF
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
        subset: v2
EOF
```

接下来，我们给ratings服务配置一下5s的延迟和一个重试2次的配置项retries

```
# kubectl apply -f - << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percent: 100
        fixedDelay: 5s
    route:
    - destination:
        host: ratings
        subset: v1
    retries:
      attempts: 2
      perTryTimeout: 1s
EOF
```

下面我们查看一下ratings的istio-proxy的log，看看是不是出现2次重试的日志

```
# kubectl logs -f ratings-v1-6f855c5fff-684lz -c istio-proxy
```

![upload-image](/assets/images/blog/istio-chaoshi/5.png) 

这里我们查看日志发现有2次的重试的日志，说明我们重试配置成功。