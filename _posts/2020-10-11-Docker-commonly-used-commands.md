---
title: Docker常用命令及知识
author: VashonNie
date: 2020-09-22 14:10:00 +0800
updated: 2020-09-22 14:10:00 +0800
categories: [Docker]
tags: [Docker]
math: true
---

本文介绍了日常运维中用的一些docker命令和知识。

## docker容器访问其他容器服务
docker run -d --network host -p 8081:8081 xxxxxxxx:v3
## docker-compose
基于docker-compose.yml,通常启动的时候是一个服务，这个服务通常由多个container共同组成，并且端口，配置等由docker-compose定义好。
## 启动docker
systemctl start docker	
## 设置docker开机启动
systemctl enable docker 
## 启动一个mysql的docker镜像
sudo docker run --name mysqltest -p 3306:3306 -e MYSQL_ROOT_PASSWORD=123456 -v /data/mysql:/var/lib/mysql -d docker.io/mysql	

## 启动一个mongo的docker镜像
sudo docker run -d -p 27017:27017 -v /data/mongodb-2-6-01-service/db:/data/db -v /data/dbback_up:/data/mongodbBack --restart=always 10.0.64.13:5000/mongo:2.6
## 从容器中拷贝文件到宿主机
docker cp 【CONTAINER ID】:【路径】文件名 【宿主机的绝对路径+文件名】	
## docker服务重启后容器也自动重启
docker run --restart=always / docker update --restart=always <CONTAINER ID>
## Docker保存多个镜像到tar中
docker save [images] [images] > [name.tar]
## Docker导出镜像到环境 
docker load<[name.tar]
## Dockerfile 创建镜像打标签
docker build -t runoob/ubuntu:v1 .
## 查看docker磁盘使用
docker system df
## 删除所有未使用的本地卷
docker volume prune
## 清理所有处于终止状态的容器
docker container prune / docker rm \`docker ps -a | grep Exited | awk '{print $1}'`
## 清理所有未使用的镜像
docker rmi -f \`docker images | grep '<none>' | awk '{print $3}'`  
## 进入docker容器内部
sudo docker attach 44fc0f0582d9
## 查看docker容器的cpu及内存的使用情况
docker stats  
具体使用方法参考链接：  
https://blog.csdn.net/hu_jinghui/article/details/80198492
## 更新已经启动容器的参数
如果已经启动了则可以使用如下命令：
docker update --restart=always <CONTAINER ID>

## dockerfile中参数-Djava.security.egd=file:/dev/./urandom
docker+tomcat 启动时非常慢，一般正常启动几十秒的，发现docker+tomcat启动竟需要几分钟，不可思议Tomcat7/8都使用org.apache.catalina.util.SessionIdGeneratorBase.createSecureRandom 类产生安全随SecureRandom 的实例作为会话 ID，SecureRandom generateSeed 使用 /dev/random 生成种子。但是 /dev/random 是一个阻塞数字生成器，如果它没有足够的随机数据提供，它就一直等，这迫使 JVM 等待。键盘和鼠标输入以及磁盘活动可以产生所需的随机性或熵。但在一个服务器缺乏这样的活动，可能会出现问题。
有2种解决方案：  
* 在Tomcat环境中解决：
可以通过配置 JRE 使用非阻塞的 Entropy Source：  
在 catalina.sh 中加入这么一行：-Djava.security.egd=file:/dev/./urandom 即可。  
* 在 JVM 环境中解决（本人使用此方法）：
打开jdk安装路径 $JAVA_PATH/jre/lib/security/java.security 这个文件，找到下面的内容：  
securerandom.source=file:/dev/random替换成：securerandom.source=file:/dev/./urandom

如果是采用docker的方式启动，则在启动命令中加入-Djava.security.egd=file:/dev/./urandom 这样一行

## 动态修改容器的内存大小
docker update --memory 2048m --memory-swap -1 container_id/container_name

## 退出容器而不停止容器
如果要正常退出不关闭容器，请按Ctrl+P+Q进行退出容器

## 容器之间访问方式
Docker容器互访三种方式
我们都知道docker容器之间是互相隔离的，不能互相访问，但如果有些依赖关系的服务要怎么办呢。下面介绍三种方法解决容器互访问题。

 ```
方式一、虚拟ip访问

安装docker时，docker会默认创建一个内部的桥接网络docker0，每创建一个容器分配一个虚拟网卡，容器之间可以根据ip互相访问。

[root@33fcf82ab4dd /]# 
[root@CentOS ~]# ifconfig
docker0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 0.0.0.0
        inet6 fe80::42:35ff:feac:66d8  prefixlen 64  scopeid 0x20<link>
        ether 02:42:35:ac:66:d8  txqueuelen 0  (Ethernet)
        RX packets 4018  bytes 266467 (260.2 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4226  bytes 33935667 (32.3 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
...... 
 运行一个centos镜像， 查看ip地址得到：172.17.0.7

[root@CentOS ~]# docker run -it --name centos-1 docker.io/centos:latest
[root@6d214ff8d70a /]# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.7  netmask 255.255.0.0  broadcast 0.0.0.0
        inet6 fe80::42:acff:fe11:7  prefixlen 64  scopeid 0x20<link>
        ether 02:42:ac:11:00:07  txqueuelen 0  (Ethernet)
        RX packets 16  bytes 1296 (1.2 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 8  bytes 648 (648.0 B) 

以同样的命令再起一个容器，查看ip地址得到：172.17.0.8

[root@CentOS ~]# docker run -it --name centos-2 docker.io/centos:latest
[root@33fcf82ab4dd /]# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.8  netmask 255.255.0.0  broadcast 0.0.0.0
        inet6 fe80::42:acff:fe11:8  prefixlen 64  scopeid 0x20<link>
        ether 02:42:ac:11:00:08  txqueuelen 0  (Ethernet)
        RX packets 8  bytes 648 (648.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 8  bytes 648 (648.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0 
容器内部ping测试结果如下：

[root@33fcf82ab4dd /]# ping 172.17.0.7
PING 172.17.0.7 (172.17.0.7) 56(84) bytes of data.64 bytes from 172.17.0.7: icmp_seq=1 ttl=64 time=0.205 ms64 bytes from 172.17.0.7: icmp_seq=2 ttl=64 time=0.119 ms64 bytes from 172.17.0.7: icmp_seq=3 ttl=64 time=0.118 ms64 bytes from 172.17.0.7: icmp_seq=4 ttl=64 time=0.101 ms

这种方式必须知道每个容器的ip，在实际使用中并不实用。

方式二、link
运行容器的时候加上参数link
运行第一个容器
docker run -it --name centos-1 docker.io/centos:latest
运行第二个容器
[root@CentOS ~]# docker run -it --name centos-2 --link centos-1:centos-1 docker.io/centos:latest
--link：参数中第一个centos-1是容器名，第二个centos-1是定义的容器别名（使用别名访问容器），为了方便使用，一般别名默认容器名。
测试结果如下：
[root@e0841aa13c5b /]# ping centos-1
PING centos-1 (172.17.0.7) 56(84) bytes of data.64 bytes from centos-1 (172.17.0.7): icmp_seq=1 ttl=64 time=0.210 ms64 bytes from centos-1 (172.17.0.7): icmp_seq=2 ttl=64 time=0.116 ms64 bytes from centos-1 (172.17.0.7): icmp_seq=3 ttl=64 time=0.112 ms64 bytes from centos-1 (172.17.0.7): icmp_seq=4 ttl=64 time=0.114 ms
 此方法对容器创建的顺序有要求，如果集群内部多个容器要互访，使用就不太方便。

方式三、创建bridge网络
1.安装好docker后，运行如下命令创建bridge网络：docker network create testnet
查询到新创建的bridge testnet。
 ![upload-image](/assets/images/blog/docker/1.png) 

2.运行容器连接到testnet网络。
使用方法：docker run -it --name <容器名> ---network <bridge> --network-alias <网络别名> <镜像名>
[root@CentOS ~]# docker run -it --name centos-1 --network testnet --network-alias centos-1 docker.io/centos:latest
[root@CentOS ~]# docker run -it --name centos-2 --network testnet --network-alias centos-2 docker.io/centos:latest

3.从一个容器ping另外一个容器，测试结果如下：
[root@fafe2622f2af /]# ping centos-1
PING centos-1 (172.20.0.2) 56(84) bytes of data.64 bytes from centos-1.testnet (172.20.0.2):   
icmp_seq=1 ttl=64 time=0.158 ms64 bytes from centos-1.testnet (172.20.0.2):   
icmp_seq=2 ttl=64 time=0.108 ms64 bytes from centos-1.testnet (172.20.0.2):   
icmp_seq=3 ttl=64 time=0.112 ms64 bytes from centos-1.testnet (172.20.0.2):   
icmp_seq=4 ttl=64 time=0.113 ms   

4.若访问容器中服务，可以使用这用方式访问 <网络别名>：<服务端口号> 
推荐使用这种方法，自定义网络，因为使用的是网络别名，可以不用顾虑ip是否变动，只要连接到docker内部bright网络即可互访。bridge也可以建立多个，隔离在不同的网段。
```
## Docker容器日志的处理
新建/etc/docker/daemon.json，若有就不用新建了。添加log-dirver和log-opts参数，样例如下：
```
vim /etc/docker/daemon.json

{
  "registry-mirrors": ["http://f613ce8f.m.daocloud.io"],
  "log-driver":"json-file",
  "log-opts": {"max-size":"500m", "max-file":"3"}
}
```
max-size=500m，意味着一个容器日志大小上限是500M， 
max-file=3，意味着一个容器有三个日志，分别是id+.json、id+1.json、id+2.json。
// 重启docker守护进程  
systemctl daemon-reload   
systemctl restart docker  
注意：设置的日志大小，只对新建的容器有效。 
## 赋予其他普通用户docker执行权限
usermod -aG docker ${USER}
## docker的网络类型
* 默认网络模式 - bridge
* 无网络模式 - none
* 宿主网络模式 - host
* 自定义网络

默认网络模式 - bridge  
多由于独立container之间的通信 首先来侃一侃docker0. 之所以说它是默认的网络，是由于当我们运行container的时候没有“显示”的指定网络时，我们的运行起来的container都会加入到这个“默认” docker0 网络。他的模式是bridge。

无网络模式 - none  
顾名思义，所有加入到这个网络模式中的container，都"不能”进行网络通信。貌似有点鸡肋。

宿主网络模式 - host  
直接使用宿主机的网络，端口也使用宿主机的 这种网络模式将container与宿主机的网络相连通，虽然很直接，但是却破获了container的隔离性，因此也比较鸡肋

自定义网络   
由于之前介绍的3种自带的网络模式有各自的局限性，因此，docker推荐大家自定义网络。通过自定义网络，我们可以实现“服务发现”与“DNS解析”。 docker 允许我们创建3种类型的自定义网络，bridge，overlay，MACVLAN（目前我还没有用到）。

bridge  
Bridge模式是Docker默认的网络模式，当Docker进程启动时，会在主机上创建一个名为docker0的虚拟网桥，用来连接宿主机和容器，此主机上的Docker容器都会连接到这个虚拟网桥上
overlay：当有多个docker主机时，跨主机的container通信
macvlan：每个container都有一个虚拟的MAC地址
## docker的存储驱动
镜像是只读的

读写层：每一个容器在运行时，都会基于当前镜像在其最上层挂载一个读写层。而用户针对容器的所有操作都在读写层中完成。一旦容器销毁，这个读写层也随之销毁。

知识点： 容器=镜像+读写层

所有驱动都用到的技术——写时复制（CoW）。CoW就是copy-on-write，表示只在需要写时才去复制，这个是针对已有文件的修改场景。比如基于一个image启动多个Container，如果为每个Container都去分配一个image一样的文件系统，那么将会占用大量的磁盘空间。而CoW技术可以让所有的容器共享image的文件系统，所有数据都从image中读取，只有当要对文件进行写操作时，才从image里把要写的文件复制到自己的文件系统进行修改。所以无论有多少个容器共享同一个image，所做的写操作都是对从image中复制到自己的文件系统中的复本上进行，并不会修改image的源文件，且多个容器操作同一个文件，会在每个容器的文件系统里生成一个复本，每个容器修改的都是自己的复本，相互隔离，相互不影响。使用CoW可以有效的提高磁盘的利用率

docker提供了多种存储驱动来实现不同的方式存储镜像，下面是常用的几种存储驱动：
* AUFS
* OverlayFS
* Devicemapper
* Btrfs
* ZFS

AUFS（AnotherUnionFS）是一种Union FS，是文件级的存储驱动。AUFS是一个能透明覆盖一个或多个现有文件系统的层状文件系统，把多层合并成文件系统的单层表示。简单来说就是支持将不同目录挂载到同一个虚拟文件系统下的文件系统。这种文件系统可以一层一层地叠加修改文件。无论底下有多少层都是只读的，只有最上层的文件系统是可写的。当需要修改一个文件时，AUFS创建该文件的一个副本，使用CoW将文件从只读层复制到可写层进行修改，结果也保存在可写层。在Docker中，底下的只读层就是image，可写层就是Container

Overlay是Linux内核3.18后支持的，也是一种Union FS，和AUFS的多层不同的是Overlay只有两层：一个upper文件系统和一个lower文件系统，分别代表Docker的镜像层和容器层。当需要修改一个文件时，使用CoW将文件从只读的lower复制到可写的upper进行修改，结果也保存在upper层。在Docker中，底下的只读层就是image，可写层就是Container。目前最新的OverlayFS为Overlay2

Device mapper是Linux内核2.6.9后支持的，提供的一种从逻辑设备到物理设备的映射框架机制，在该机制下，用户可以很方便的根据自己的需要制定实现存储资源的管理策略。前面讲的AUFS和OverlayFS都是文件级存储，而Device mapper是块级存储，所有的操作都是直接对块进行操作，而不是文件。Device mapper驱动会先在块设备上创建一个资源池，然后在资源池上创建一个带有文件系统的基本设备，所有镜像都是这个基本设备的快照，而容器则是镜像的快照。所以在容器里看到文件系统是资源池上基本设备的文件系统的快照，并没有为容器分配空间。当要写入一个新文件时，在容器的镜像内为其分配新的块并写入数据，这个叫用时分配。当要修改已有文件时，再使用CoW为容器快照分配块空间，将要修改的数据复制到在容器快照中新的块里再进行修改。Device mapper 驱动默认会创建一个100G的文件包含镜像和容器。每一个容器被限制在10G大小的卷内，可以自己配置调整。

存储驱动---特点---优点---缺点---适用场景
AUFS	联合文件系统、未并入内核主线、文件级存储	作为docker的第一个存储驱动，已经有很长的历史，比较稳定，且在大量的生产中实践过，有较强的社区支持	有多层，在做写时复制操作时，如果文件比较大且存在比较低的层，可能会慢一些	大并发但少IO的场景

overlayFS	联合文件系统、并入内核主线、文件级存储	只有两层	不管修改的内容大小都会复制整个文件，对大文件进行修改显示要比小文件消耗更多的时间	大并发但少IO的场景

Devicemapper	并入内核主线、块级存储	块级无论是大文件还是小文件都只复制需要修改的块，并不是整个文件	不支持共享存储，当有多个容器读同一个文件时，需要生成多个复本，在很多容器启停的情况下可能会导致磁盘溢出	适合io密集的场景

Btrfs	并入linux内核、文件级存储	可以像devicemapper一样直接操作底层设备，支持动态添加设备	不支持共享存储，当有多个容器读同一个文件时，需要生成多个复本	不适合在高密度容器的paas平台上使用
ZFS	把所有设备集中到一个存储池中来进行管理	支持多个容器共享一个缓存块，适合内存大的环境	COW使用碎片化问题更加严重，文件在硬盘上的物理地址会变的不再连续，顺序读会变的性能比较差	适合paas和高密度的场景

AUFS VS OverlayFS
AUFS和Overlay都是联合文件系统，但AUFS有多层，而Overlay只有两层，所以在做写时复制操作时，如果文件比较大且存在比较低的层，则AUSF可能会慢一些。而且Overlay并入了linux kernel mainline，AUFS没有。目前AUFS已基本被淘汰

OverlayFS VS Device mapper
OverlayFS是文件级存储，Device mapper是块级存储，当文件特别大而修改的内容很小，Overlay不管修改的内容大小都会复制整个文件，对大文件进行修改显示要比小文件要消耗更多的时间，而块级无论是大文件还是小文件都只复制需要修改的块，并不是整个文件，在这种场景下，显然device mapper要快一些。因为块级的是直接访问逻辑盘，适合IO密集的场景。而对于程序内部复杂，大并发但少IO的场景，Overlay的性能相对要强一些。
## docker的默认存储位置的修改
```
sudo vim /etc/docker/daemon.json
{
"graph": "/home/server/docker"
}
```
通过添加如上字段可以指定docker的存储位置

重启docker生效  
sudo systemctl daemon-reload && sudo systemctl restart docker
## dockerfile的构建知识
* 构建缓存  
在镜像的构建过程中，Docker 根据 Dockerfile 指定的顺序执行每个指令。在执行每条指令之前，Docker 都会在缓存中查找是否已经存在可重用的镜像，如果有就使用现存的镜像，不再重复创建。当然如果你不想在构建过程中使用缓存，你可以在 docker build 命令中使用 --no-cache=true选项。Docker 中构建缓存遵循的基本规则如下：
从一个基础镜像开始（FROM 指令指定），下 一条指令将和该基础镜像的所有子镜像进行匹配，检查这些子镜像被创建时使用的指令是否和被检查的指令完全一样。如果不是，则缓存失效。
对于 ADD 和 COPY 指令，镜像中对应文件的内容也会被检查，每个文件都会计算出一个校验值。在缓存的查找过程中，会将这些校验和已存在镜像中的文件校验值进行对比。如果文件有任何改变，则缓存失效。
除了 ADD 和 COPY 指令，缓存匹配过程不会查看临时容器中的文件来决定缓存是否匹配。例如，当执行完 RUN apt-get -y update 指令后，容器中一些文件被更新，但 Docker 不会检查这些文件。这种情况下，只有指令字符串本身被用来匹配缓存。
一旦缓存失效，所有后续的 Dockerfile 指令都将产生新的镜像，缓存不会被使用

* 使用多阶段构建  
多阶段构建可以让我们大幅度减小最终的镜像大小，而不需要去想办法减少中间层和文件的数量。因为镜像是在生成过程的最后阶段生成的，所以可以利用生成缓存来最小化镜像层

* 避免安装不必要的包  
为了降低复杂性、减少依赖、减小文件大小和构建时间，应该避免安装额外的或者不必要的软件包。例如，不要在数据库镜像中包含一个文本编辑器。

* 应用解耦  
每个容器应用只关心一个方面的事情。将多个应用解耦到不同容器中，可以更轻松地保证容器的横向扩展和复用

* 最小化镜像层数  
只有 RUN、COPY 和 ADD 指令会创建层，其他指令会创建临时的中间镜像，但是不会直接增加构建的镜像大小了

* 对多行参数进行排序  
只要有可能，就将多行参数按字母顺序排序。这可以帮助你避免重复包含同一个包，更新包列表时也更容易，也更容易阅读和审查。建议在反斜杠符号 \ 之前添加一个空格，可以增加可读性。
