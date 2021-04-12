---
title: Traefik1.7.17的部署使用
author: VashonNie
date: 2020-07-12 14:10:00 +0800
updated: 2020-07-12 14:10:00 +0800
categories: [Kubernetes,Docker]
tags: [Kubernetes,Docker,Treafik1.7]
math: true
---

本篇文章介绍了在k8s上treafik1.7的搭建和使用。

因为我这里是作为kubernetes服务的暴露，因此你得有一个kubernetes集群

集群准备好了，需要下面的配置文件

# 部署rbac文件

rbac文件让ingress获取对应命名空间的权限

```
[root@master traefik]# cat ingress-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ingress
  namespace: kube-system
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: ingress
subjects:
  - kind: ServiceAccount
    name: ingress
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

# 部署traefik应用

这里部署应用中包含了https服务，因此需要在对应的节点上生成证书进行认证

首先openssl命令生成 CA 证书

```
$ openssl req -newkey rsa:2048 -nodes -keyout tls.key -x509 -days 365 -out tls.crt
```

现在我们有了证书，我们可以使用 kubectl 创建一个 secret 对象来存储上面的证书

```
$ kubectl create secret generic traefik-cert --from-file=tls.crt --from-file=tls.key -n kube-system
```

现在我们来配置 Traefik，让其支持 https，新建traefik.toml文件

```
[root@master https]# cat traefik.toml
defaultEntryPoints = ["http", "https"]
[entryPoints]
[entryPoints.http]
address = ":80"
[entryPoints.http.redirect]
entryPoint = "https"
[entryPoints.https]
address = ":443"
[entryPoints.https.tls]
  [[entryPoints.https.tls.certificates]]
  CertFile = "/ssl/tls.crt"
  KeyFile = "/ssl/tls.key"

然后通过cm挂载进pod里面，让pod能够访问该配置文件
```

然后通过cm挂载进pod里面，让pod能够访问该配置文件

```
$ kubectl create configmap traefik-conf --from-file=traefik.toml -n kube-system
```

最后部署我们的对应的traefik应用

```
[root@master traefik]# cat traefik.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: traefik-ingress-lb
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress-lb
spec:
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-lb
        name: traefik-ingress-lb
    spec:
      terminationGracePeriodSeconds: 60
      hostNetwork: true
      restartPolicy: Always
      serviceAccountName: ingress
      containers:
      - image: traefik:v1.7.17
        name: traefik-ingress-lb
        volumeMounts:
        - mountPath: "/ssl"
          name: "ssl"
        - mountPath: "/config"
          name: "config"
        resources:
          limits:
            cpu: 200m
            memory: 30Mi
          requests:
            cpu: 100m
            memory: 20Mi
        ports:
        - name: http
          containerPort: 80
          hostPort: 80
        - name: https
          containerPort: 443
          hostPort: 443
        - name: admin
          containerPort: 8580
          hostPort: 8580
        args:
        - --web
        - --web.address=:8580
        - --kubernetes
        - --configfile=/config/traefik.toml
      volumes:
      - name: ssl
        secret:
          secretName: traefik-cert
      - name: config
        configMap:
          name: traefik-conf
```

# 部署traefik的service

```
[root@master traefik]# cat traefik-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik-web-ui
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
  - name: web
    port: 80
    targetPort: 8580
  - protocol: TCP
    port: 443
    name: https
  type: NodePort
```

# 给trarfik部署一个路由

```
[root@master traefik]# cat ingress-route.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-web-ui
  namespace: kube-system
spec:
  rules:
  - host: traefik.k8s.niewx.club #配置ui的域名
    http:
      paths:
      - path: /
        backend:
          serviceName: traefik-web-ui
          servicePort: web
```

# ingress 中 path 的用法

部署nginx测试服务测试ingress 中 path 的用法

```
[root@master traefik]# cat test.yaml
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: svc1
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: svc1
    spec:
      containers:
      - name: svc1
        image: cnych/example-web-service
        env:
        - name: APP_SVC
          value: svc1
        ports:
        - containerPort: 8080
          protocol: TCP

---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: svc2
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: svc2
    spec:
      containers:
      - name: svc2
        image: cnych/example-web-service
        env:
        - name: APP_SVC
          value: svc2
        ports:
        - containerPort: 8080
          protocol: TCP

---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: svc3
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: svc3
    spec:
      containers:
      - name: svc3
        image: cnych/example-web-service
        env:
        - name: APP_SVC
          value: svc3
        ports:
        - containerPort: 8080
          protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  labels:
    app: svc1
  name: svc1
spec:
  type: ClusterIP
  ports:
  - port: 8080
    name: http
  selector:
    app: svc1
---
kind: Service
apiVersion: v1
metadata:
  labels:
    app: svc2
  name: svc2
spec:
  type: ClusterIP
  ports:
  - port: 8080
    name: http
  selector:
    app: svc2
---
kind: Service
apiVersion: v1
metadata:
  labels:
    app: svc3
  name: svc3
spec:
  type: ClusterIP
  ports:
  - port: 8080
    name: http
  selector:
    app: svc3
```

设置不同的同一个路由不同的路由访问对应的nginx服务

```
[root@master traefik]# cat test-ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-test
spec:
  rules:
  - host: test.k8s.niewx.club #配置ui的域名
    http:
      paths:
      - path: /s1
        backend:
          serviceName: svc1
          servicePort: 8080
      - path: /s2
        backend:
          serviceName: svc2
          servicePort: 8080
      - path: /
        backend:
          serviceName: svc3
          servicePort: 8080
```

# 部署结果

![upload-image](/assets/images/blog/treafil1.7/1.png) 

# 基于traefik的Basic auth认证

首先采用htpasswd创建文件

```
htpasswd -bc auth admin admin
```

基于上面的htpasswd创建secret(注意命名空间)

```
kubectl create secret generic nginx-basic-auth --from-file=auth -n kube-system
```

treafik引用对应的secret进行认证（注意如下）

* Secret文件必须与Ingress规则在同一命名空间。
* 目前只支持basic authentication。
* Realm不可配置，默认使用traefik。
* Secret必须只包含一个文件。

引用secret的yaml配置

```
[root@master traefik]# cat test-ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-test
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: traefik
    # 认证类型
    ingress.kubernetes.io/auth-type: basic
    # 包含 user/password 的 Secret 名称
    ingress.kubernetes.io/auth-secret: nginx-basic-auth
    # 当认证的时候显示一个合适的上下文信息
    #ingress.kubernetes.io/auth-realm: 'Authentication Required - admin'
spec:
  rules:
  - host: test.k8s.niewx.club #配置ui的域名
    http:
      paths:
      - path: /s1
        backend:
          serviceName: svc1
          servicePort: 8080
      - path: /s2
        backend:
          serviceName: svc2
          servicePort: 8080
      - path: /
        backend:
          serviceName: svc3
          servicePort: 8080
```

# 解析域名到k8s集群中

一般暴露服务到外部都是提供域名访问，我们这边的集群节点通过lb来负载均衡，将域名解析到对应的lb上，后端监听的服务为treafik的80端口即可，这样treafik可以使用你所绑定解析的域名