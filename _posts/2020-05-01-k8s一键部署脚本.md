---
title: kubernetes一键部署包
author: VashonNie
date: 2020-05-10 14:10:00 +0800
updated: 2020-05-10 14:10:00 +0800
categories: [Kubernetes]
tags: [Kubernetes,Docker]
math: true
top: true
---

本章主要介绍了k8s一键部署脚本。

# k8s一键安装包介绍

## 版本说明

* kubernetes为1.15.2版本  
* docker版本为docker-ce-19.03.1-3.el7  
* docker-comnpose版本为1.18.0。  

## 脚本功能说明

### start.sh

启动部署k8s脚本,必须在master上执行脚本,并且脚本执行方式:

sh start.sh masterIP node1Ip node2Ip node3Ip ....

### add_node_join_k8s.sh 

新加节点到k8s集群中，在master上执行必须保证master可以免密登录新的节点，执行方式:

add_node_join_k8s.sh new-node-ip

### modify_docker_storage_path.sh

新增或者替换docker存储目录脚本，在对应的机器上执行,执行方式:

modify_docker_storage_path.sh new_storage_path

### push_image_registry.sh

上传镜像到新的register仓库，将上传的镜像load到任何一台机器上,执行方式:

sh push_image_registry.sh 按照提示输入仓库地址，用户名和密码

# 使用说明

1. 准备k8s部署节点，配置master节点到node节点免密登录，免密登录配置参考https://www.cnblogs.com/www-yang-com/p/10419861.html

2. 上传包到master节点，并解压到root目录，切换/root/auto-install-k8s/k8s-install-1.15.2

3. 执行脚本start.sh masterip node1-ip node2-ip ..... (注意需要在master上执行)

4. 稍等2分钟安装完毕后可以通过kubectl get node进行验证。

5. 本集群中有搭建私有镜像仓库在master节，用户名为registry，密码为000000


# 部署包下载地址

百度网盘链接: <https://pan.baidu.com/s/13ILXvdGwjnEXHN1cnkJ5UQ> 

提取码: nw4b 


