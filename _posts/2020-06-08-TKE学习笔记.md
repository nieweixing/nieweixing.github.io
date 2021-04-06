---
title: TKE学习笔记
author: VashonNie
date: 2020-06-08 14:10:00 +0800
updated: 2020-06-08 14:10:00 +0800
categories: [TKE,腾讯云]
tags: [Kubernetes,Docker,TKE]
math: true
---

该文章介绍了在TKE学习使用过程中的一些记录，tke集群中的各类组件如何选择。

# TKE集群网络模式

## GlobalRouter 模式

![upload-image](/assets/images/bolg/tke-study/1.png) 

GlobalRouter模式是在每个节点下起一个agent从整个VPC中指定一个子网进行通信和数据的传输。该模式其实就是在VPC下为每个节点分配一个子网进行网络通讯和传输

## VPC-CNI 模式

![upload-image](/assets/images/blog/tke-study/2.png) 

VPC-CNI模式是在某个VPC下提前规划好多个子网，pod服务通过每个节点上的弹性网卡从子网中随机分配ip来进行pod之间的通讯和数据传输。固定IP模式其实就是单独固定某个子网作为pod的ip和service分配使用。

## VPC-CNI和GlobalRouter对比

![upload-image](/assets/images/blog/tke-study/3.png) 

* 绝大多数情况下应该选择 GlobalRouter，容器网段地址充裕，扩展性强，能适应规模较大的业务
* 如果后期部分业务需要用到 VPC-CNI 模式，可以在 GlobalRouter 集群再开启 VPC-CNI 支持，也就是 GlobalRouter 与 VPC-CNI 混用，仅对 部分业务使用 VPC-CNI 模式  
* 如果完全了解并接受 VPC-CNI 的各种限制，并且需要集群内所有 Pod 都用 VPC-CNI 模式，可以创建集群时选择 VPC-CNI 网络插件

# TKE集群容器运行组件

## Docker

![upload-image](/assets/images/blog/tke-study/4.png) 

docker运行容器，主要是通过kubelet调用dockerd的进程，调用docker-containerd接口去启动对应的容器

## Containerd

![upload-image](/assets/images/blog/tke-study/5.png) 

containerd则主要是kubelet通过CRI插件去调用containerd的api接口来启动容器

## docker和containerd对比

* containerd 方案由于绕过了 dockerd，调用链更短，组件更少，占用节点资源更少，绕过了 dockerd 本身的一些 bug，但 containerd 自身也还存在一些 bug (已修复一些，灰度中) 
* docker 方案历史比较悠久，相对更成熟，支持 docker api，功能丰富，符合大多数人的使用习惯

推荐使用docker方式，这样可以调用docker api以及命令，如果想对docker做优化也可以执行

# servie的转发
## iptables

![upload-image](/assets/images/blog/tke-study/6.png) 

iptables支持的小场景下应用，更加稳定

## ipvs

![upload-image](/assets/images/blog/tke-study/7.png) 

* IPVS为大型集群提供了更好的可扩展性和性能。（规则的存储方式使用的数据结构更高效）
* IPVS支持比iptables更复杂的负载平衡算法（最小负载，最少连接，位置，加权等）。
* IPVS支持服务器健康检查和连接重试等。

# 集群故障定位

## pod退出错误码分析

* 129-255 表示进程因外界中断信号退出，最常见的是 137，表示被 SIGKILL 杀死，可能是 Cgroup OOM，系统 OOM，存 活检查失败或者被其它进程杀死导致 
* 1-128 表示进程主动退出 (只是约定)，具体状态码含义取决于应用程序逻辑；有时主动退出也会是 255 状态码: 代码里使 用类似 exit(-1) 时，-1 被自动转成 255，通常状态码为 1 和 255 是一般性错误，看不错具体含义，需要结合日志分析

## 容器内抓包

nsenter命令仅进入该容器的网络命名空间，使用宿主机的命令调试容器网络
```
[root@VM_0_13_centos kubernetes-elasticsearch]# docker ps
CONTAINER ID        IMAGE                                COMMAND                  CREATED             STATUS                PORTS                                         NAMES
1421f7bbc523        goharbor/nginx-photon:v2.0.0         "nginx -g 'daemon of…"   6 days ago          Up 6 days (healthy)   0.0.0.0:80->8080/tcp, 0.0.0.0:443->8443/tcp   nginx
e9ab5bf15849        goharbor/harbor-jobservice:v2.0.0    "/harbor/entrypoint.…"   6 days ago          Up 6 days (healthy)                                                 harbor-jobservice
d04f14741f3d        goharbor/harbor-core:v2.0.0          "/harbor/entrypoint.…"   6 days ago          Up 6 days (healthy)                                                 harbor-core
c31d291b2425        goharbor/redis-photon:v2.0.0         "redis-server /etc/r…"   6 days ago          Up 6 days (healthy)   6379/tcp                                      redis
13f1de98a114        goharbor/registry-photon:v2.0.0      "/home/harbor/entryp…"   6 days ago          Up 6 days (healthy)   5000/tcp                                      registry
9e154ff22c54        goharbor/harbor-registryctl:v2.0.0   "/home/harbor/start.…"   6 days ago          Up 6 days (healthy)                                                 registryctl
051736f00111        goharbor/harbor-db:v2.0.0            "/docker-entrypoint.…"   6 days ago          Up 6 days (healthy)   5432/tcp                                      harbor-db
b10b982a225a        goharbor/harbor-portal:v2.0.0        "nginx -g 'daemon of…"   6 days ago          Up 6 days (healthy)   8080/tcp                                      harbor-portal
3a0d7ec954c5        goharbor/harbor-log:v2.0.0           "/bin/sh -c /usr/loc…"   6 days ago          Up 6 days (healthy)   127.0.0.1:1514->10514/tcp                     harbor-log
[root@VM_0_13_centos kubernetes-elasticsearch]# nsenter --target 6128
[root@VM_0_13_centos kubernetes-elasticsearch]# docker inspect -f {{.State.Pid}} 1421f7bbc523
6128
[root@VM_0_13_centos kubernetes-elasticsearch]# nsenter -n --target 6128
```

进入之后可以执行对应的ip address，ping，telnet，ss，tcpdump命令等

```
[root@VM_0_13_centos kubernetes-elasticsearch]# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
31887: eth0@if31888: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:1f:00:0a brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.31.0.10/16 brd 172.31.255.255 scope global eth0
       valid_lft forever preferred_lft forever
[root@VM_0_13_centos kubernetes-elasticsearch]# tcpdump -i eth0 tcp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
```
## 在pod中通过busybox容器来修改系统参数失败
现在的版本中集群中如果节点使用TKE订制镜像，无法修改pod的内核参数，如果需要支持内核参数的修改，可以采用官方的centos和ubuntu镜像。