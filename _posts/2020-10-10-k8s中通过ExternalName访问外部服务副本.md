---
title: k8s中通过ExternalName访问外部服务
author: VashonNie
date: 2020-10-10 14:10:00 +0800
updated: 2020-10-10 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes]
math: true
---

本文主要介绍了ExternalName类型的service在k8s中的使用。·

## ExternalName访问外部服务

其实我们很多服务都是在在aws上，比如mysql和redis等数据库服务，如果我们代码中想要访问这些服务，那应该怎么访问，我们的代码服务是运行在pod中的，也就是相当于我们的k8s集群中的pod需要访问aws上的mysql或者redis等服务。
其实我们只需要提供一个ExternalName的servcie对外部服务进行映射就可以了，我们创建好这样service，然后通过service name就能直接访问到aws上提供的mysql服务。
```
---
kind: Service
apiVersion: v1
metadata:
  name: mysql-5-7-01-service
spec:
  type: ExternalName
  externalName: ai-production-mysql-bot.cfyipcsxzevb.rds.cn-northwest-1.amazonaws.com.cn
---
```
我们可以通过mysql-5-7-01-service这样一个servcie来访问aws的mysql数据库


## Endpoint访问外部服务
ExternalName只在kubedns中能够解析，在coredns中无法解析，如果集群中采用的coredns，则需要修改成endpoint的方式
```
---
kind: Service
apiVersion: v1
metadata:
  name: elasticsearch-2-4-0-01-service
spec:
  clusterIP: None
---
kind: Endpoints
apiVersion: v1
metadata:
  name: elasticsearch-2-4-0-01-service
subsets:
  - addresses:
      - ip: 10.42.94.157
```

## 参考链接
<https://blog.csdn.net/Juwenzhe_HEBUT/article/details/89577459>
