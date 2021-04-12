---
title: istio入门系列之故障注入
author: VashonNie
date: 2020-12-02 14:10:00 +0800
updated: 2020-12-02 14:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes]
math: true
---

本篇文章讲解了istio如何注入故障并测试应用程序的弹性。

![upload-image](/assets/images/blog/istio-guzhangzhuru/1.png) 

# 延迟故障

下面我们来进行故障注入的配置，我们给ratings的v2版本注入一个延迟，这里导致调用出现延迟故障。

```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml
virtualservice.networking.istio.io/productpage unchanged
virtualservice.networking.istio.io/reviews configured
virtualservice.networking.istio.io/ratings configured
virtualservice.networking.istio.io/details unchanged
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml
virtualservice.networking.istio.io/reviews configured
```

经过上面的配置，下面是请求的流程：

* productpage → reviews:v2 → ratings (针对 jason 用户)
* productpage → reviews:v1 (其他用户)

我们来测试下是否生效，我们刷新页面发现没有登录的是没有星标的v1版本

![upload-image](/assets/images/blog/istio-guzhangzhuru/2.png) 

登录jason用户查看到的是v2版本

![upload-image](/assets/images/blog/istio-guzhangzhuru/3.png) 

下面我们配置一下延迟

```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/bookinfo/networking/virtual-service-ratings-test-delay.yaml
virtualservice.networking.istio.io/ratings configured
[root@VM-0-13-centos istio-1.5.1]# cat samples/bookinfo/networking/virtual-service-ratings-test-delay.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    fault:
      delay:
        percentage:
          value: 100.0
        fixedDelay: 7s
    route:
    - destination:
        host: ratings
        subset: v1
  - route:
    - destination:
        host: ratings
        subset: v1
```

![upload-image](/assets/images/blog/istio-guzhangzhuru/4.png) 

刷新页面出现了错误，这是因为延迟超过了硬编码的时间，我们推出jason用户发现又会恢复正常。

![upload-image](/assets/images/blog/istio-guzhangzhuru/5.png) 

从上面的故障注入可以发下，是配置在VirtualService中，配置的字段是fault，我们在这里配置的是延迟故障，其实fault还有一种故障叫abort（终止），下面我们来配置下终止故障。

# 终止故障

```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/bookinfo/networking/virtual-service-ratings-test-abort.yaml
virtualservice.networking.istio.io/ratings configured
[root@VM-0-13-centos istio-1.5.1]# cat samples/bookinfo/networking/virtual-service-ratings-test-abort.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    fault:
      abort:
        percentage:
          value: 100.0
        httpStatus: 500
    route:
    - destination:
        host: ratings
        subset: v1
  - route:
    - destination:
        host: ratings
        subset: v1
```

使用用户jason登陆到/productpage 页面。如果规则成功传播到所有的 pod，您应该能立即看到页面加载并看到 Ratings service is currently unavailable 消息。

![upload-image](/assets/images/blog/istio-guzhangzhuru/6.png) 

如果您注销用户 jason 或在匿名窗口（或其他浏览器）中打开 Bookinfo 应用程序， 您将看到 /productpage 为除 jason 以外的其他用户调用了 reviews:v1（完全不调用 ratings）。 因此，您不会看到任何错误消息。

![upload-image](/assets/images/blog/istio-guzhangzhuru/7.png) 
