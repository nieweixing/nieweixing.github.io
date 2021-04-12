---
title: harbor搭建企业docker私有镜像仓库
author: VashonNie
date: 2020-07-12 14:10:00 +0800
updated: 2020-07-12 14:10:00 +0800
categories: [Harbor]
tags: [Kubernetes,Docker,Harbor]
math: true
---

本篇文章介绍了如何搭建企业级私有镜像仓库harbor及harbor仓库的使用。

# 搭建harbor仓库

## 安装docker和docker-compose

```
# curl -fsSL https://get.docker.com/ | sh
# systemctl start docker
# systemctl enable docker
# curl -L https://github.com/docker/compose/releases/download/1.19.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
# chmod +x /usr/local/bin/docker-compose
```

## 下载harbor安装包

```
# wget https://github.com/goharbor/harbor/releases/download/v2.0.0/harbor-offline-installer-v2.0.0.tgz
# tar -zxvf harbor-offline-installer-v2.0.0.tgz
# mv harbor /opt/
# cd /opt/harbor
# cp harbor.yml.tmpl harbor.yml
```

## 配置https方式访问证书

1. 生成根证书(存放到目录/etc/docker/certs.d/reg.niewx.club)
```
$ mkdir -p /etc/docker/certs.d/reg.niewx.club && cd /etc/docker/certs.d/reg.niewx.club 
```
2. 创建自己的CA证书（不使用第三方权威机构的CA来认证，自己充当CA的角色
```
$ openssl genrsa -out ca.key 2048
```
3. 生成自签名证书（使用已有私钥ca.key自行签发根证书）
```
$ openssl req -x509 -new -nodes -key ca.key -days 10000 -out ca.crt -subj "/CN=Harbor-ca"
```
4. 生成服务器端私钥和CSR签名请求
```
$ openssl req -newkey rsa:4096 -nodes -sha256 -keyout server.key -out server.csr
```
5. 签发服务器证书
```
echo subjectAltName = IP:49.235.179.157 > extfile.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 -extfile extfile.cnf -out server.crt
```
6. 最终生成的证书如下
```
[root@VM_0_13_centos reg.niewx.club]# ls
ca.crt ca.key ca.srl extfile.cnf server.crt server.csr server.key
```

## 修改harbor配置项
```
[root@VM_0_13_centos harbor]# cat harbor.yml
# Configuration file of Harbor
# The IP address or hostname to access admin UI and registry service.
# DO NOT use localhost or 127.0.0.1, because Harbor needs to be accessed by external clients.
hostname: 1.1.1.1
# http related config
#http:
 # port for http, default is 80. If https enabled, this port will redirect to https port
# port: 80
# https related config
https:
 # https port for harbor, default is 443
 port: 443
 # The path of cert and key files for nginx
 certificate: /etc/docker/certs.d/reg.niewx.club/server.crt
 private_key: /etc/docker/certs.d/reg.niewx.club/server.key
# # Uncomment following will enable tls communication between all harbor components
# internal_tls:
# # set enabled to true means internal tls is enabled
# enabled: true
# # put your cert and key files on dir
# dir: /etc/harbor/tls/internal
# Uncomment external_url if you want to enable external proxy
# And when it enabled the hostname will no longer used
# external_url: https://reg.mydomain.com:8433
# The initial password of Harbor admin
# It only works in first time to install harbor
# Remember Change the admin password from UI after launching Harbor.
harbor_admin_password: 123456
```
主要需要修改上面标记的选项。

## 启动harbor
```
# cd /opt/harbor
# ./ prepare
# ./install.sh --with-clair (启动扫描器)

```

![upload-image](/assets/images/blog/harbor/1.png) 

启动日志显示上面则启动成功

如果修改了配置项需要重新启动harbor则重新执行以下命令即可
```
# cd /opt/harbor
# ./ prepare
# ./install.sh --with-clair (启动扫描器)

```

# haobor仓库的使用

## harbor的登录和创建项目

默认账号为admin，密码为你之前修改配置密码

![upload-image](/assets/images/blog/harbor/2.png) 

项目管理，里面会有一个默认的公开项目library，所有人可以上传下载镜像

![upload-image](/assets/images/blog/harbor/1-2.png) 

点击新建项目，输入项目名称，设置存储容量和是否公开

![upload-image](/assets/images/blog/harbor/3.png) 

查看项目的镜像仓库，也可以查看推送命令推送镜像

![upload-image](/assets/images/blog/harbor/4.png) 

## 客户端推送镜像

首先需要配置docker认真地址

```
[root@node1 ~]# cat /etc/docker/daemon.json
{
 "insecure-registries": ["https://1.1.1.1"],
 "registry-mirrors": ["https://yywkvob3.mirror.aliyuncs.com"],
 "exec-opts": ["native.cgroupdriver=systemd"]
}
# systemctl daemon-reload && systemctl restart docker
# docker login 1.1.1.1 -u admin -p *****
# docker tag busybox:latest 1.1.1.1/library/busybox:latest
# docker push 1.1.1.1/library/busybox:latest

```

## harbor中角色权限说明

|角色|权限说明|
|----|----|
|访客|对于指定项目拥有只读权限|
|开发人员|对于指定项目拥有读写权限|
|维护人员|对于指定项目拥有读写权限，创建 Webhooks|
|项目管理员|除了读写权限，同时拥有用户管理/镜像扫描等管理权限|



