---
title: 如何搭建docker私有镜像仓库
author: VashonNie
date: 2020-10-12 14:10:00 +0800
updated: 2020-10-12 14:10:00 +0800
categories: [Docker]
tags: [Docker]
math: true
---

本文主要介绍了如何搭建docker私有镜像仓库。

## 服务端下载镜像registry
```
docker pull registry
```
## 生成登录的用户名和密码
```
mkdir -p /data/docker-registry/auth
docker run --entrypoint htpasswd docker.io/registry:latest -Bbn nwx 000000  >> /data/docker-registry/auth/htpasswd  
```
## 节设置配置文件，启用删除镜像功能
也可以不启用，看业务需要，修改 storage - delete - enable 为 false 即可
```
mkdir -p /data/docker-registry/config
vim  /data/docker-registry/config/config.yml
version: 0.1
log:
  fields:
    service: registry
storage:
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
threshold: 3
```
## 启动registry镜像服务
```
docker run -d -p 5000:5000 --restart=always  --name=registry\
  -v /data/docker-registry/auth/:/auth/ \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -v /data/docker-registry/:/var/lib/registry/ \
docker.io/registry:latest
```
## 开启节点的http形式访问私有仓库
```
vim /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "insecure-registries":["55.18.67.171:5000"]
}

systemctl daemon-reload
systemctl restart docker
```

## 上传和下载镜像到私有仓库
```
docker pull docker.io/hello-world
docker tag docker.io/hello-world:latest 106.54.126.251:5000/hello-word:latest
docker login 106.54.126.251:5000 -u nwx -p 000000
docker push 106.54.126.251:5000/hello-word:latest
curl -u nwx:000000  http://106.54.126.251:5000/v2/_catalog
curl -u nwx:000000  http://106.54.126.251:5000/v2/sprintboot/tags/list
```
## k8s创建拉取镜像秘钥
默认default命名空间使用的secret
```
kubectl create secret docker-registry 10.10.10.149  --docker-server=55.18.67.171:5000 --docker-username=hy --docker-password=000000 --docker-email=niewx@ruyi.ai
```
hy-uat命名空间使用的secret
```
kubectl create secret docker-registry 10.10.10.149  --docker-server=55.18.67.171:5000 –namespace=hy-uat --docker-username=hy --docker-password=000000 --docker-email=niewx@ruyi.ai
```
## 列出所有镜像
```
curl -u hy:000000  http://55.18.67.171:5000/v2/_catalog
```
## 列出busybox镜像有哪些tag
```
curl -u hy:000000  http://55.18.67.171:5000/v2/company-ner/tags/list
```