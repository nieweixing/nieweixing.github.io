---
title: istio入门系列之VirtualService和DestinationRule
author: VashonNie
date: 2020-11-29 12:10:00 +0800
updated: 2020-11-29 12:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes,VirtualService,DestinationRule]
math: true
---

本文我们讲解下如何通过用Virtual Service和 Destination Rule设置服务路由规则。

我们还是以之前部署的bookinfo示例进行操作，我们通过Virtual Service路由到reviews的v1版本。

![upload-image](/assets/images/blog/VirtualService/1.png) 

bookinfo默认访问的情况是刷新页面会出现三种颜色星标，后续我们需要做的就是刷新页面让星标颜色不变。

![upload-image](/assets/images/blog/VirtualService/2.png) 

![upload-image](/assets/images/blog/VirtualService/3.png) 

![upload-image](/assets/images/blog/VirtualService/4.png) 

下面我们直接创建对应的VirtualService和DestinationRule

```
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml
virtualservice.networking.istio.io/productpage created
virtualservice.networking.istio.io/reviews created
virtualservice.networking.istio.io/ratings created
virtualservice.networking.istio.io/details created
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
destinationrule.networking.istio.io/productpage created
destinationrule.networking.istio.io/reviews created
destinationrule.networking.istio.io/ratings created
destinationrule.networking.istio.io/details created
```

再次刷新页面会一直停留在这个页面，一直都并不会变化，这个说明我们指向v1版本的路由规则实现了。

![upload-image](/assets/images/blog/VirtualService/5.png) 

接下来我们详细的研究下VirtualService和DestinationRule的配置

![upload-image](/assets/images/blog/VirtualService/6.png) 

samples/bookinfo/networking/virtual-service-all-v1.yaml

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: productpage
spec:
  hosts:   # 设置目标地址
  - productpage
  http:     
  - route:
    - destination:
        host: productpage
        subset: v1  #子集版本
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

samples/bookinfo/networking/destination-rule-all.yaml

```
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: productpage
spec:
  host: productpage
  subsets:
  - name: v1
    labels:
      version: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews #目标路径
  subsets:
  - name: v1  #目标规则
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ratings
spec:
  host: ratings
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v2-mysql
    labels:
      version: v2-mysql
  - name: v2-mysql-vm
    labels:
      version: v2-mysql-vm
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: details
spec:
  host: details
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
---
```

来自特定用户的所有流量路由到特定服务版本。在这，来自名为 jason 的用户的所有流量将被路由到服务 reviews:v2

```
$ kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml

$ kubectl get virtualservice reviews -o yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
  ...
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

我们登录jason用户，查看的都是带星标的v2版本

![upload-image](/assets/images/blog/VirtualService/7.png) 

登录非jason用户查看到的都是不带星标的v1版本

![upload-image](/assets/images/blog/VirtualService/8.png) 