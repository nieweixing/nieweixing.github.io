---
title: Nginx的学习和配置
author: VashonNie
date: 2021-05-21 14:10:00 +0800
updated: 2021-05-21 14:10:00 +0800
categories: [Nginx]
tags: [Nginx]
math: true
---

```
镜像源：sudo rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
```

centos上安装这个镜像源，然后rpm install nginx即可

# Nginx.conf配置文件解析

```
#运行用户
user www-data;    
#启动进程,通常设置成和cpu的数量相等
worker_processes  1;
 
#全局错误日志及PID文件
error_log  /var/log/nginx/error.log;
pid        /var/run/nginx.pid;
 
#工作模式及连接数上限
events {
    use   epoll;             #epoll是多路复用IO(I/O Multiplexing)中的一种方式,但是仅用于linux2.6以上内核,可以大大提高nginx的性能
    worker_connections  1024;#单个后台worker process进程的最大并发链接数
    # multi_accept on; 
}
 
#设定http服务器，利用它的反向代理功能提供负载均衡支持
http {
     #设定mime类型,类型由mime.type文件定义
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    #设定日志格式
    access_log    /var/log/nginx/access.log;
 
    #sendfile 指令指定 nginx 是否调用 sendfile 函数（zero copy 方式）来输出文件，对于普通应用，
    #必须设为 on,如果用来进行下载等应用磁盘IO重负载应用，可设置为 off，以平衡磁盘与网络I/O处理速度，降低系统的uptime.
    sendfile        on;
    #tcp_nopush     on;
 
    #连接超时时间
    #keepalive_timeout  0;
    keepalive_timeout  65;
    tcp_nodelay        on;
    
    #开启gzip压缩
    gzip  on;
    gzip_disable "MSIE [1-6]\.(?!.*SV1)";
 
    #设定请求缓冲
    client_header_buffer_size    1k;
    large_client_header_buffers  4 4k;
 
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
 
    #设定负载均衡的服务器列表
     upstream mysvr {
    #weigth参数表示权值，权值越高被分配到的几率越大
    #本机上的Squid开启3128端口
    server 192.168.8.1:3128 weight=5;
    server 192.168.8.2:80  weight=1;
    server 192.168.8.3:80  weight=6;
    }
 
 
   server {
    #侦听80端口
        listen       80;
        #定义使用www.xx.com访问
        server_name  www.xx.com;
 
        #设定本虚拟主机的访问日志
        access_log  logs/www.xx.com.access.log  main;
 
    #默认请求
    location / {
          root   /root;      #定义服务器的默认网站根目录位置
          index index.php index.html index.htm;   #定义首页索引文件的名称
 
          fastcgi_pass  www.xx.com;
         fastcgi_param  SCRIPT_FILENAME  $document_root/$fastcgi_script_name; 
          include /etc/nginx/fastcgi_params;
        }
 
    # 定义错误提示页面
    error_page   500 502 503 504 /50x.html;  
        location = /50x.html {
        root   /root;
    }
 
    #静态文件，nginx自己处理
    location ~ ^/(images|javascript|js|css|flash|media|static)/ {
        root /var/www/virtual/htdocs;
        #过期30天，静态文件不怎么更新，过期可以设大一点，如果频繁更新，则可以设置得小一点。
        expires 30d;
    }
    #PHP 脚本请求全部转发到 FastCGI处理. 使用FastCGI默认配置.
    location ~ \.php$ {
        root /root;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME /home/www/www$fastcgi_script_name;
        include fastcgi_params;
    }
    #设定查看Nginx状态的地址
    location /NginxStatus {
        stub_status            on;
        access_log              on;
        auth_basic              "NginxStatus";
        auth_basic_user_file  conf/htpasswd;
    }
    #禁止访问 .htxxx 文件
    location ~ /\.ht {
        deny all;
    }
     }
}
```

# Nginx在dockerfile中的配置

Dockerfile中执行的方式，注意这里是将自己配置的nginx的配置文件拷贝到了/opt/nginx的目录下面

```
CMD[“nginx”,”-p”,”/opt/nginx”.”-c”,”/opt/nginx/conf/nginx.conf”]
```

# Nginx在配置文件中的内置变量

```
# 通过arg_<name>的方式可取出相关参数，若请求 /foo?name=Tony&age=2，则 arg_name=tony arg_age=2
$arg_name
$args
# 客户端IP地址二进制
$binary_remote_addr
# 发送到客户端的字节数，不包括响应头
$body_bytes_sent
# 发送给客户端字节数
$bytes_sent
# 连接序列号
$connection
# 当前已经连接的请求书
$connection_requests
# Content-Length 请求头
$content_length
# Content-Type 请求头
$content_type
# cookie 名称
$cookie_name
# 当前请求的 root 或 alias 的值
$document_root
# 与 $uri 相同
$document_uri
# 优先级：请求行中的 host name，请求头中的 Host，请求匹配的 server name
$host
# host name
$hostname
# 任意请求头字段。变量名的最后一部分是转换为小写的字段名，用下划线替换破折号
$http_name
# 如果连接在 SSL 模式下运行，则为 on，否则为空字符串
$https
# ? 后如果请求行有参数，或者空字符串
$is_args
# 设置此变量可以限制响应速度
$limit_rate
# 当前时间(秒)，分辨率为毫秒
$msec
# nginx 版本号
$nginx_version
# 当前 worker 进程号
$pid
# 如果是 pipelined 则为 p，否则为 . 
$pipe
# 代理协议头中的客户端地址，否则为空字符串，代理协议之前必须通过在listen指令中设置 proxy_protocol 参数来启用
$proxy_protocol_addr
# 来自代理协议头的客户端端口，否则为空字符串，代理协议之前必须通过在listen指令中设置 proxy_protocol 参数来启用
$proxy_protocol_port
# 与 $args 相同
$query_string
# 与当前请求的 root 或 alias 指令值对应的绝对路径名，所有符号链接都解析为实际路径
$realpath_root
# 客户端地址
$remote_addr
# 客户端端口
$remote_port
# 使用 Basic auth 的用户名
$remote_user
# 完整的请求行
$request
# 请求体，当将请求体读入内存缓冲区时，proxy_pass、fastcgi_pass、uwsgi_pass和scgi_pass指令处理的位置可以使用变量的值
$request_body
# 具有请求主体的临时文件的名称
$request_body_file
# 如果请求完成则为 OK，否则为空
$request_completion
# 当前请求的文件路径，基于 root 或 alias 和请求 URI
$request_filename
# 由16个随机字节生成的惟一请求标识符，以十六进制表示
$request_id
# 请求长度(包括请求行、头和请求体)
$request_length
# 请求方法，如 GET 或 POST
$request_method
# 请求处理时间，从客户端读取第一个字节以来的时间
$request_time
# 若请求 /foo?a=1&b=2，则 request_uri=/foo?a=1&b=2
$request_uri
# 如 http 或 https
$scheme
# 任意响应报头字段，变量名的最后一部分是转换为小写的字段名，用下划线替换破折号
$sent_http_name
# 响应结束时发送的任意字段，变量名的最后一部分是转换为小写的字段名，用下划线替换破折号
$sent_trailer_name
# 接受请求的服务器的地址
$server_addr
# 接受请求的 server 名称
$server_name
# 接受请求的 server 端口
$server_port
# 请求协议，如 HTTP/1.0 或 HTTP/1.1 或 HTTP/2.0
$server_protocol
# 响应状态
$status
$tcpinfo_rtt,$tcpinfo_rttvar,$tcpinfo_snd_cwnd,$tcpinfo_rcv_space
# 本地时间ISO 8601标准格式
$time_iso8601
# 通用日志格式的本地时间
$time_local
# 若请求 /foo?a=1&b=2，则 uri=/foo
$uri
# 用户代理
$http_user_agent
# cookie
$http_cookie
```

# Nginx的访问鉴权（设置登录账号密码）

## 首先安装htpasswd和ngxin工具

用htpasswd的工具在/etc/nginx/创建一个用户密码，我这里创建一个admin用户，密码也是admin

```
$ htpasswd -c .htpasswd admin
New password: admin
Re-type new password: admin
Adding password for user admin
```

## 在ngxin的配置文件中添加配置，加入你之前访问的端口是30003

```
http {
  server {
    listen 0.0.0.0:40003;
    location / {
      proxy_pass http://localhost:30003/;
      auth_basic "Prometheus";
      auth_basic_user_file ".htpasswd";
    }
  }
```

## 启动nginx采用如下地址访问你的30003服务

在浏览器输入http://nginx-ip:40003，提示你需要输入账号密码，输入之前的admin/admin则登录成功

也可以在后台进行curl -u admin http://localhost:40003进行测试访问

## Nginx中proxy_pass的配置

```
location /test/
{
Proxy_pass http://t6:8300;   #不到/
 }

location /test/
{
Proxy_pass http://t6:8300/;  #带/
 }
```

上面两种配置，区别只在于proxy_pass转发的路径后是否带 “/”

针对情况1，如果访问url = http://server/test/test.jsp，则被nginx代理后，请求路径会便问http://proxy_pass/test/test.jsp，将test/ 作为根路径，请求test/路径下的资源

针对情况2，如果访问url = http://server/test/test.jsp，则被nginx代理后，请求路径会变为 http://proxy_pass/test.jsp，直接访问server的根资源

# Nginx的启停

## 启动

```
cd usr/local/nginx/sbin
./nginx
```

## 重启

更改配置重启nginx

kill -HUP 主进程号或进程号文件路径,或者使用

```
cd /usr/local/nginx/sbin
./nginx -s reload
```

判断配置文件是否正确　

```
nginx -t -c /usr/local/nginx/conf/nginx.conf
或者
cd /usr/local/nginx/sbin
./nginx -t
```

## 关闭


查询nginx主进程号

```
ps -ef | grep nginx
```

从容停止 kill -QUIT 主进程号
快速停止 kill -TERM 主进程号
强制停止 kill -9 nginx

若nginx.conf配置了pid文件路径，如果没有，则在logs目录下

```
kill -信号类型 '/usr/local/nginx/logs/nginx.pid'
```
# Nginx如何读取环境变量

## 首先需要引入nginx的lua模块

具体安装lua模块参考下列dockerfile

```
# Base images 基础镜像
FROM centos:centos7
#FROM hub.c.163.com/netease_comb/centos:7
#安装相关依赖
RUN yum -y update
RUN yum -y install  gcc gcc-c++ autoconf automake make
RUN yum -y install  zlib zlib-devel openssl* pcre* wget lua-devel
 
#MAINTAINER 维护者信息
MAINTAINER niewx 35715270@qq.com
 
#ADD  获取url中的文件,放在当前目录下
ADD http://nginx.org/download/nginx-1.14.0.tar.gz /tmp/
#LuaJIT 2.1
#ADD http://luajit.org/download/LuaJIT-2.0.5.tar.gz /tmp/
ADD https://github.com/LuaJIT/LuaJIT/archive/v2.0.5.tar.gz /tmp/
#ngx_devel_kit（NDK）模块
ADD https://github.com/simpl/ngx_devel_kit/archive/v0.3.0.tar.gz /tmp/
#lua-nginx-module 模块
ADD https://github.com/openresty/lua-nginx-module/archive/v0.10.13.tar.gz /tmp/
#nginx ngx_cache_purge模块
ADD http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz  /tmp/
 
#切换目录
WORKDIR  /tmp 
 
#安装LuaJIT 2.0.5
#RUN wget http://luajit.org/download/LuaJIT-2.0.5.tar.gz -P /tmp/
RUN tar zxf v2.0.5.tar.gz
WORKDIR  /tmp/LuaJIT-2.0.5
#RUN cd LuaJIT-2.0.5
RUN make PREFIX=/usr/local/luajit 
RUN make install PREFIX=/usr/local/luajit
 
#安装ngx_devel_kit(NDK)
WORKDIR  /tmp
RUN tar -xzvf v0.3.0.tar.gz
RUN cp -r ngx_devel_kit-0.3.0/ /usr/local/src/
 
#安装lua-nginx-module模块
RUN tar -xzvf v0.10.13.tar.gz
RUN cp -r lua-nginx-module-0.10.13/ /usr/local/src/
 
#安装nginx ngx_cache_purge模块
RUN tar -xzvf ngx_cache_purge-2.3.tar.gz
RUN cp -r ngx_cache_purge-2.3/ /usr/local/src/
 
#设置环境变量
RUN export LUAJIT_LIB=/usr/local/lib
RUN export LUAJIT_INC=/usr/local/include/luajit-2.0
 
RUN mkdir -p {/usr/local/nginx/logs,/var/lock}
 
#编译安装Nginx
RUN useradd -M -s /sbin/nologin nginx
RUN tar -zxvf nginx-1.14.0.tar.gz
RUN mkdir -p /usr/local/nginx
RUN cd /tmp/nginx-1.14.0 \
	&& ./configure --prefix=/usr/local/nginx --user=nginx --group=nginx \
	--error-log-path=/usr/local/nginx/logs/error.log \
	--http-log-path=/usr/local/nginx/logs/access.log \
	--pid-path=/usr/local/nginx/logs/nginx.pid \
	--lock-path=/var/lock/nginx.lock \
	--with-ld-opt="-Wl,-rpath,/usr/local/luajit/lib" \
	--with-http_stub_status_module \
	--with-http_ssl_module \
	--with-http_sub_module \
	--add-module=/usr/local/src/lua-nginx-module-0.10.13 \
	--add-module=/usr/local/src/ngx_devel_kit-0.3.0 \
	--add-module=/usr/local/src/ngx_cache_purge-2.3 \
	&& make && make install
#参数说明
#--prefix 用于指定nginx编译后的安装目录
#--add-module 为添加的第三方模块，此次添加了fdfs的nginx模块
#--with..._module 表示启用的nginx模块，如此处启用了http_ssl_module模块	
RUN /usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
RUN ln -s /usr/local/nginx/sbin/* /usr/local/sbin/
#EXPOSE 映射端口
EXPOSE 80 443
 
#CMD 运行以下命令
#CMD ["nginx"]
CMD ["/usr/local/nginx/sbin/nginx","-g","daemon off;"]
```

## 在系统中写入你的环境变量

```
export TEST_IP=10.10.10.10 
```

## 在nginx中引入你的环境变量，具体编写参考如下

![upload-image](/assets/images/blog/nginx/1.png)
 
# Nginx监听多个端口

可以配置多个server，每个server配置不同的端口 

![upload-image](/assets/images/blog/nginx/1.png)

# Nginx的负载均衡

```
//举例，以下IP，端口无效
 upstream test{ 
      server 11.22.333.11:6666 weight=1; 
      server 11.22.333.22:8888 down; 
      server 11.22.333.33:8888 backup;
      server 11.22.333.44:5555 weight=2; 
}
```

* down 表示单前的server临时不參与负载.
* weight 默觉得1.weight越大，负载的权重就越大
* backup： 其他全部的非backup机器down或者忙的时候，请求backup机器。所以这台机器压力会最轻
