---
title: TKE中使用lb直连获取客户端真实IP
author: VashonNie
date: 2020-07-28 14:10:00 +0800
updated: 2020-07-28 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [Kubernetes,TKE,Service]
math: true
---

我们在使用TKE的过程中会遇到一个这样的场景，就是我在服务端想获取到有哪些客户端在访问我，并且获取到客户端的真实ip。但是在k8s集群中经过多次的网络的转发，一般是无法获取到客户端真实ip。

为了满足这个常见TKE这边提供了lb直连pod的方式来获取客户端真实的ip，其实tke中能够实现这个方案的主要还是基于在vpc-cni的网络模式下实现的，因为vpc-cni模式可以使pod处于和node节点，vpc同一个网络下，而lb也是在vpc的网络中，因此这边lb就可以直接将请求转发到pod上，下面我们来说一下如何在tke中使用这种模式。

这边还是分为2种类型的工作负载来进行实践操作。

# Deployment使用lb直连

一般我们创建deploy类型的pod，关联创建svc的时候是无法选择直连lb的类型的，因为这边直连需要pod选择vpc-cni网络模式才可以，我们这边先手动创建一个正常的deployement，再去手动修改svc和pod的网络模式即可

我们这里在控制台创建了一个pod

![upload-image](/assets/images/blog/clb/1.png)

我们可以测试一下非直连的pod，通过10.168.1.5这个机器上发起访问，发现pod日志并没有对应的客户端ip信息

![upload-image](/assets/images/blog/clb/2.png) 

![upload-image](/assets/images/blog/clb/3.png) 

下面修改对应的svc类型为直连模式，勾选这个采用负载均衡直连pod的模式

![upload-image](/assets/images/blog/clb/4.png) 


修改下对应的pod为vpc-cni网络模式，在pod中加上参数
```
annotations:
        tke.cloud.tencent.com/networks: tke-route-eni
```

![upload-image](/assets/images/blog/clb/5.png) 

![upload-image](/assets/images/blog/clb/6.png) 

现在pod的网络模式已经是vpc-cni了，并且svc也是直连了，下面我们来访问下，看日志能否看到client的ip

![upload-image](/assets/images/blog/clb/7.png) 

![upload-image](/assets/images/blog/clb/8.png) 

经过测试是可以获取到客户端的ip的。

# StatefulSet使用lb直连

StatefulSet因为支持在界面创建vpc-cni的网路模式，所以我们只需要在控制台配置就行。

我们不选择vpc-cni模式是没有lb直连选项的

![upload-image](/assets/images/blog/clb/9.png) 

勾选了vpc-cni模式才会出现lb直连选项，所以我们需要在创建的时候选择vpc-cni，并选择lb直连

![upload-image](/assets/images/blog/clb/10.png) 

下面我们来测试下创建好的sts的直连nginx服务

![upload-image](/assets/images/blog/clb/11.png) 

![upload-image](/assets/images/blog/clb/12.png) 

![upload-image](/assets/images/blog/clb/13.png)

经过测试，这这边创建好的sts类型的nginx的pod也可以获取到客户端的真实ip
