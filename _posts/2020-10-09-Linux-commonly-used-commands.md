---
title: Linux中常用命令和知识
author: VashonNie
date: 2020-10-09 22:28:00 +0800
updated: 2020-10-09 22:28:00 +0800
categories: [linux,Shell]
tags: [linux]
math: true
---

作为一个运维人员，linux命令和shell脚本是必不可少，本篇文章简要介绍在运维过程中一些常用的linux命令和脚本一些语法。

## 安装rpm包到指定路径
rpm -ivh --prefix=/java  xx.rpm
## 修改git上一次提交记录
git commit --amend
## 全局替换命令
%s/home/\/home\/rcs/g
## rpm包命令
解压命令：rpm2cpio xxx.rpm | cpio -idmv

安装命名：rpm -ivh --nodeps xxx.rpm

卸载命令：rpm -e xxx

查看命名：rpm -qa | grep xxx
## 查看I/O命令
iostat -t 3 
## 生成线程分析文件
jmap -dump:live,format=b,file=swa8.bin PID（top查看）
## 查找某个类所属的包：
grep -l "com/huawei/payment/console/id/IdTool" * -R

grep "com.huawei.payment.ag.socket.iso8583.template.ISOBasicConfig" * -R

git查看多少天文件的变化：git whatchanged --since="100 days ago"
## 查看文件的CRC值
cksum file （可以根据CRC值判断文件是否有变化）
## 重启sshd服务
/etc/init.d/sshd restart
## 查找某个文件的值
find ./ -name cps.beanconf.properties | xargs grep "Cps.Bean.CustomizePolicy=*"
## 查看suse版本号
lsb_release -d
## 解压tar.gz包到指定路径
tar -zxvf jdk\-8u71\-linux\-x64.tar.gz -C /home/ci/nwx/targz/temp
## 替换多个文件内容
find ./ -name cps.datasource.xml | xargs sed -i 's/10.62.172.249/10.62.159.192/g'
## 不挂断某个命令
nohup command &
## 查看某个端口所建立的连接
netstat -an | grep 31100
## 查看system信息
jinfo pid
## 查看目录文件的个数
ls -l|grep "^-"| wc -l
## 查看目录空间使用情况
du -sh * | sort -n
## 通过其他用户执行命令
su - $tomcatuse -c "cd tools;stop.sh -y&"
## 查看某个文件的大小
du -k ${logfilepath}/${log_module_name}_${logfile} | awk -F ' ' '{print $1}'
## 检查文件sha256sum
sha256sunm test.txt>test.txt.sha256sum
sha256sum -c <(grep test.txt test.txt.sha256sum)
## 检查文件的md5值
md5sum test1 test2 >tmp.test
md5sum -c tem.test		   
## 浮点数的计算
ab=\`echo "scale=5;a=1/3;if(length(a)==scale(a)) print 0;print a"|bc`
## 提取字符串中的数字
echo "2014年7月21日" | tr -cd "[0-9]"
## 往文件的某一行中追加字符
sed -i "0,/^AllowGroups.*/s//& wheel/" $sshd_config
## 替换yaml中的镜像名
tag=$(date +"%Y%m%d-%H%M%S")

newimage=106.54.126.251:5000/sprintboot:$tag

sed -i "s#image: .*#image: $newimage#g" /opt/k8s/nginx.yaml
## 获取一行的第n个字段到最后一个字段
log_content=\`echo "$line" | awk '{for (i=7 ;i<=NF;i++) printf $i " "; printf "\n" }'`
## Exit和return的区别
（1）作用不同。exit用于在程序运行的过程中随时结束程序，exit的参数是返回给OS的。exit是结束一个进程，它将删除进程使用的内存空间，同时把错误信息返回父进程。而return是返回函数值并退出函数；

（2）语义层级不同。return是语言级别的，它表示了调用堆栈的返回；而exit是系统调用级别的，它表示了一个进程的结束；

（3）使用方法不用。return一般用在函数方法体内，exit可以出现在Shell脚本中的任意位置。
## >/dev/null 2>&1
2>&1，将错误输出绑定到标准输出上。由于此时的标准输出是默认值，也就是输出到屏幕，所以错误输出会输出到屏幕。

\>/dev/null，将标准输出1重定向到/dev/null中。
## 获取字符串的第1个字符
first_character=\`echo ${line:0:1}`
## 大于小于英文
-ne —比较两个参数是否不相等

-lt —参数1是否小于参数2

-le —参数1是否小于等于参数2

-gt —参数1是否大于参数2

-ge —参数1是否大于等于参数2
## grep参数的用法
![upload-image](/assets/images/blog/linux-command/1.png) 

## ssh-copy-id
ssh-copy-id命令可以把本地主机的公钥复制到远程主机的authorized_keys文件上，

ssh-copy-id命令也会给远程主机的用户主目录（home）和~/.ssh, 和~/.
ssh/authorized_keys设置合适的权限。

使用模式：
ssh-copy-id [-i [identity_file]] [user@]machine
 
描述：  
ssh-copy-id 是一个实用ssh去登陆到远程服务器的脚本（假设使用一个登陆密码，因此，密码认证应该被激活直到你已经清理了做了多个身份的使用）。
它也能够改变远程用户名的权限，~/.ssh和~/.ssh/authorized_keys
删除群组写的权限（在其它方面，如果远程机上的sshd在它的配置
文件中是严格模式的话，这能够阻止你登陆。）。
 
如果这个 “-i”选项已经给出了，然后这个认证文件（默认是~/.ssh/id_rsa.pub）被使用，不管在你的ssh-agent那里是否有任何密钥。另外，命令 “ssh-add -L” 提供任何输出，它使用这个输出优先于
身份认证文件。如果给出了参数“-i”选项，或者ssh-add不产生输出，
然后它使用身份认证文件的内容。一旦它有一个或者多个指纹，它使
用ssh将这些指纹填充到远程机~/.ssh/authorized_keys文件中。
## split切割文件
```
先使用 dd 命令来生成一个 700MB 文件来作为我们的拆分对象：
[root@roclinux ~]$ dd if=/dev/zero bs=1024 count=700000 of=king_of_ring.avi
700000+0 records in
700000+0 records out
716800000 bytes (717 MB) copied, 12.9189 s, 55.5 MB/s
[root@roclinux ~]$  ls -l king_of_ring.avi
-rw-r--r-- 1 root root 716800000 Apr 12 13:01 king_of_ring.avi

这里使用到了 split 的-b选项，来指定每个拆分文件的大小：  
[root@roclinux ~]$ split -b 400M king_of_ring.avi  
[root@roclinux ~]$ ls -l  
total 1400008  
-rw-r--r-- 1 root root 716800000 Apr 12 13:01 king_of_ring.avi  
-rw-r--r-- 1 root root 419430400 Apr 12 13:04 xaa    
-rw-r--r-- 1 root root 297369600 Apr 12 13:04 xab

默认情况下，分割后的文件的名称会以 x 作为前缀，以 aa、ab、ac 这样的双字母格式作为后缀，形成 xaa、xab 这样的名称格式。

我们来一起看看 split 的命令格式：
split [-b ][-C ][-][-l ][要切割的文件][输出文件名前缀][-a ]
最常用的选项，都在这里了：  
-b<字节>：指定按多少字节进行拆分，也可以指定 K、M、G、T 等单位。
-<行数>或-l<行数>：指定每多少行要拆分成一个文件。  
输出文件名前缀：设置拆分后的文件的名称前缀，split 会自动在前缀后加上编号，默认从 aa 开始。  
-a<后缀长度>：默认的后缀长度是 2，也就是按 aa、ab、ac 这样的格式依次编号。  

使用 cat 命令将拆分文件 xaa 和 xab 合并成一个文件，可以看出合并后的文件和源文件的大小是一致的：  
[root@roclinux ~]$ cat xaa xab > king_of_ring_merge.avi
 
[root@roclinux ~]$ ls -l  
total 2100012  
-rw-r--r-- 1 root root 716800000 Apr 12 13:01 king_of_ring.avi  
-rw-r--r-- 1 root root 716800000 Apr 12 13:07   king_of_ring_merge.avi   
-rw-r--r-- 1 root root 419430400 Apr 12 13:04 xaa  
-rw-r--r-- 1 root root 297369600 Apr 12 13:04 xab  

对了，如果是在 Windows 下的话，我们要先运行 cmd，然后用 copy 命令来进行文件的合并：
copy /b xaa + xab king_of_ring.avi
格式上和 Linux 有些区别，但原理是一样的。
设置拆分文件的名称前缀
下面的例子，我们尝试以 king_of_ring_part_ 作为拆分后文件的名称前缀：
我们指定了king_of_ring_part_前缀
[root@roclinux ~]$ split -b 400m king_of_ring.avi king_of_ring_part_
 
可以看到, 文件名的可读性提高了很多
[root@roclinux ~]$ ls -l king*
-rw-r--r-- 1 root root 716800000 Feb 25 18:29 king_of_ring.avi
-rw-r--r-- 1 root root 419430400 Feb 25 19:24 king_of_ring_part_aa
-rw-r--r-- 1 root root 297369600 Feb 25 19:24 king_of_ring_part_ab

设置数字后缀
如果大家看不惯以 aa、ab 这种字母作为文件后缀，我们还可以通过-d选项来指定数字形式的文件后缀：
使用了-d选项
[root@roclinux ~]$ split -b 400m -d king_of_ring.avi king_of_ring_part_
 
后缀从原来的aa、ab变成了00、01
[root@roclinux ~]$ ls -l king*
-rw-r--r-- 1 root root 716800000 Feb 25 18:29 king_of_ring.avi
-rw-r--r-- 1 root root 419430400 Feb 25 19:24 king_of_ring_part_00
-rw-r--r-- 1 root root 297369600 Feb 25 19:24 king_of_ring_part_01


按照行数进行拆分
前面我们讲的是按照文件大小（如 400MB）进行文件拆分的方法，但是并非所有情况都适合于用文件大小作为拆分单元。比如，我们希望把 /etc/passwd 文件按照一个文件 10 行记录的方式进行拆分，又该怎么操作呢？
使用-N来指定拆分的行数,本例中为-10
[root@roclinux ~]$ split -d -10 /etc/passwd my_passwd_
可以看到拆分成功
[root@roclinux ~]$ wc -l my_passwd_*
  10 my_passwd_00
  10 my_passwd_01
   5 my_passwd_02
  25 total

#对原先的文件计算md5值
[root@roclinux ~]$ md5sum king_of_ring.avi
eacff27bf2db99c7301383b7d8c1c07c  king_of_ring.avi
 
#对合并后的文件计算md5值, 并与原值进行比较
[root@roclinux ~]$ md5sum king_of_ring_merge.avi
eacff27bf2db99c7301383b7d8c1c07c  king_of_ring_merge.avi
如果前后一致，那么恭喜你，文件合并成功！
```

## 随机生成12位密码
PassWd=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 12 | tr -d "\n";echo)

## test命令
Shell中的 test 命令用于检查某个条件是否成立，它可以进行数值、字符和文件三个方面的测试。

数值测试
参数	说明  
-eq  &emsp;等于则为真  
-ne	 &emsp;不等于则为真  
-gt	 &emsp;大于则为真  
-ge	 &emsp;大于等于则为真  
-lt	&emsp;小于则为真  
-le	    &emsp;小于等于则为真  

字符串测试
参数	说明  
=	等于则为真  
!=	不相等则为真  
-z 字符串	字符串的长度为零则为真  
-n 字符串	字符串的长度不为零则为真  

文件测试
参数	说明  
-e 文件名	如果文件存在则为真  
-r 文件名	如果文件存在且可读则为真  
-w 文件名	如果文件存在且可写则为真  
-x 文件名	如果文件存在且可执行则为真  
-s 文件名	如果文件存在且至少有一个字符则为真  
-d 文件名	如果文件存在且为目录则为真  
-f 文件名	如果文件存在且为普通文件则为真  
-c 文件名	如果文件存在且为字符型特殊文件则为真  
-b 文件名	如果文件存在且为块特殊文件则为真  

## sudo执行echo命令
$ echo 3 | sudo tee /proc/sys/vm/drop_caches
## 查看cpu数量
cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc –l

## let命令
let 命令是 BASH 中用于计算的工具，用于执行一个或多个表达式，变量计算中不需要加上 $ 来表示变量。如果表达式中包含了空格或其他特殊字符，则必须引起来。  
let a=5+4  
let b=9-3  

## shift命令
从上可知 shift(shift 1) 命令每执行一次，变量的个数($#)减一（之前的$1变量被销毁,之后的$2就变成了$1），而变量值提前一位。同理，shift n后，前n位参数都会被销毁，比如：  
输入5个参数： abcd e
那么$1=a,$2=b,$3=c,$4=d,$5=e,执行shift 3操作后，前3个参数a、b、c被销毁，就剩下了2个参数：d,e（这时d=$1,e=$2，其中d由$4—>$1,e由$5—>$2）

## 获取所有参数中的第m个后面的n个参数
${variable:offset:length}   
获得variable值位置从offset开始长度为length的子串。

${@:m:n}  
m表示从第m个参数开始（从1开始），n表示输出m参数后面的n个参数

例子

```
a b c d e f g h   
${@:3:2}  
输出结果：c d   

test.sh  
aaaaaa=(${@:2:4}); shift 2  
echo $aaaaaa

sh test.sh    
a b c d e f g
结果：输出b
```
## linux下进程通讯的8中方法
Linux下进程通信的八种方法：管道(pipe)，命名管道(FIFO)，内存映射(mapped memeory)，消息队列(message queue)，共享内存(shared memory)，信号量(semaphore)，信号(signal)，套接字(Socket)
(1) 管道（pipe）：管道允许一个进程和另一个与它有共同祖先的进程之间进行通信；  
(2) 命名管道（FIFO）：类似于管道，但是它可以用于任何两个进程之间的通信，命名管道在文件系统中有对应的文件名。命名管道通过命令mkfifo或系统调用mkfifo来创建；  
(3) 信号（signal）：信号是比较复杂的通信方式，用于通知接收进程有某种事情发生，除了用于进程间通信外，进程还可以发送信号给进程本身；Linux除了支持UNIX早期信号语义函数signal外，还支持语义符合POSIX.1标准的信号函数sigaction(实际上，该函数是基于BSD的，BSD即能实现可靠信号机制，又能够统一对外接口，用sigaction函数重新实现了signal函数的功能);  
(4) 内存映射（mapped memory）：内存映射允许任何多个进程间通信，每一个使用该机制的进程通过把一个共享的文件映射到自己的进程地址空间来实现它；  
(5) 消息队列（message queue）：消息队列是消息的连接表，包括POSIX消息对和System V消息队列。有足够权限的进程可以向队列中添加消息，被赋予读权限的进程则可以读走队列中的消息。消息队列克服了信号承载信息量少，管道只能成该无格式字节流以及缓冲区大小受限等缺点；  
(6) 信号量（semaphore）：信号量主要作为进程间以及同进程不同线程之间的同步手段；  
(7) 共享内存 （shared memory）：它使得多个进程可以访问同一块内存空间，是最快的可用IPC形式。这是针对其他通信机制运行效率较低而设计的。它往往与其他通信机制，如信号量结合使用，以达到进程间的同步及互斥；  
(8) 套接字（Socket）：它是更为通用的进程间通信机制，可用于不同机器之间的进程间通信。起初是由UNIX系统的BSD分支开发出来的，但现在一般可以移植到其他类UNIX系统上：Linux和System V的变种都支持套接字。

## 使用sed在文件中插入带有变量的字符串
解决方式为：sed -i '10i-A INPUT -m state --state NEW -m tcp -p tcp --dport '$port' -j ACCEPT' /etc/sysconfig/iptables

授人以鱼不如授人以渔，产生问题的原因是：
因为 $port 是shell变量而不是sed中的变量，需要单独拿到 sed 的单引号外面来才能被 shell 解析。单引号里面是 sed 的势力范围，shell 无法触及。
sed的参数后的命令，是以单引号开始，单引号结束的，所以想将shell变量拿出来，那就在变量前面加个单引号让sed命令结束，再在变量后面再加个单引号让sed命令再开始
## Shell中要如何调用别的脚本，变量，函数
方法一:   . ./subscript.sh  
方法二:   source ./subscript.sh  
注意:
1.两个点之间，有空格，千万注意.  
2.两个脚本不在同一目录，要用绝对路径  
3.为简单起见，通常用第一种方法  
## Shell中获取脚本最后一个参数
echo ${@:${#@}}
## Shell中连续输出n个数
 [root@master ~]# echo a-{0..11}  
a-0 a-1 a-2 a-3 a-4 a-5 a-6 a-7 a-8 a-9 a-10 a-11
## 查看内存占比
ps -eo pmem,pcpu,rss,vsize,args | sort -k 1 -r

 

