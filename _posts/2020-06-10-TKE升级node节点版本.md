---
title: TKE升级node节点版本
author: VashonNie
date: 2020-06-10 14:10:00 +0800
updated: 2020-06-10 14:10:00 +0800
categories: [TKE,腾讯云]
tags: [Kubernetes,Docker,TKE]
math: true
---

该文章介绍了在TKE中如何给集群节点升级版本。

# TKE节点升级方式

## 驱逐节点pod升级节点方式

![upload-image](/assets/images/blog/node-update/1.png) 

找到对应的节点，点击驱逐，驱逐完毕后，点击集群信息升级


![upload-image](/assets/images/blog/node-update/2.png) 

![upload-image](/assets/images/blog/node-update/3.png) 

![upload-image](/assets/images/blog/node-update/4.png) 

![upload-image](/assets/images/blog/node-update/5.png) 

信息配置完成后点击完成，等待10分钟即可升级完成。

## 将节点对应的pod副本设置大于1

![upload-image](/assets/images/blog/node-update/6.png) 

![upload-image](/assets/images/blog/node-update/7.png)

先将对应节点上的pod副本都设置大于2，因为升级时候会销毁pod，可以会导致服务不可用，设置pod副本为多个，可以保证服务不会中断。设置完之后，再执行上述升级节点步骤即可。