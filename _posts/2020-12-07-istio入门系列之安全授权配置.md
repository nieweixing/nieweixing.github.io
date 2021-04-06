---
title: istio入门系列之安全授权配置
author: VashonNie
date: 2020-12-07 14:10:00 +0800
updated: 2020-12-07 14:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes]
math: true
---

Istio 的授权功能为网格中的工作负载提供网格、命名空间和工作负载级别的访问控制。这种控制层级提供了以下优点：

工作负载间和最终用户到工作负载的授权。
一个简单的 API：它包括一个单独的并且很容易使用和维护的 AuthorizationPolicy CRD。
灵活的语义：运维人员可以在 Istio 属性上定义自定义条件，并使用 DENY 和 ALLOW 动作。
高性能：Istio 授权是在 Envoy 本地强制执行的。
高兼容性：原生支持 HTTP、HTTPS 和 HTTP2，以及任意普通 TCP 协议。

# 基于JWT授权

下面我们新建一个testjwt的命名空间，部署一个sleep和httpbin服务来进行测试，从下面测试，默认是可以访问通的。

```
[root@VM-0-13-centos istio-1.5.1]# kubectl create ns testjwt
namespace/testjwt created
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f <(istioctl kube-inject -f samples/httpbin/httpbin.yaml) -n testjwt
serviceaccount/httpbin created
service/httpbin created
deployment.apps/httpbin created
[root@VM-0-13-centos istio-1.5.1]# kubectl apply -f <(istioctl kube-inject -f samples/sleep/sleep.yaml) -n testjwt
serviceaccount/sleep created
service/sleep created
deployment.apps/sleep created
[root@VM-0-13-centos istio-1.5.1]# kubectl get pod -n testjwt
NAME                       READY   STATUS    RESTARTS   AGE
httpbin-74887fc549-8cq6c   2/2     Running   0          6m41s
sleep-68dc95bf4c-z8z6g     2/2     Running   0          6m28s
[root@VM-0-13-centos istio-1.5.1]#  kubectl exec -it $(kubectl get pod -l app=sleep -n testjwt -o jsonpath={.items..metadata.name}) -c sleep -n testjwt -- curl http://httpbin.testjwt:8000/ip -s -o /dev/null -w "%{http_code}\n"
200
```

下面我们来配置下身份认证，创建请求认证

```
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "RequestAuthentication"
metadata:
  name: "jwt-example"
  namespace: testjwt
spec:
  selector:
    matchLabels:
      app: httpbin
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.8/security/tools/jwt/samples/jwks.json"
EOF
```

测试不合法的jwt访问，会返回401

```
kubectl exec $(kubectl get pod -l app=sleep -n testjwt -o jsonpath={.items..metadata.name}) -c sleep -n testjwt -- curl "http://httpbin.testjwt:8000/headers" -H "Authorization: Bearer invalidToken" -s -o /dev/null -w "%{http_code}\n"
```

测试没有授权策略时，都可以访问

```
kubectl exec $(kubectl get pod -l app=sleep -n testjwt -o jsonpath={.items..metadata.name}) -c sleep -n testjwt -- curl "http://httpbin.testjwt:8000/headers" -s -o /dev/null -w "%{http_code}\n"
```

创建授权策略

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: testjwt
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: ["testing@secure.istio.io/testing@secure.istio.io"]
EOF
```

解析token

```
TOKEN=$(curl https://raw.githubusercontent.com/malphi/geektime-servicemesh/master/c3-19/demo.jwt -s) && echo $TOKEN | cut -d '.' -f2 - | base64 --decode -
```

测试带token的请求

```
kubectl exec $(kubectl get pod -l app=sleep -n testjwt -o jsonpath={.items..metadata.name}) -c sleep -n testjwt -- curl "http://httpbin.testjwt:8000/headers" -s -o /dev/null -H "Authorization: Bearer $TOKEN" -w "%{http_code}\n"
```

# HTTP流量授权

使用 Istio，您可以轻松地为网格中的workloads设置访问控制。下面看看如何使用 Istio 授权设置访问控制。首先，配置一个简单的 deny-all 策略，来拒绝工作负载的所有请求，然后逐渐地、增量地授予对工作负载更多的访问权

运行下面的命令在 default 命名空间里创建一个 deny-all 策略。该策略没有 selector 字段，它会把策略应用于 default 命名空间中的每个工作负载。spec: 字段为空值 {}，意思是不允许任何流量，有效地拒绝所有请求。

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  {}
EOF

```

我们访问bookinfo页面被拒接

![upload-image](/assets/images/blog/istio-tls/3.png) 

运行下面的命令创建一个 productpage-viewer 策略以容许通过 GET 方法访问 productpage 工作负载。该策略没有在 rules 中设置 from 字段，这意味着所有的请求源都被容许访问，包括所有的用户和工作负载

```
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "productpage-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - to:
    - operation:
        methods: ["GET"]
EOF
```

运行下面的命令创建一个 details-viewer 策略以容许 productpage 工作负载以 GET 方式，通过使用 cluster.local/ns/default/sa/bookinfo-productpage ServiceAccount 去访问 details 工作负载

```
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "details-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: details
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
    to:
    - operation:
        methods: ["GET"]
EOF
```

运行下面的命令创建一个 reviews-viewer 策略以容许 productpage 工作负载以 GET 方式，通过使用 cluster.local/ns/default/sa/bookinfo-productpage ServiceAccount 去访问 reviews 工作负载

```
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "reviews-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
    to:
    - operation:
        methods: ["GET"]
EOF
```

运行下面的命令创建一个 ratings-viewer 策略以容许 reviews 工作负载以 GET 方式，通过使用 cluster.local/ns/default/sa/bookinfo-reviews ServiceAccount 去访问 ratings 工作负载

```
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "ratings-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: ratings
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-reviews"]
    to:
    - operation:
        methods: ["GET"]
EOF
```

在浏览器访问 Bookinfo productpage (http://$GATEWAY_URL/productpage)。你会在 “Book Reviews” 部分看到“黑色”和“红色”评分

# TCP流量的授权

默认情况下，Bookinfo 示例应用只使用 HTTP 协议。 为了演示 TCP 流量的授权，您需要将应用更新到使用 TCP 的版本。 按照下面的步骤，部署 Bookinfo 应用示例，并且将 ratings 服务升级到 v2 版本，在该版本中会使用 TCP 调用后端 MongoDB 服务，然后将授权策略应用到 MongoDB 工作负载上。


使用 bookinfo-ratings-v2 服务账户安装 ratings 工作负载的 v2 版本：

```
$ kubectl apply -f <(istioctl kube-inject -f samples/bookinfo/platform/kube/bookinfo-ratings-v2.yaml)
```

创建适当的 destination rules：

```
$ kubectl apply -f samples/bookinfo/networking/destination-rule-all-mtls.yaml
```

因为 virtual service 规则中引用的 subset 项依赖 destination rules，所以在添加 virtual service 规则之前先等待几秒钟以让 destination rules 传播生效。

在 destination rules 传播生效后，更新 reviews 工作负载以只使用 v2 版本的 ratings 工作负载：

```
$ kubectl apply -f samples/bookinfo/networking/virtual-service-ratings-db.yaml
```

浏览 Bookinfo 的产品页面（http://$GATEWAY_URL/productpage）。

在这一页面中，您会在 Book Reviews 模块中看到一条错误信息：“Ratings service is currently unavailable.”。 这是因为我们现在用的是 v2 版本的 ratings 工作负载，但是我们还没有部署 MongoDB。

部署Mongodb

```
kubectl apply -f <(istioctl kube-inject -f samples/bookinfo/platform/kube/bookinfo-db.yaml)
```

浏览 Bookinfo 的产品页面（http://$GATEWAY_URL/productpage）。

确认 Book Reviews 模块显示了书评。

部署了 MongoDB 工作负载之后，在将授权配置为仅允许授权请求之前，我们需要为工作负载应用默认的 deny-all 策略，以确保默认情况下拒绝对 MongoDB 工作负载的所有请求。

对 MongoDB 工作负载应用默认的 deny-all 策略：

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
spec:
  selector:
    matchLabels:
      app: mongodb
EOF
```

打开 Bookinfo 的 productpage 页面（http://$GATEWAY_URL/productpage）。您会看到：

页面左下角的 Book Details 中包含了书籍类型、页数以及出版商等信息。

页面右下角的 Book Reviews 显示了错误信息：“Ratings service is currently unavailable”。

在配置了默认拒绝所有请求之后，我们需要创建一个 bookinfo-ratings-v2 策略以允许来自 cluster.local/ns/default/sa/bookinfo-ratings-v2 服务账户在 27017 端口上对 MongoDB 工作负载的请求。 我们授权给这个服务账户，是因为来自 ratings-v2 工作负载的请求都用的是 cluster.local/ns/default/sa/bookinfo-ratings-v2 服务账户发出的。

为来自 cluster.local/ns/default/sa/bookinfo-ratings-v2 服务账户的 TCP 流量增强工作负载级别的访问控制：

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: bookinfo-ratings-v2
spec:
  selector:
    matchLabels:
      app: mongodb
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-ratings-v2"]
    to:
    - operation:
        ports: ["27017"]
EOF
```

打开 Bookinfo 的 productpage 页面（http://$GATEWAY_URL/productpage），您现在应该看到以下各节按预期工作：

页面左下角的 Book Details 中包含了书籍类型、页数以及出版商等信息。

页面右下角的 Book Reviews 显示了红色星级的书评。

恭喜！ 您已经成功部署了通过 TCP 流量进行通信的工作负载，并应用了网格级别和工作负载级别的授权策略来对请求实施访问控制。