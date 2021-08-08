---
title: cert-manager为域名签发免费证书
author: VashonNie
date: 2021-08-07 14:10:00 +0800
updated: 2021-08-07 14:10:00 +0800
categories: [cert-manager]
tags: [cert-manager]
math: true
---

随着HTTPS不断普及，大多数网站开始由HTTP升级到HTTPS。使用HTTPS需要向权威机构申请证书，并且需要付出一定的成本，如果需求数量多，则开支也相对增加。cert-manager 是 Kubernetes 上的全能证书管理工具，支持利用 cert-manager 基于 ACME 协议与 Let's Encrypt 签发免费证书并为证书自动续期，实现永久免费使用证书。

cert-manager支持许多dns provider，但不支持国内的dnspod，不过cert-manager提供了Webhook机制来扩展provider，社区也有dnspod的provider实现，下面我们在k8s中通过cert-manager和cert-manager-webhook-dnspod来为域名签发免费证书，

# 环境配置

* k8s集群：这里我们用的腾讯云eks集群
* 域名：腾讯云购买的域名，并用dnspod进行解析
* dnspod-token：从<https://console.dnspod.cn/account/token/apikey>创建一个
* nginx-ingress：需要在k8s中部署nginx-ingress，后续配置ingress验证证书

集群已经部署了nginx-ingress并且支持helm3部署应用到集群。

# 安装部署cert-manager

首先我们安装cert-manager到集群中，执行下面的命令部署既可

```
kubectl apply --validate=false -f https://raw.githubusercontent.com/TencentCloudContainerTeam/manifest/master/cert-manager/cert-manager.yaml
```

# 安装cert-manager-webhook-dnspod

cert-manager-webhook-dnspod通过helm安装，首先我们配置下dnspod-webhook的配置文件。

```
groupName: cert-manager.io

secrets:
  apiID: xxxxx
  apiToken: xxxxxx

clusterIssuer:
  enabled: true
  email: nwx_qdlg@163.com
```

这里groupname可以和我的保持一致，secret是之前从dnspod上创建获取，clusterIssuer设置为true，邮箱填写自己既可。下面我们helm安装下

```
# git clone --depth 1 https://github.com/qqshfox/cert-manager-webhook-dnspod.git
# helm upgrade --install -n cert-manager -f dnspod-webhook-values.yaml cert-manager-webhook-dnspod ./cert-manager-webhook-dnspod/deploy/cert-manager-webhook-dnspod
```

# Certificate签发证书

创建一个Certificate来给我们的域名签发免费证书

```
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cert-manager-crt
  namespace: default
spec:
  secretName: cert-manager-crt-secret
  issuerRef:
    name: cert-manager-webhook-dnspod-cluster-issuer
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
  - niewx.cn
  - cert-manager.niewx.cn
```

这里cert-manager-webhook-dnspod-cluster-issuer是自动生成的，dnsname需要保证填写的域名是dnspod管理的，最终生成的证书会在cert-manager-crt-secret这个secret。

这里创建之后，等certificate的状态是true，则签发成功，如果为false，需要describe看下报错是什么原因。

```
[eks@VM-0-13-centos cert]$ kubectl get certificate
NAME               READY   SECRET                    AGE
cert-manager-crt   True    cert-manager-crt-secret   104m
```

# 创建ingress使用免费签发证书

这里已经预先部署了一个简单go的demo服务

```
[eks@VM-0-13-centos cert]$ kubectl get all | grep go
pod/go-test-6cb6889655-c2gkh   1/1     Running   0          156m
service/go-test      ClusterIP      10.0.0.110   <none>        3000/TCP       221d
```

然后我们用ingress绑定域名cert-manager.niewx.cn到后端的go服务提供访问

```
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: go-ingress
  namespace: default
spec:
  rules:
  - host: cert-manager.niewx.cn
    http:
      paths:
      - backend:
          serviceName: go-test
          servicePort: 3000
        path: /
  tls:
  - hosts:
    - cert-manager.niewx.cn
    secretName: cert-manager-crt-secret
```

ingress创建好之后，浏览器用https访问域名正常则说明证书签发成功

![upload-image](/assets/images/blog/cert-manager/1.png) 

