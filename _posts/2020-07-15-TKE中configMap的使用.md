---
title: TKE中configMap的使用
author: VashonNie
date: 2020-07-15 14:10:00 +0800
updated: 2020-07-15 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [Kubernetes,TKE,configMap]
math: true
---

本篇文章主要介绍了如何在tke集群中挂载configMap到pod中。


一般我们使用configMap主要用途分为2种，一种是挂载configmap中的配置文件进容器里，一种是引用configMap中的键值对作为容器的环境变量。

我们这里测试之前创建了3个测试文件，测试镜像为nginx最新镜像

# 测试文件
## nginx.conf

在配置文件中加入了一行测试注释 #test line，方便我们后续进行验证

```
apiVersion: v1
data:
  nginx.conf: |2-
    user  nginx;
    worker_processes  1;
    # test line
    error_log  /var/log/nginx/error.log warn;
    pid        /var/run/nginx.pid;
    events {
        worker_connections  1024;
    }
    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;

        log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" '
                          '"$http_user_agent" "$http_x_forwarded_for"';

        access_log  /var/log/nginx/access.log  main;

        sendfile        on;
        #tcp_nopush     on;

        keepalive_timeout  65;

        #gzip  on;

        include /etc/nginx/conf.d/*.conf;
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2020-06-02T09:19:45Z"
  name: nginx-conf
  namespace: test
  resourceVersion: "10479370942"
  selfLink: /api/v1/namespaces/test/configmaps/nginx-conf
  uid: 32ca67ac-a4b2-11ea-9c35-e28957d7d0b3
```

## nginx-env

nginx-env用来测试环境变量的引用

```
apiVersion: v1
data:
  RUNTIME: nginx-test
  TZ: Asia/Shanghai
kind: ConfigMap
metadata:
  creationTimestamp: "2020-06-02T09:31:26Z"
  name: nginx-env
  namespace: test
  resourceVersion: "8584098360"
  selfLink: /api/v1/namespaces/test/configmaps/nginx-env
  uid: d4e69d1a-a4b3-11ea-9c35-e28957d7d0b3
```

## test.txt

```
apiVersion: v1
data:
  test.txt: '"\tmap $http_upgrade $connection_upgrade {\n\t    default upgrade;\n\t    ''''
    close;\n\t}"'
kind: ConfigMap
metadata:
  creationTimestamp: "2020-07-13T10:33:50Z"
  name: test
  namespace: test
  resourceVersion: "10478782044"
  selfLink: /api/v1/namespaces/test/configmaps/test
  uid: 95a40fc5-7e5b-4af1-892d-b3ed3d6ebee9
```

# 如何挂载配置文件到容器内

我们一般挂载文件到容器内分为多种情况：

* 替换容器内已经存在的某个配置文件
* 替换容器内不存在的配置文件
* 替换容器内的某个目录下所有文件

![upload-image](/assets/images/blog/configMap/1.png) 

对应的yaml文件如下

```
        volumeMounts:
        - mountPath: /etc/nginx/test.txt
          name: conf
        - mountPath: /etc/nginx/nginx.conf
          name: nginx
          subPath: nginx.conf
        - mountPath: /etc/nginx/conf.d/
          name: conf
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
      - configMap:
          defaultMode: 420
          name: test
        name: conf
      - configMap:
          defaultMode: 420
          name: nginx-conf
        name: nginx
```

# 如何引用configMap的值作为环境变量

![upload-image](/assets/images/blog/configMap/2.png) 

yaml文件如下

```
spec:
      containers:
      - env:
        - name: RUNTIME
          valueFrom:
            configMapKeyRef:
              key: RUNTIME
              name: nginx-env
              optional: false
        - name: TZ
          valueFrom:
            configMapKeyRef:
              key: TZ
              name: nginx-env
              optional: false
```

