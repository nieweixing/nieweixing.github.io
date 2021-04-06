---
title: kubewatch监控k8s集群资源变更
author: VashonNie
date: 2020-11-01 14:10:00 +0800
updated: 2020-11-01 14:10:00 +0800
categories: [Kubernetes,Monitor]
tags: [Kubernetes]
math: true
---

这次要介绍一个 Kubernetes 资源观测工具，实时监控 Kubernetes 集群中各种资源的新建、更新和删除，并实时通知到各种协作软件/聊天软件，目前支持的通知渠道有：

* slack
* hipchat
* mattermost
* flock
* webhook

本次实验环境采用的是腾讯云上TKE托管集群，通知发生采用的是发送到slack上。

# 申请slack账号

这边首先申请一个个人slack账号，申请后创建一个app，并且创建一个告警channel将app关联上去

## 创建slack账号

通过企业邮箱去页面 https://slack.com/get-started#/create 创建你的slack命名空间，这里根据提示填写邮箱信息即可。

![upload-image](/assets/images/blog/kubewatch/0.png) 

## 创建APP

通过页面 https://api.slack.com/apps 点击创建New App

![upload-image](/assets/images/blog/kubewatch/1.png) 

填写你的APP Name和你的workspace，我这里之前创建一个kubewatch的app

![upload-image](/assets/images/blog/kubewatch/2.png) 

给APP申请权限，这边点击0Auth

![upload-image](/assets/images/blog/kubewatch/3.png) 

点击添加权限按钮给APP添加权限，这边注意最后给admin的token权限

![upload-image](/assets/images/blog/kubewatch/4.png) 

## 安装APP

添加完权限后，点击安装APP按钮安装到你的workspaces

![upload-image](/assets/images/blog/kubewatch/5.png) 

安装完成后，复制保存APP的token。这里后续需要用到，配置到kubewatch的配置文件中。

![upload-image](/assets/images/blog/kubewatch/6.png) 

## 创建channel关联APP接收信息

这里我们创建一个test的channel来接受kubewatch发送的信息

![upload-image](/assets/images/blog/kubewatch/7.png) 

点击Connect an app将kubewatch app关联到test channel

![upload-image](/assets/images/blog/kubewatch/8.png) 

关联成功后，后续消息将会发生到test channel中

![upload-image](/assets/images/blog/kubewatch/9.png) 

# 部署kubewatch到k8s集群中

## 腾讯云控制台部署到TKE集群

点击容器服务的应用页面，选择你的集群，点击新建

![upload-image](/assets/images/blog/kubewatch/9--10.png) 

填写你的应用名，所部属的命名空间，选择kubewatch应用，修改value.yaml

![upload-image](/assets/images/blog/kubewatch/10.png) 

修改enabled为ture，channel为之前接收消息的channel，我这里是test，将之前APP的token填写到token配置项

![upload-image](/assets/images/blog/kubewatch/11.png) 

## helm命令部署到集群中

通过helm客户端执行命令部署kubewatch，如何安装使用helm可以参考https://cloud.tencent.com/developer/article/1696689

```
[root@VM-6-17-centos ~]# helm repo add bitnami https://charts.bitnami.com/bitnami
[root@VM-6-17-centos ~]# helm fetch bitnami/kubewatch
[root@VM-6-17-centos ~]# tar -xvf kubewatch-1.2.6.tgz
[root@VM-6-17-centos ~]# cd kubewatch/
[root@VM-6-17-centos ~]# vi values.yaml
[root@VM-6-17-centos ~]# helm install ./kubewatch --namespace kubewatch --name nwx-kubewatch
```

这里vi修改一下values.yam文件如下,修改enabled为ture，channel为之前接收消息的channel，我这里是test，将之前APP的token填写到token配置项

![upload-image](/assets/images/blog/kubewatch/11--12.png) 

查看pod日志，检查服务是否允许，这边pod出现如下日志，则表示接入slack成功

![upload-image](/assets/images/blog/kubewatch/12.png) 

# k8s集群资源变更测试

下面我们尝试重建一个pod，看下slack是否会接收到变更信息，我们在test下部署一个busybox的pod

![upload-image](/assets/images/blog/kubewatch/13.png) 

从下图可以发现，slack有接收到变更的信息，说明我们已经成功部署kubewatch监控k8s集群并接入到slack

![upload-image](/assets/images/blog/kubewatch/14.png) 



