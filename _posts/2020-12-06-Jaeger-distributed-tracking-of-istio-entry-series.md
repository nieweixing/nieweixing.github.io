---
title: istio入门系列之Jaeger分布式追踪
author: VashonNie
date: 2020-12-06 10:10:00 +0800
updated: 2020-12-06 10:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes,Jaeger]
math: true
---

分布式追踪可以让用户对跨多个分布式服务网格的 1 个请求进行追踪分析。这样进而可以通过可视化的方式更加深入地了解请求的延迟，序列化和并行度。

Istio 利用 Envoy 的分布式追踪功能提供了开箱即用的追踪集成。确切地说，Istio 提供了安装各种各种追踪后端服务的选项，并且通过配置代理来自动发送追踪 span 到追踪后端服务。

下面了解如何让您的应用程序参与 Jaeger 的追踪， 而不管您用来构建应用程序的语言、框架或平台是什么。

![upload-image](/assets/images/blog/istio-jaeger/1.png) 

使用demo方式安装的istio，默认会安装jaeger到集群中，使用jaeger默认需要打开tracing，如果没有打开则需要执行下面命令

```
--set values.tracing.enabled=true
--set values.global.tracer.zipkin.address = <jaeger-collector-service>.<jaeger-collector-namespace>:9411
```

下面我们进入jaeger界面看看

```
[root@VM-0-3-centos ~]# kubectl get svc -n istio-system | grep jaeger-query
jaeger-query                NodePort       172.16.54.199    <none>           16686:31110TCP       11d
```

浏览器输入http://节点ip:31110，然后就可以查看到jaeger基本页面

![upload-image](/assets/images/blog/istio-jaeger/2.png) 

我们看一下bookinfo的首页转发到后端details服务的一个链路

![upload-image](/assets/images/blog/istio-jaeger/3.png) 

点击一个链路进去查看每个服务对应的响应时长

![upload-image](/assets/images/blog/istio-jaeger/4.png) 

还可以点击具体的响应信息

![upload-image](/assets/images/blog/istio-jaeger/5.png)

jaeger还支持图形方式展示调用的链路

![upload-image](/assets/images/blog/istio-jaeger/6.png) 