---
title: TKE上搭建kong网关
author: VashonNie
date: 2020-12-22 14:10:00 +0800
updated: 2020-12-22 14:10:00 +0800
categories: [Kong]
tags: [Kong,TKE]
math: true
---

本文介绍下如何在k8s上搭建kong网关及kong网关的简单使用，kong是一个服务控制平台，通过允许客户管理服务和 API 的整个生命周期，将组织的信息代理到所有服务。Kong Enterprise 建立在 Kong Gateway 之上，使用户能够简化跨混合云和多云部署的 API 和微服务管理。

Kong Enterprise 旨在利用工作流自动化和现代 GitOps 实践在分散式体系结构上运行。通过kong，用户可以：

* 分散应用程序/服务并过渡到微服务
* 创建丰富的的 API 开发人员生态系统
* 主动识别与 API 相关的异常和威胁
* 保护和管理 API/服务，并在整个组织中提高 API 可见性

kong的架构大致如下图

![upload-image](/assets/images/blog/kong/1.png) 

![upload-image](/assets/images/blog/kong/2.png) 

# 部署kong网关

我们在部署kong网关的时候可以选择用数据库Postgres来存储路由规则，也可部署一个单机的kong服务，注意部署kong的过程中，如果官方镜像拉不下来可以替换镜像成siriuszg/kong-ingress-controller

## 不带数据库部署kong

部署单机的kong服务，我们可以通过helm和kustomize来部署

helm部署的方式，我们将kong部署到kong这个命名空间下

```
# kubectl create kong
# helm repo add kong https://charts.konghq.com
# helm repo update
# helm install kong/kong --generate-name --set ingressController.installCRDs=false --namespace kong
```

kustomize部署kong到集群，首先需要安装下kustomize则个工具

```
# wget https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh
# sh install_kustomize.sh
# cp kustomize /usr/local/bin
# kustomize build github.com/kong/kubernetes-ingress-controller/deploy/manifests/base | kubectl apply -f -
```

## 带数据库部署kong

github的kubernetes-ingress-controller项目上有带数据库的yaml文件，我们下周下来修改下就可以了

```
# cd /root
# git clone https://github.com/Kong/kubernetes-ingress-controller.git
# cd /root/kubernetes-ingress-controller/deploy/manifests/postgres
# 修改下postgres.yaml的卷大小为10G和base目录下kong-ingress-dbless.yaml的镜像
# kustomize build /root/kubernetes-ingress-controller/deploy/manifests/postgres | kubectl apply -f -
```

## 验证kong网关是否部署成功

```
[root@VM-0-13-centos ~]# HOST=$(kubectl get svc --namespace kong kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
[root@VM-0-13-centos ~]# PORT=$(kubectl get svc --namespace kong kong-proxy -o jsonpath='{.spec.ports[0].port}')
[root@VM-0-13-centos ~]# export PROXY_IP=${HOST}:${PORT}
[root@VM-0-13-centos base]# curl $PROXY_IP
{"message":"no Route matched with those values"}
```

出现这个信息表示kong网关部署成功

# 部署kong的UI管理服务konga

```
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: kong
  labels:
    app: konga
  name: konga
spec:
  replicas: 1
  selector:
    matchLabels:
      app: konga
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: konga
    spec:
      containers:
      - env:
        - name: DB_ADAPTER
          value: postgres
        - name: DB_URI
          value: "postgresql://kong:kong@postgres:5432/kong"  #根据实际的kong数据库配置
        image: pantsel/konga
        imagePullPolicy: Always
        name: konga
        ports:
        - containerPort: 1337
          protocol: TCP
      restartPolicy: Always

---
apiVersion: v1
kind: Service
metadata:
  name: konga
  namespace: kong
spec:
  ports:
  - name: http
    port: 1337
    targetPort: 1337
    protocol: TCP
  selector:
    app: konga

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: konga-ingress
  namespace: kong
  annotations:
    kubernetes.io/ingress.class: nwx-ingress
spec:
  rules:
  - host: kong.tke.niewx.cn
    http:
      paths:
      - path: /
        backend:
          serviceName: konga
          servicePort: 1337
```

在浏览器输入http://kong.tke.niewx.cn访问页面

![upload-image](/assets/images/blog/kong/3.png)

创建一个admin账号，这里我们账号为tke，创建完登录即可，这里需要暴露kong的8001端口，作为kong admin api

![upload-image](/assets/images/blog/kong/4.png)

然后配置一个链接连接后端的amin api，这里填写kong的serviceip和端口即可

# 配置kong-ingress

首先我们在default下部署一个httpbin服务和service在，这里我们已经部署好了

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
  namespace: default
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
        ports:
        - containerPort: 80
          protocol: TCP
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always

---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: httpbin
  name: httpbin
  namespace: default
spec:
  ports:
  - name: http
    nodePort: 30178
    port: 8000
    protocol: TCP
    targetPort: 80
  selector:
    app: httpbin
  sessionAffinity: None
  type: NodePort
```

接下来我们创建一个kong的ingress网关来访问后端的httpbin服务

```
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  annotations:
    konghq.com/strip-path: "true"
    kubernetes.io/ingress.class: kong
  name: kong-ingress
  namespace: default
spec:
  rules:
  - http:
      paths:
      - backend:
          serviceName: httpbin
          servicePort: 8000
        path: /foo
      - backend:
          serviceName: httpbin
          servicePort: 8000
        path: /bar
```

创建好之后，我们通过kong的入口lb类型service的vip访问后端的httpbin服务，其他的ingress配置方式可以参考<https://docs.konghq.com/kubernetes-ingress-controller/1.1.x/guides/using-kongplugin-resource/>

```
[root@VM-0-13-centos manifests]# curl -i 159.75.145.38/bar/status/200
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 0
Connection: keep-alive
server: istio-envoy
date: Sun, 10 Jan 2021 07:44:25 GMT
access-control-allow-origin: *
access-control-allow-credentials: true
x-envoy-upstream-service-time: 1
x-envoy-decorator-operation: httpbin.default.svc.cluster.local:8000/*
X-Kong-Upstream-Latency: 3
X-Kong-Proxy-Latency: 1
Via: kong/2.2.1

[root@VM-0-13-centos manifests]# curl -i 159.75.145.38/foo/status/200
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 0
Connection: keep-alive
server: istio-envoy
date: Sun, 10 Jan 2021 08:02:37 GMT
access-control-allow-origin: *
access-control-allow-credentials: true
x-envoy-upstream-service-time: 1
x-envoy-decorator-operation: httpbin.default.svc.cluster.local:8000/*
X-Kong-Upstream-Latency: 4
X-Kong-Proxy-Latency: 1
Via: kong/2.2.1
```

从上面的访问我们可以发现已经成功的通过kong访问到了后端的httpbin服务。

