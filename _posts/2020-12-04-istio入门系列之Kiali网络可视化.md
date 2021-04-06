---
title: istio入门系列之Kiali网络可视化
author: VashonNie
date: 2020-12-04 10:10:00 +0800
updated: 2020-12-04 10:10:00 +0800
categories: [Istio]
tags: [Istio,Kubernetes,Kiali]
math: true
---

Kiali组件，使用基于 Web 的图形用户界面来查看网格和 Istio 配置对象的服务图。 使用 Kiali Public API 返回的 JSON 数据生成图形数据。

Kiali拥有如下的功能

![upload-image](/assets/images/blog/istio-Kiali/1.png) 

Kiali的架构如下

![upload-image](/assets/images/blog/istio-Kiali/2.png) 

istio中的组件web界面命令行打开方式

```
[root@VM-0-13-centos treafik]# istioctl dashboard
Access to Istio web UIs

Usage:
  istioctl dashboard [flags]
  istioctl dashboard [command]

Aliases:
  dashboard, dash, d

Available Commands:
  controlz    Open ControlZ web UI
  envoy       Open Envoy admin web UI
  grafana     Open Grafana web UI
  jaeger      Open Jaeger web UI
  kiali       Open Kiali web UI
  prometheus  Open Prometheus web UI
  zipkin      Open Zipkin web UI

```

进入web界面，我们可以在Application中查看应用情况

![upload-image](/assets/images/blog/istio-Kiali/3.png) 

可以到Graph中查看对应服务的调用拓扑图

![upload-image](/assets/images/blog/istio-Kiali/4.png) 

可以在service中查看对应的service情况和所配置的VirtualService和DestinationRule

![upload-image](/assets/images/blog/istio-Kiali/5.png) 

我们还可以在service中查看对应服务的访问情况

![upload-image](/assets/images/blog/istio-Kiali/6.png) 

![upload-image](/assets/images/blog/istio-Kiali/7.png) 

我们还可以对istio的配置进行检查，我们在istio config页面对istio的配置进行检查修改，查看到有红色感叹号的说明配置异常，点击进去看

![upload-image](/assets/images/blog/istio-Kiali/8.png) 

我们按照提示修改后然后保存重新加载即可

![upload-image](/assets/images/blog/istio-Kiali/9.png) 

![upload-image](/assets/images/blog/istio-Kiali/10.png) 

这里修改后，这个DestinationRule显示正常

删除kiali的方式，可以执行如下命令

```
kubectl delete all,secrets,sa,configmaps,deployments,ingresses,clusterroles,clusterrolebindings,customresourcedefinitions --selector=app=kiali -n istio-system
```
