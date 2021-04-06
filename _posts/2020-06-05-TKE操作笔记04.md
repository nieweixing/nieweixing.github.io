---
title: TKE操作笔记04
author: VashonNie
date: 2020-06-05 14:10:00 +0800
updated: 2020-06-05 14:10:00 +0800
categories: [TKE,腾讯云]
tags: [Kubernetes,Docker,TKE]
math: true
---

本周讲述了在TKE上如何监控集群并发送告警，简单部署wordpress到集群中

# TKE监控使用和查看

良好的监控环境为腾讯云容器服务高可靠性、高可用性和高性能提供重要保证。您可以方便为不同资源收集不同维度的监控数据，能方便掌握资源的使用状况，轻松定位故障。 腾讯云容器服务提供集群、节点、工作负载、Pod、Container 5个层面的监控数据收集和展示功能。 收集监控数据有助于您建立容器集群性能的正常标准。通过在不同时间、不同负载条件下测量容集群的性能并收集历史监控数据，您可以较为清楚的了解容器集群和服务运行时的正常性能，并能快速根据当前监控数据判断服务运行时是否处于异常状态，及时找出解决问题的方法。例如，您可以监控服务的 CPU 利用率、内存使用率和磁盘 I/O

## 集群整体监控

![upload-image](/assets/images/blog/tke04/1.png) 

![upload-image](/assets/images/blog/tke04/2.png) 

可以选择不同的时间段，时间间隔等选项来查看对应的指标数据

## 节点监控

![upload-image](/assets/images/blog/tke04/3.png) 

![upload-image](/assets/images/blog/tke04/4.png) 

我们可以查看某一个节点或者所有节点的监控指标，根据其他选项来选择数据的时间段和类型

## pod监控

![upload-image](/assets/images/blog/tke04/5.png) 

![upload-image](/assets/images/blog/tke04/6.png) 

我们要选择pod所在的节点，然后再进行其他选择来查看某个pod或者所有pod的监控指标数据

## deployment监控

![upload-image](/assets/images/blog/tke04/7.png) 

![upload-image](/assets/images/blog/tke04/8.png) 

可以选择所有负载或者某一个负载不同时间段的监控数据

## 查看某个deployment中具体pod的监控

![upload-image](/assets/images/blog/tke04/9.png) 

![upload-image](/assets/images/blog/tke04/10.png) 

![upload-image](/assets/images/blog/tke04/11.png) 

## 查看pod内某个容器的指标

![upload-image](/assets/images/blog/tke04/12.png) 

单击【Container】，将【所属 Pod】选择为您想查看的 Pod，即可查看该 Pod 内 Container 的监控指标对比图

# helm的安装和使用
## helm的安装
### helm服务端的安装

![upload-image](/assets/images/blog/tke04/13.png) 

找到扩展插件，选择你的集群，选择helm，点击安装到你的集群中即可

### helm客户端的安装

在你配置了集群的访问凭证下执行如下操作

```
curl -O https://storage.googleapis.com/kubernetes-helm/helm-v2.10.0-linux-amd64.tar.gz
tar xzvf helm-v2.10.0-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/helm
```
能够正确查询到版本则成功
```
[root@VM_0_13_centos ~]# helm version
Client: &version.Version{SemVer:"v2.10.0", GitCommit:"9ad53aac42165a5fadc6c87be0dea6b115f93090", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.10.0", GitCommit:"9ad53aac42165a5fadc6c87be0dea6b115f93090", GitTreeState:"clean"}
```
配置 Helm 为 Client-only

执行以下命令，将 Helm 配置为 Client-only。
```
helm init --client-only
```
## helm的使用
### helm仓库
```
[root@VM_0_13_centos ~]# helm repo list
NAME    URL
stable  https://kubernetes-charts.storage.googleapis.com
local   http://127.0.0.1:8879/charts
```
一般默认的远程仓库为google的，下载应用比较慢，我们可以设置为阿里的。
客户端命令设置如下
```
[root@VM_0_13_centos ~]# helm repo remove stable
[root@VM_0_13_centos ~]# helm repo add stable https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
"stable" has been added to your repositories
[root@VM_0_13_centos ~]# helm repo list
NAME    URL
local   http://127.0.0.1:8879/charts
stable  https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
```

我们也可以在控制台安装应用的时候指定chart包地址进行下载

![upload-image](/assets/images/blog/tke04/14.png) 

![upload-image](/assets/images/blog/tke04/15.png) 

新建应用中填写指定的chart包地址进行安装即可

# 日志的采集
## 创建日志采集

![upload-image](/assets/images/blog/tke04/16.png) 

首先要在集群中安装扩展插件才能进行日志采集

![upload-image](/assets/images/blog/tke04/17.png) 

![upload-image](/assets/images/blog/tke04/18.png) 

参数说明
* 名称：填写你日志采集器的名称
* 类型：收集说明类型的日志
* 日志源：可以指定某个容器，也可以选择全部容器（我们这里选择全部）
* 消费端：消费端也就是日志存储的地方，我们选择CLS（没有创建CLS，要先创建）

## 创建CLS日志采集服务

![upload-image](/assets/images/blog/tke04/19.png) 

![upload-image](/assets/images/blog/tke04/20.png) 

![upload-image](/assets/images/blog/tke04/21.png)

可以根据需要选择你日志保存的天数

![upload-image](/assets/images/blog/tke04/22.png) 

参数说明：

日志主题名称：采集日志名称

主题分区数量：通过合并或分裂操作可以自由划分区间，从而控制服务的整体吞吐性能，最多为50个

## 收集日志
![upload-image](/assets/images/blog/tke04/23.png) 

引用创建的日志主题，点击完成

![upload-image](/assets/images/blog/tke04/24.png) 

日志采集创建完成

## 检索日志
![upload-image](/assets/images/blog/tke04/25.png) 

日志服务中找到【检索分析】，然后选择你的主题，设置你的日志时间，可以搜索你想要查看的日志内容

# 告警设置
![upload-image](/assets/images/blog/tke04/26.png) 

![upload-image](/assets/images/blog/tke04/27.png) 

可以设置不同的告警指标条件，然后将告警通过不同的方式来给不同的用户组

# 事件持久化

Kubernetes Events 包括了 Kuberntes 集群的运行和各类资源的调度情况，对维护人员日常观察资源的变更以及定位问题均有帮助。TKE 支持为您的所有集群配置事件持久化功能，开启本功能后，会将您的集群事件实时导出到配置的存储端。TKE 还支持使用腾讯云提供的 PAAS 服务或开源软件对事件流水进行检索

![upload-image](/assets/images/blog/tke04/28.png) 

![upload-image](/assets/images/blog/tke04/29.png) 

可以将持久化日志存储到ES或者CLS中

# 健康检查

![upload-image](/assets/images/blog/tke04/30.png) 

点击健康检查，选择你的集群，可以选择立即手动检查，也可以设置某个时间定时检查。

![upload-image](/assets/images/blog/tke04/31.png) 

点击健康检查，选择你的集群，可以选择立即手动检查，也可以设置某个时间定时检查。

![upload-image](/assets/images/blog/tke04/32.png) 

根据报告可以适当的调整集群，修复告警项

# TecentDB部署WordPress

## 创建mysql数据库

![upload-image](/assets/images/blog/tke04/33.png) 

![upload-image](/assets/images/blog/tke04/34.png) 

![upload-image](/assets/images/blog/tke04/35.png) 

![upload-image](/assets/images/blog/tke04/36.png)

初始化完成后mysql数据库即创建完成

## 部署WordPress服务

![upload-image](/assets/images/blog/tke04/37.png)
 
![upload-image](/assets/images/blog/tke04/38.png) 

![upload-image](/assets/images/blog/tke04/39.png) 

主要参数信息如下，其余选项保持默认设置：
* 名称：输入自定义容器名称，本文以 my-wordpress为例。
* 镜像：输入 wordpress。
* 镜像版本（Tag）：输入 latest。
* 镜像拉取策略：提供以下3种策略，请按需选择，本文以不进行设置使用默认策略为例。若不设置镜像拉取策略，当镜像版本为空或 latest 时，使用 Always 策略，否则使用 IfNotPresent 策略。
    - Always：总是从远程拉取该镜像。
    - IfNotPresent：默认使用本地镜像，若本地无该镜像则远程拉取该镜像。
    - Never：只使用本地镜像，若本地没有该镜像将报异常。
* 环境变量：依次输入以下配置信息：
    - WORDPRESS_DB_HOST = 云数据库 MySQL 的内网 IP
    - WORDPRESS_DB_PASSWORD = 初始化时填写的密码
* Service：勾选“启用”。
* 服务访问方式：选择“提供公网访问”。
* 负载均衡器：根据实际需求进行选择。
* 端口映射：选择 TCP 协议，将容器端口和服务端口都设置为80 。

## 访问wordpress服务

![upload-image](/assets/images/blog/tke04/40.png) 
