---
title: k8s中如何控制pod中容器的启动顺序
author: VashonNie
date: 2020-12-25 14:10:00 +0800
updated: 2020-12-25 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes,Docker]
math: true
---

我们在部署服务的时候，通常会遇到这种场景就是2个服务部署在同一个pod中，但是这2个服务又有先后的依赖关系，那么我们如何在pod中如何来控制容器的启动顺序呢？今天我们来讲一下如何在pod如何控制2个容器的启动顺序，我们在这里在一个pod里面部署springboot和centos的2个容器作为示例，centos的启动需要依赖于springboot的服务启动正常再启动。

正常我们在一个pod中部署2个容器，启动的顺序都是随机的，其实我们在这里设置启动顺序就是通过脚本来判读springboot服务是否启动，如果启动了我再启动centos。

```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: container-start-order
    qcloud-app: container-start-order
  name: container-start-order
  namespace: test
spec:
  progressDeadlineSeconds: 600
  replicas: 0
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: container-start-order
      qcloud-app: container-start-order
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        k8s-app: container-start-order
        qcloud-app: container-start-order
    spec:
      containers:
      - args:
        - while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:8080)" != '200' ]]; do echo Waiting for springboot;sleep 5; done; echo springboot available; top -b
        command:
        - /bin/bash
        - -c
        image: centos:7
        imagePullPolicy: Always
        name: centos
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 250m
            memory: 256Mi
        securityContext:
          privileged: false
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      - image: nwx-test.tencentcloudcr.com/nwx/springboot:springboot-4801f1daf265728c1061f2fa0ff20b1eeedb9416
        imagePullPolicy: Always
        name: springboot
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 250m
            memory: 256Mi
        securityContext:
          privileged: false
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      imagePullSecrets:
      - name: tcr.ipstcr-erzjx59w-public
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
```

我们在centos中设置依赖的启动命令，下面这条命令的意思是我们在centos中每隔5s去curl springboot的服务，如果正常启动，则启动centos，启动命令是top -b，如果是您的服务镜像这个设置成你自己的服务启动命令

```
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:8080)" != '200' ]]; do echo Waiting for springboot;sleep 5; done; echo springboot available; top -b
```

下面我们启动pod，看看是否会达到我们预期目标，centos依赖springboot的服务启动后再启动

![upload-image](/assets/images/blog/container-start-order/1.png) 

![upload-image](/assets/images/blog/container-start-order/2.png) 

![upload-image](/assets/images/blog/container-start-order/3.png) 

从事件和容器启动日志的时间，我们可以发现springboot是在6:41 56毫秒才访问成功，查看centos的日志可以发现，6:41 56毫秒前每隔5s探测一次springboot服务是否启动成功，到了6:41 56毫秒返回200后则执行top -b启动centos。