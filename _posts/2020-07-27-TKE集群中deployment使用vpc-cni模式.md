---
title: TKE集群中deployment使用vpc-cni模式
author: VashonNie
date: 2020-07-27 14:10:00 +0800
updated: 2020-07-27 14:10:00 +0800
categories: [TKE,Kubernetes]
tags: [Kubernetes,TKE]
math: true
---

TKE集群中的网络模式分为Global Router和vpc-cni这2种，有的集群是创建的时候使用Global Router的网络模式，但是后续开启了vpc-cni的网络模式，因为集群是可以同时兼容2种网络模式。

在使用vpc-cni的网络模式大家会有一个疑惑，就是为什么我开启了vpc-cni模式后，创建的工作负载中的pod ip没有在我配置的子网中，没有和vpc在一个网段。

其实并不是开启了vpc-cni模式后，创建新的pod或者重建pod就会选择vpc-cni模式，除非你在创建集群的时候就选择的vpc-cni模式，那样创建出来的所有pod分配的ip都会和vpc在一个网段。其实在tke集群中有一个参数来控制你的pod是否选择vpc-cni模式，下面我们来说说如何使用这个参数，不同类型的工作负载如何选择vpc-cni模式。

# StatefulSet如何选择vpc-cni模式

一般我们创建StatefulSet的时候是可以在控制台选择是否选择vpc-cni模式，使用方法如下，在创建StatefulSet时候选择高级选项，点击是否选择vpc-cni模式即可，StatefulSet还可以选择是否配置固定ip模式

![upload-image](/assets/images/blog/cni-1/1.png) 

![upload-image](/assets/images/blog/cni-1/2.png) 

![upload-image](/assets/images/blog/cni-1/3.png) 

# deployement如何选择vpc-cni模式

我们在创建deployment的时候在控制台是没有对应的选项来选择是否采用vpc-cni模式的，但是并不是说我们无法创建deployment的pod选择vpc-cni模式。我们可以在yaml中添加参数 tke.cloud.tencent.com/networks: tke-route-eni 即可，下面我们来实验一下

首先我们创建一个不配置这个参数的pod，我们在控制台是没有vpc-cni选择项的

![upload-image](/assets/images/blog/cni-1/4.png) 

我们创建完之后发现pod和节点不在一个网段，对应的yaml中没有tke.cloud.tencent.com/networks: tke-route-eni这个字段

![upload-image](/assets/images/blog/cni-1/5.png) 

![upload-image](/assets/images/blog/cni-1/6.png) 

下面我们修改yaml，加上这个字段再更新pod，我们发现pod和节点处在同一个网段中，

![upload-image](/assets/images/blog/cni-1/7.png) 

![upload-image](/assets/images/blog/cni-1/8.png)

所以，如果我们需要在deployment中使用vpc-cni模式只需要在yaml中加上tke.cloud.tencent.com/networks: tke-route-eni这个字段更新pod即可。

