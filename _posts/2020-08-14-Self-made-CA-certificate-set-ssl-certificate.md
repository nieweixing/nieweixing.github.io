---
title: 自制CA证书设置ssl证书
author: VashonNie
date: 2020-08-14 14:10:00 +0800
updated: 2020-08-14 14:10:00 +0800
categories: [linux]
tags: [linux,ssl]
math: true
---

本章介绍了如何自制CA证书签发ssl证书来配置https服务

# 安装openssl工具

```
# yum install openssl
# yum install openssl-devel
# openssl version -a
```
# 生成ca证书

## 生成 CA 私钥

```
# openssl genrsa -out ca.key 1024
```

## 生成请求文件

```
openssl req -new -key ca.key -out ca.csr -subj "/C=CN/ST=Guangdong/L=Shenzhen/O=devops/OU=devops/CN=nwx_qdlg@163.com" 
```
**注意**:这里的 Organization Name (eg, company) [Internet Widgits Pty Ltd]: 后面生成客户端和服务器端证书的时候也需要填写，O和OU不要写成一样的！！！

## 生成CA证书

```
openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt
```

# 生成服务端证书并CA签发

## 生成服务端私钥

```
openssl genrsa -out server.key 1024
```

## 生成服务端公钥
```
openssl rsa -in server.key -pubout -out server.pem
```

## 生成服务端向CA申请签名的CSR
```
openssl req -new -key server.key -out server.csr -subj "/C=CN/ST=Guangdong/L=Shenzhen/O=serverdevops/OU=serverdevops/CN=nwx_qdlg@163.com"
```

## 生成服务端带有CA签名的证书
```
openssl x509 -req -CA ca.crt -CAkey ca.key -CAcreateserial -in server.csr -out server.crt
```

# 生成客户端证书并CA签发

## 生成客户端私钥

```
openssl genrsa -out client.key 1024
```

## 生成客户端公钥

```
openssl rsa -in client.key -pubout -out client.pem
```

## 生成客户端向CA申请签名的CSR

```
openssl req -new -key client.key -out client.csr -subj "/C=CN/ST=Guangdong/L=Shenzhen/O=clientdevops/OU=clientdevops/CN=nwx_qdlg@163.com"
```

## 生成客户端带有CA签名的证书

```
openssl x509 -req -CA ca.crt -CAkey ca.key -CAcreateserial -in client.csr -out client.crt
```

# 使用证书在nginx进行https的配置
将服务端或者客户端生成的私钥和CA签名证书拷贝到对应的服务部署机器上进行部署

例如：

配置nginx 我们拿到CA签发的这个证书后，需要将证书配置在nginx中。 首先，我们将server.crt和server.key拷贝到nginx的配置文件所在的目录 其次，在nginx的配置中添加如下配置：

```
server {
        listen       443 ssl;
        server_name  你的域名;
        charset utf-8;

        ssl on;
        ssl_certificate      server.crt;
        ssl_certificate_key  server.key;

        location / {
            root   html;
            index  index.html index.htm;
        }
    }
```