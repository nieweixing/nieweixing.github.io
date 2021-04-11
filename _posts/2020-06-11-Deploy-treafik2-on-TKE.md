---
title: TKE上部署treafik2
author: VashonNie
date: 2020-06-11 14:10:00 +0800
updated: 2020-06-11 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [Kubernetes,Docker,TKE,Treafik2]
math: true
---

腾讯云上有默认的提供的ingress服务，如果你不想用提供的，想用最新的treafik来暴露服务通过域名访问也是可以的,下面我们来部署操作下。

# 创建LB负载到集群中

![upload-image](/assets/images/blog/treafik2/1.png) 

![upload-image](/assets/images/blog/treafik2/2.png) 

![upload-image](/assets/images/blog/treafik2/3.png) 

网络类型选择公网，域名需要解析到公网ip

网络选择私有网络，集群所在的vpc

![upload-image](/assets/images/blog/treafik2/4.png)

在你购买的域名中解析到该VIP上，我这边是解析了*.tx.niewx.ciub

![upload-image](/assets/images/blog/treafik2/5.png) 

添加监听器

![upload-image](/assets/images/blog/treafik2/6.png) 

![upload-image](/assets/images/blog/treafik2/7.png) 

![upload-image](/assets/images/blog/treafik2/8.png) 

![upload-image](/assets/images/blog/treafik2/9.png) 

![upload-image](/assets/images/blog/treafik2/10.png) 

绑定后端服务器，我们这里绑定的端口为30183,这个端口是k8s集群暴露treafik2的服务端口

# 创建treafik命名空间来部署服务

![upload-image](/assets/images/blog/treafik2/11.png) 

![upload-image](/assets/images/blog/treafik2/12.png) 

# 部署treafik服务

以下部署，如果在TKE的控制台无法部署yaml，可以通过kubectl来部署对应的yaml文件

## 首先自定义资源类型

```
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressroutes.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRoute
    plural: ingressroutes
    singular: ingressroute
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressroutetcps.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRouteTCP
    plural: ingressroutetcps
    singular: ingressroutetcp
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: middlewares.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: Middleware
    plural: middlewares
    singular: middleware
  scope: Namespaced

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: tlsoptions.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TLSOption
    plural: tlsoptions
    singular: tlsoption
  scope: Namespaced
```

## 配置rbac权限

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: treafik
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses/status
    verbs:
      - update
  - apiGroups:
      - traefik.containo.us
    resources:
      - middlewares
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - traefik.containo.us
    resources:
      - ingressroutes
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - traefik.containo.us
    resources:
      - ingressroutetcps
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - traefik.containo.us
    resources:
      - tlsoptions
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: treafik
```

## 部署treafik

```
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: traefik
  namespace: treafik
  labels:
    k8s-app: traefik-ingress-lb
spec:
  selector:
    matchLabels:
      k8s-app: traefik-ingress-lb
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-lb
        name: traefik-ingress-lb
    spec:
      serviceAccountName: traefik-ingress-controller
      containers:
      - image: traefik:v2.0
        name: traefik-ingress-lb
        ports:
        - name: web
          containerPort: 80
          hostPort: 80
        - name: websecure
          containerPort: 443
          hostPort: 443
        - name: admin
          containerPort: 8080
        args:
        - --entrypoints.web.Address=:80
        - --entrypoints.websecure.Address=:443
        - --api.insecure=true
        - --providers.kubernetescrd
        - --api
        - --api.dashboard=true
        - --accesslog

---

kind: Service
apiVersion: v1
metadata:
  name: traefik
  namespace: treafik
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
    - protocol: TCP
      port: 8080
      name: admin
  type: NodePort
```

## 配置域名规则

```
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-webui
  namespace: treafik
spec:
  entryPoints:
    - web
  routes:
  - match: Host(`traefik2.tx.niewx.club`)
    kind: Rule
    services:
    - name: traefik
      port: 8080

---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: prometheus-webui
  namespace: kube-ops
spec:
  entryPoints:
    - web
  routes:
  - match: Host(`prometheus.tx.niewx.club`)
    kind: Rule
    services:
    - name: prometheus
      port: 9090

---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: grafana-webui
  namespace: kube-ops
spec:
  entryPoints:
    - web
  routes:
  - match: Host(`grafana.tx.niewx.club`)
    kind: Rule
    services:
    - name: grafana
      port: 3000
```

这里我们暴露我们之前已经部署好的服务。

## 添加treafik服务端口

因为之前的svc只暴露了8080,我们需要暴露treafik的80和443端口，这样lb才能负载到对应的服务上

![upload-image](/assets/images/blog/treafik2/13.png) 

我们直接在treafik的svc上添加2条映射即可，也可以在最开始的yaml中直接设置好。

# 通过域名访问集群服务

![upload-image](/assets/images/blog/treafik2/14.png) 

![upload-image](/assets/images/blog/treafik2/15.png) 

# 设置treafik的basic auth认证

有的时候我们的服务自身没有设置鉴权，任何人可以直接登录界面，这样是不安全的，treafik2提供的中间来解决这个问题，我们一般访问treafik界面是不需要密码的，下面我们给treafik来设置一个访问账号密码

## 采用htpasswd创建文件
```
htpasswd -bc auth admin admin
```

## 创建secret
```
kubectl create secret generic nginx-basic-auth --from-file=auth -n treafik
```

## 定义Basic Auth中间件
```
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: secured
  namespace: treafik
spec:
  chain:
    middlewares:
    - name: auth-users

---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: auth-users
  namespace: treafik
spec:
  basicAuth:
    secret: nginx-basic-auth # 兼容 K8S secrets 对象
```

## Ingress中应用中间件

```
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-webui
  namespace: treafik
spec:
  entryPoints:
    - web
  routes:
  - match: Host(`traefik2.tx.niewx.club`)
    kind: Rule
    services:
    - name: traefik
      port: 8080
    middlewares:
      - name: secured
```

## 通过域名访问需要登录才行

![upload-image](/assets/images/blog/treafik2/16.png) 

![upload-image](/assets/images/blog/treafik2/17.png)
