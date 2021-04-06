---
title: linux定位问题常用命令
author: VashonNie
date: 2020-08-28 14:10:00 +0800
updated: 2020-08-28 14:10:00 +0800
categories: [linux]
tags: [linux]
math: true
---

本篇文章主要介绍了在使用linux过程中常见的一些定位问题的命令。

# ifconfig(查看网卡)

```
$ ifconfig

enp1s0    Link encap:Ethernet  HWaddr 28:d2:44:eb:bd:98  
          inet addr:192.168.0.103  Bcast:192.168.0.255  Mask:255.255.255.0
          inet6 addr: fe80::8f0c:7825:8057:5eec/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:169854 errors:0 dropped:0 overruns:0 frame:0
          TX packets:125995 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:174146270 (174.1 MB)  TX bytes:21062129 (21.0 MB)

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:15793 errors:0 dropped:0 overruns:0 frame:0
          TX packets:15793 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1 
          RX bytes:2898946 (2.8 MB)  TX bytes:2898946 (2.8 MB)
```

如果要显示所有的网络接口，包含在线（up）的或下线（down）的，使用-a 选项。

```
$ ifconfig -a   
```

如果要给一个网络接口分配一个IP地址，使用下面的命令

```
$ sudo ifconfig eth0 192.168.56.5 netmask 255.255.255.0
```

如果要启用一个网络接口，使用下面命令

```
$ sudo ifconfig up eth0
```

如果要禁用一个网络接口，使用下面命令

```
$ sudo ifconfig down eth0
```

# ip(查看网卡) 

显示所有网卡

```
# ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 52:54:00:eb:2b:9b brd ff:ff:ff:ff:ff:ff
    inet 10.168.1.4/24 brd 10.168.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:feeb:2b9b/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 20:90:6f:6a:7f:ae brd ff:ff:ff:ff:ff:ff
    inet6 fe80::2290:6fff:fe6a:7fae/64 scope link 
       valid_lft forever preferred_lft forever
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:76:73:f4:f6 brd ff:ff:ff:ff:ff:ff
```

查看路由信息

```
[root@VM_1_4_centos ~]# ip route show
default via 10.168.1.1 dev eth0 
10.168.1.0/24 dev eth0 proto kernel scope link src 10.168.1.4 
10.168.100.3 dev enic3c3d718fcd scope link 
10.168.100.11 dev enib229b17365d scope link 
169.254.0.0/16 dev eth0 scope link metric 1002 
169.254.32.0/28 dev docker0 proto kernel scope link src 169.254.32.1 linkdown 
172.16.3.64/26 dev cbr0 proto kernel scope link src 172.16.3.65 
```

# ifup，ifdown(激活或者禁用网卡)

ifup命令用于激活一个网络接口，使得可以接收或传输数据。

```
$ sudo ifup eth0
```

ifdown命令可以禁用一个网络接口，禁掉后就不能传输和接收数据了。

```
$ sudo ifdown eth0
```

# ping(探测网络连通性)

```
[root@VM_1_4_centos ~]# ping www.baidu.com
PING www.a.shifen.com (14.215.177.38) 56(84) bytes of data.
64 bytes from 14.215.177.38 (14.215.177.38): icmp_seq=1 ttl=54 time=3.30 ms
64 bytes from 14.215.177.38 (14.215.177.38): icmp_seq=2 ttl=54 time=3.15 ms
```

发送指定数量的包

```
[root@VM_1_4_centos ~]# ping -c 4 www.baidu.com
PING www.a.shifen.com (14.215.177.38) 56(84) bytes of data.
64 bytes from 14.215.177.38 (14.215.177.38): icmp_seq=1 ttl=54 time=3.59 ms
64 bytes from 14.215.177.38 (14.215.177.38): icmp_seq=2 ttl=54 time=3.16 ms
64 bytes from 14.215.177.38 (14.215.177.38): icmp_seq=3 ttl=54 time=3.19 ms
64 bytes from 14.215.177.38 (14.215.177.38): icmp_seq=4 ttl=54 time=3.14 ms

--- www.a.shifen.com ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 3.148/3.275/3.591/0.191 ms
```

# traceroute(查看数据包路由途径)

```
[root@VM_1_4_centos ~]# traceroute 106.55.165.251
traceroute to 106.55.165.251 (106.55.165.251), 30 hops max, 60 byte packets
 1  9.31.61.129 (9.31.61.129)  1.033 ms  1.954 ms  1.574 ms
 2  9.31.123.96 (9.31.123.96)  0.831 ms  1.058 ms  1.319 ms
 3  9.31.123.105 (9.31.123.105)  0.763 ms  1.330 ms  1.052 ms
 4  106.55.165.251 (106.55.165.251)  0.504 ms  0.524 ms  0.555 ms
```

# mtr(ping+traceroute)

```
# mtr qq.com
```

![upload-image](/assets/images/blog/linux/1.png)

# route(查看路由表)

```
[root@VM_1_4_centos ~]# route 
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         gateway         0.0.0.0         UG    0      0        0 eth0
10.168.1.0      0.0.0.0         255.255.255.0   U     0      0        0 eth0
10.168.100.3    0.0.0.0         255.255.255.255 UH    0      0        0 enic3c3d718fcd
10.168.100.11   0.0.0.0         255.255.255.255 UH    0      0        0 enib229b17365d
link-local      0.0.0.0         255.255.0.0     U     1002   0        0 eth0
169.254.32.0    0.0.0.0         255.255.255.240 U     0      0        0 docker0
172.16.3.64     0.0.0.0         255.255.255.192 U     0      0        0 cbr0
```

添加一个网络路由到一个路由表：

```
$ sudo route add -net <network ip/cidr> gw <gateway ip> <interface>
```

从路由表中删除特定的路由项：

```
$ sudo route del -net <network ip/cidr>
```

# netstat(查看连接数)

查看某个服务的TCP连接数

```
# netstat -an | grep ESTABLISHED | grep 126:80 | wc -l
```

查看udp的连接数

```
netstat -nu
```

查看网卡列表

```
[root@VM_1_4_centos ~]# netstat -i 
Kernel Interface table
Iface             MTU    RX-OK RX-ERR RX-DRP RX-OVR    TX-OK TX-ERR TX-DRP TX-OVR Flg
cbr0             1500 421966834      0      0 0      478598834      0      0      0 BMPRU
docker0          1500        0      0      0 0             7      0      0      0 BMU
enib229b17365d   1500  3399766      0      0 0       5942984      0      0      0 BMRU
enic3c3d718fcd   1500  1187714      0      0 0       1188197      0      0      0 BMRU
eth0             1500 945294724      0      0 0      695281730      0      0      0 BMRU
eth1             1500  8390504      0      0 0       4818989      0      0      0 BMRU
lo              65536  6202712      0      0 0       6202712      0      0      0 LRU
veth00bf0de2     1500       10      0      0 0         10516      0      0      0 BMRU
```

显示组播组的关系

```
# netstat -g
IPv6/IPv4 Group Memberships
Interface    RefCnt Group
--------------- ------ ---------------------
lo       1   ALL-SYSTEMS.MCAST.NET
eth0      1   ALL-SYSTEMS.MCAST.NET
lo       1   ff02::1
eth0      1   ff02::1:ff0a:b0c
eth0      1   ff02::1
```

显示网络统计信息

```
# netstat -s
Ip:
  184695 total packets received
  0 forwarded
  0 incoming packets discarded
  184687 incoming packets delivered
  143917 requests sent out
  32 outgoing packets dropped
  30 dropped because of missing route
Icmp:
  676 ICMP messages received
```

显示监听的套接口

```
# netstat -l
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State      
tcp        0      0 0.0.0.0:ssh             0.0.0.0:*               LISTEN     
tcp        0      0 VM_1_4_centos:33437     0.0.0.0:*               LISTEN     
tcp        0      0 VM_1_4_centos:50050     0.0.0.0:*               LISTEN     
tcp        0      0 VM_1_4_centos:10248     0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:46313           0.0.0.0:*               LISTEN     
tcp        0      0 VM_1_4_centos:10249     0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:sunrpc          0.0.0.0:*               LISTEN     
tcp6       0      0 [::]:30099              [::]:*                  LISTEN     
```

# ss(检测套接字)

```
$ ss -ta
State      Recv-Q Send-Q                                         Local Address:Port                                                          Peer Address:Port                
LISTEN     0      128                                                        *:ssh                                                                      *:*                    
LISTEN     0      32768                                              127.0.0.1:33437                                                                    *:*                    
LISTEN     0      32768                                              127.0.0.1:50050                                                                    *:*                    
LISTEN     0      32768                                              127.0.0.1:10248                                                                    *:*                    
LISTEN     0      64                                                         *:46313                                                                    *:*                    
LISTEN     0      32768                                              127.0.0.1:10249                                                                    *:*                    
LISTEN     0      128                                                        *:sunrpc                                                                   *:*                    
TIME-WAIT  0      0                                                172.16.3.65:48682                                                          172.16.3.75:websm                
ESTAB      0      0                                               172.16.252.1:54536                                                         172.16.252.1:https                
ESTAB      0      0                                                 10.168.1.4:46820                                                       169.254.128.15:60002                
ESTAB      0      0                                                 10.168.1.4:ssh                                                          163.177.68.35:11123                
ESTAB      0      0                                                 10.168.1.4:51178                                                         169.254.0.71:http                 
ESTAB      0      0                                               172.16.252.1:45940                                                         172.16.252.1:https    
```

显示所有活动的TCP连接以及计时器，运行以下命令：

```
$ ss -to
```

# ncat(nc)

ncat/nc既是一个端口扫描工具，也是一款安全工具，还是一款监测工具，甚至可以做为一个简单的TCP代理。 由于有这么多的功能，它被誉为是网络界的瑞士军刀。
安装

```
yum install nmap-ncat -y
```

监听某个端口的入站连接

```
ncat -l 80
```

连接远程服务器执行命令

```
ncat IP_address port_number

[root@VM-6-17-centos ~]# ncat 49.235.179.157 80
curl localhost  
HTTP/1.1 400 Bad Request
Server: nginx/1.16.1
Date: Fri, 28 Aug 2020 09:08:14 GMT
Content-Type: text/html
Content-Length: 157
Connection: close

<html>
<head><title>400 Bad Request</title></head>
<body>
<center><h1>400 Bad Request</h1></center>
<hr><center>nginx/1.16.1</center>
</body>
</html>
```

测试主机端口的连通性

```
[root@VM-6-17-centos ~]# ncat -v 49.235.179.157 22
Ncat: Version 7.50 ( https://nmap.org/ncat )
Ncat: Connected to 49.235.179.157:22.
SSH-2.0-OpenSSH_7.4
```

nc进行主机间通信聊天

```
[root@VM_0_13_centos ~]# ncat 42.194.143.131 8081
hello

[root@VM_1_4_centos ~]# ncat -l 8081
hello
```

# nmap(扫描主机)

扫描www.niewx.club这个地址的状态

```
[root@VM_1_4_centos ~]# nmap www.niewx.club

Starting Nmap 6.40 ( http://nmap.org ) at 2020-08-28 17:16 CST
Nmap scan report for www.niewx.club (49.235.179.157)
Host is up (0.029s latency).
Not shown: 992 filtered ports
PORT      STATE  SERVICE
20/tcp    closed ftp-data
21/tcp    closed ftp
22/tcp    open   ssh
80/tcp    open   http
443/tcp   open   https
3389/tcp  closed ms-wbt-server
5555/tcp  closed freeciv
55555/tcp closed unknown

Nmap done: 1 IP address (1 host up) scanned in 80.76 seconds
```

# iftop(查看流量)

```
yum install iftop -y
# iftop -i eth0
```

-i: 接口

-B: 以字节而非比特显示

![upload-image](/assets/images/blog/linux/2.png)

TX：发送流量

RX：接收流量

TOTAL：总流量

Cumm：运行iftop到目前时间的总流量

peak：流量峰值

rates：分别表示过去 2s 10s 40s 的平均流量


# trickle(限制带宽)

```
yum install trickle -y
```

这个应用用于限制网络带宽

1. 限制wget的上传和下载速度限制上传为10KB/S,下载为20KB/s

```
# trickle -u 10 -d 20 wget http://mirrors.163.com/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1503-01.iso
```

2. 单独限制某个进程的下载和上传速度

```
# trickle -s -d 50 -u 25 ftp
```

3. 限制终端下的所有命令带宽为，下载500KB/S，上传250KB/s;

```
# trickle -s -d 500 -u 250 bash
备注，单独命令使用时，必须加-s参数
```

# dstat(监控cpu内存)

```
yum install dstat -y
-c: 显示cpu综合占有率
-m: 显示内存使用情况
-n: 显示网络状况
-l：显示系统负载情况
-r：显示I/O请求(读/写)情况
[root@VM_1_4_centos ~]# dstat -ncmlr
-net/total- ----total-cpu-usage---- ------memory-usage----- ---load-avg--- --io/total-
 recv  send|usr sys idl wai hiq siq| used  buff  cach  free| 1m   5m  15m | read  writ
   0     0 |  8   2  90   0   0   0|6769M 1226M 6870M  661M|0.61 0.50 0.46|2.85  23.7 
  78k  141k|  2   2  95   0   0   0|6777M 1226M 6870M  653M|0.56 0.49 0.45|   0  25.0 
  71k   97k|  6   1  93   0   0   0|6771M 1226M 6870M  659M|0.56 0.49 0.45|   0  9.00 
 273k  235k|  7   1  92   0   0   0|6771M 1227M 6870M  659M|0.56 0.49 0.45|   0  32.0 
 214k  401k|  3   1  96   0   0   0|6771M 1227M 6870M  659M|0.56 0.49 0.45|   0  5.00 
 123k  132k|  2   1  97   0   0   0|6772M 1227M 6870M  658M|0.56 0.49 0.45|   0  35.0 
```

# tcpdump(网络抓包)

```
tcpdump [ -adeflnNOpqStvx ] [ -c 数量 ] [ -F 文件名 ]
　　　　　　　　　　[ -i 网络接口 ] [ -r 文件名] [ -s snaplen ]
                                       [ -T 类型 ] [ -w 文件名 ] [表达式 ]
 tcpdump的选项介绍
　　　-a 　　　将网络地址和广播地址转变成名字；
　　　-d 　　　将匹配信息包的代码以人们能够理解的汇编格式给出；
　　　-dd 　　　将匹配信息包的代码以c语言程序段的格式给出；
　　　-ddd 　　　将匹配信息包的代码以十进制的形式给出；
　　　-e 　　　在输出行打印出数据链路层的头部信息，包括源mac和目的mac，以及网络层的协议；
　　　-f 　　　将外部的Internet地址以数字的形式打印出来；
　　　-l 　　　使标准输出变为缓冲行形式；
　　　-n 　　　指定将每个监听到数据包中的域名转换成IP地址后显示，不把网络地址转换成名字；
     -nn：    指定将每个监听到的数据包中的域名转换成IP、端口从应用名称转换成端口号后显示
　　　-t 　　　在输出的每一行不打印时间戳；
　　　-v 　　　输出一个稍微详细的信息，例如在ip包中可以包括ttl和服务类型的信息；
　　　-vv 　　　输出详细的报文信息；
　　　-c 　　　在收到指定的包的数目后，tcpdump就会停止；
　　　-F 　　　从指定的文件中读取表达式,忽略其它的表达式；
　　　-i 　　　指定监听的网络接口；
      -p：    将网卡设置为非混杂模式，不能与host或broadcast一起使用
　　　-r 　　　从指定的文件中读取包(这些包一般通过-w选项产生)；
　　　-w 　　　直接将包写入文件中，并不分析和打印出来；
      -s snaplen         snaplen表示从一个包中截取的字节数。0表示包不截断，抓完整的数据包。默认的话 tcpdump 只显示部分数据包,默认68字节。
　　　-T 　　　将监听到的包直接解释为指定的类型的报文，常见的类型有rpc （远程过程调用）和snmp（简单网络管理协议；）
     -X            告诉tcpdump命令，需要把协议头和包内容都原原本本的显示出来（tcpdump会以16进制和ASCII的形式显示），这在进行协议分析时是绝对的利器。
```

1. 抓取包含10.10.10.122的数据包

```
# tcpdump -i eth0 -vnn host 10.10.10.122
```

2. 抓取包含10.10.10.0/24网段的数据包

```
# tcpdump -i eth0 -vnn net 10.10.10.0/24
```

3. 抓取包含端口22的数据包

```
# tcpdump -i eth0 -vnn port 22
```

4. 抓取udp协议的数据包

```
# tcpdump -i eth0 -vnn  udp
```

5. 抓取icmp协议的数据包

```
# tcpdump -i eth0 -vnn icmp
```

6. 抓取arp协议的数据包

```
# tcpdump -i eth0 -vnn arp
```

7. 抓取ip协议的数据包

```
# tcpdump -i eth0 -vnn ip
```

8. 抓取源ip是10.10.10.122数据包。

```
# tcpdump -i eth0 -vnn src host 10.10.10.122
```

9. 抓取目的ip是10.10.10.122数据包

```
# tcpdump -i eth0 -vnn dst host 10.10.10.122
```

10. 抓取源端口是22的数据包

```
# tcpdump -i eth0 -vnn src port 22
```

11. 抓取源ip是10.10.10.253且目的ip是22的数据包

```
# tcpdump -i eth0 -vnn src host 10.10.10.253 and dst port 22
```

12. 抓取源ip是10.10.10.122或者包含端口是22的数据包

```
# tcpdump -i eth0 -vnn src host 10.10.10.122 or port 22
```

13. 抓取源ip是10.10.10.122且端口不是22的数据包

```
# tcpdump -i eth0 -vnn src host 10.10.10.122 and not port 22
```

14. 抓取源ip是10.10.10.2且目的端口是22，或源ip是10.10.10.65且目的端口是80的数据包。

```
# tcpdump -i eth0 -vnn \( src host 10.10.10.2 and dst port 22 \) or   \( src host 10.10.10.65 and dst port 80 \)
```

15. 抓取源ip是10.10.10.59且目的端口是22，或源ip是10.10.10.68且目的端口是80的数据包。

```
[root@localhost ~]# tcpdump -i  eth0 -vnn 'src host 10.10.10.59 and dst port 22' or  ' src host 10.10.10.68 and dst port 80 '
```

16. 把抓取的数据包记录存到/tmp/fill文件中，当抓取100个数据包后就退出程序。

```
# tcpdump –i eth0 -vnn -w  /tmp/fil1 -c 100
```

17. 从/tmp/fill记录中读取tcp协议的数据包

```
# tcpdump –i eth0 -vnn -r  /tmp/fil1 tcp
```

18. 从/tmp/fill记录中读取包含10.10.10.58的数据包

```
# tcpdump –i eth0 -vnn -r  /tmp/fil1 host  10.10.10.58
```

# curl(发送请求)

```
curl www.baidu.com
```

也可以保存源码 用curl -O 文件名 url，这个和wget类似

```
curl -O baidu.txt wwww.baidu.com
```

显示网页头部信息 用-i,当然也会把网页信息显示出来

```
[root@VM_0_11_centos training]# curl -i www.baidu.com
HTTP/1.1 200 OK
Accept-Ranges: bytes
Cache-Control: private, no-cache, no-store, proxy-revalidate, no-transform
Connection: keep-alive
Content-Length: 2381
Content-Type: text/html
Date: Thu, 02 Apr 2020 02:14:33 GMT
Etag: "588604c8-94d"
Last-Modified: Mon, 23 Jan 2017 13:27:36 GMT
Pragma: no-cache
Server: bfe/1.0.8.18
Set-Cookie: BDORZ=27315; max-age=86400; domain=.baidu.com; path=/

<!DOCTYPE html>
 xxx
  </html> 
```

参数 -v可以显示通信的过程：

```
[root@VM_0_11_centos training]# curl -v www.baidu.com
* About to connect() to www.baidu.com port 80 (#0)
*   Trying 180.101.49.11...
* Connected to www.baidu.com (180.101.49.11) port 80 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.29.0
> Host: www.baidu.com
> Accept: */*
> 
< HTTP/1.1 200 OK
< Accept-Ranges: bytes
< Cache-Control: private, no-cache, no-store, proxy-revalidate, no-transform
< Connection: keep-alive
< Content-Length: 2381
< Content-Type: text/html
< Date: Thu, 02 Apr 2020 02:16:36 GMT
< Etag: "588604c8-94d"
< Last-Modified: Mon, 23 Jan 2017 13:27:36 GMT
< Pragma: no-cache
< Server: bfe/1.0.8.18
< Set-Cookie: BDORZ=27315; max-age=86400; domain=.baidu.com; path=/
<
```

更详细的通信信息可以用 参数 --trance 文件名 url,具体信息保存到单独的文件中

```
[root@VM_0_11_centos training]# curl --trace info.txt www.baidu.com
```

htpp的动词，例如GET POST，PUT，DELETE等,需要参数 -X

curl默认的是get请求，如果发送POSt请求

```
curl -X POST www.baidu.com
```

发送表单的时候，GET很简单 只需要把数据拼接到url后面就行

```
curl www.baidu.com?data=xxx&data1=xxx
```

POST也不难

```
curl -X POST --data "data=xxx" example.com/form.cgi
```

POST发送请求的数据体可以用-d

```
$ curl -d'login=emma＆password=123'-X POST https://google.com/login
 或者
$ curl -d 'login=emma' -d 'password=123' -X POST  https://google.com/login
```

使用-d参数以后，HTTP 请求会自动加上标头Content-Type : application/x-www-form-urlencoded。并且会自动将请求转为 POST 方法，因此可以省略-X POST。-d参数可以读取本地文本文件的数据，向服务器发送。

```
$ curl -d '@data.txt' https://google.com/login
```

上面命令读取data.txt文件的内容，作为数据体向服务器发送。
文件上传： 假定文件上传的表单是下面这样：

```
　<form method="POST" enctype='multipart/form-data' action="upload.cgi">
　　　　<input type=file name=upload>
　　　　<input type=submit name=press value="OK">
　　</form>
```

curl上传就应该是：

```
curl --form upload=@localfilename --form press=OK [URL]
```

--referer参数表示的是你从哪个页面来的

```
[root@VM_0_11_centos training]# curl --referer www.baidu.com www.baidu.com
```

User Agent字段，这个字段表示的是客户端设备的信息，服务器可能会根据这个User Agent字段来判断是手机还是电脑

```
curl --user-agent " xx" url
比如IPhone 
Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) 
AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5


 curl --user-agent "Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) 
 AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5"  www.baidu.com
```

* --user-agent 可以用-A或者-H来替代
* --cookie参数，使用--cookie可以携带cookie信息

```
curl --cookie "name=xxx" URL
 `-c cookie-file`可以保存服务器返回的cookie到文件，
 `-b cookie-file`可以使用这个文件作为cookie信息，进行后续的请求。
```

增加头部信息 --header

```
curl --header "Content-Type:application/json" http://example.com
```


# 参考链接

<https://www.jianshu.com/p/39b9d66c9dbf>

<https://www.toutiao.com/i6812988437512061452/>
<https://www.toutiao.com/i6850221908475003405/>