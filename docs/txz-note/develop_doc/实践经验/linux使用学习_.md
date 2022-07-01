linux使用学习

### 一、计算机概论

#### **1.操作系统基础概念**

##### **操作系统由五大部分组成**：

- 运算器：处理数据的算术运算和逻辑运算得到结果
- 控制器：协调控制程序之间的执行逻辑
- 存储器：暂时存储程序、信号、命令的等信息，等待被使用
- 输入设备：鼠标、键盘等外设
- 输出设备：显示器、打印机、刻录机等

##### **基础单位换算**：

计算数据由二进制编写而成，一个二进制的单位称为1比特(bit)，由于bit只能存储0和1，能够代表的意义过于单一，所以存储数据一般以8个比特为一个存储单元，我们称这个存储单元为一个字节(Byte)

```
1 Byte = 8 bits
```

由于字节单位还是过小，于是就有了之后的1024位的进位关系：

```java
1024Byte = 1K
1024K = 1M
1024M = 1G
1024G = 1T
1024T = 1P
1024P = 1E
```

======================

PS：硬盘制作商会采用10进制来计算硬盘的大小，如一个500G的硬盘的实际空间只有460G左右，并不是偷工减料了，而是500G = 1000 * 1000 * 1000Bytes，转化成以1024Bytes的二进制单位时，就是460G左右了。至于为啥要使用十进制单位，简单解释就是硬盘的最小组成单位是一个扇区，而硬盘容器的计算采用“多个扇区来计算”,所以采用十进制处理(注意：硬盘的最小物理量为512Bytes)。

==================

#### 2.Oracle VM安装虚拟机：

1.打开主界面后点击新增

![image-20210422145751460](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422145759.png)

2，一直默认下一步，设置虚拟磁盘大小：

![image-20210422145920280](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422145920.png)

3.安装完成后创建一个空的虚拟机模板，此时，这个模板还是空的，需要我们吧一个linux.iso系统安装到这个模板中：

右键点击设置，移动到存储选择，添加centos.iso到控制器：

![image-20210422150226785](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422150226.png)

之后点击网络设置联网方式，这里设置的是桥接模式(注意网卡的选择，需要和宿主机保存一致)：

由于本人使用的wifi网卡，所以选择的802.11ac无线网卡

![image-20210422152108980](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422152109.png)

设置好后的配置如下：

![image-20210422150410738](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422150410.png)

4.之后我们启动这个虚拟机，开始安装操作系统：

![image-20210422150504704](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422150504.png)

一直下一步就好

5.安装好后，开始配置系统：

![image-20210422150842782](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422150842.png)

选择语言和时间：

![image-20210422151309967](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422151310.png)

配置系统安装的磁盘位置和网络连接配置：
![image-20210422151544506](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422151544.png)

选择安装磁盘：

![image-20210422151637154](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422151637.png)

开启网络IP配置：

![image-20210422151841101](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422151841.png)

之后点击开始安装就行了，并且可以设置管理员密码。

安装完成后会重启，重启后我们可以通过&lt;root/设置的密码&gt;访问系统了：

![image-20210422152443653](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422152443.png)

执行命令安装网络工具yum install net-tools

安装成功后使用ifconfig查询网络状况：

![image-20210422153511018](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422153511.png)

并且宿主机和虚拟机可以互相ping通:

![image-20210422153737313](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210422153737.png)

==================

#### 3.CPU占用率100%如何排查处理？

1.通过top命令获取cpu=100%的进程pid

2.通过top -Hp [pid]获取进程中占内存最高的线程pid

3.将上面的线程pid转为16进制，例如printf "%x\n" 16756，得到的16进制是0x4174

4.通过jstack \[pid\] >ThreadInfo.txt导出进程的线程状况，或者筛选执行jstack [进程pid] | grep '0x4174' -C10 --color

![image-20210806161952521](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210806161952.png)

5.通过ps -mp \[pid\] -o THREAD,tid,time等命令查询哪一个线程cpu占用高

6.将线程的TID转换为16进制后，和ThreadInfo.txt中的NID进行对比，找到线程栈中的代码位置

============

另一种方式：

1.top -c 查看所有进程

2.键入P 按照cpu的使用率从上到下排序

3.根据第2步拿到的pid 执行top -Hp pid 查看pid对应的线程cpu使用率

4.键入P 线程CPU的消耗从大到小排序

5.选择第四步中最耗CPU的线程id

6.由于Linux中线程id的打印是16进制,将线程id转为16进制，printf “%x” tid

7.打印线程id对应的jstack日志 jstack pid │ grep tid -C 5 --color ：输出指定pid的线程jstack日志，过滤筛选指定的线程id，找到位置后前后打印5行 满足条件的tid字段线程颜色

8.根据堆栈线程找到对应的代码行

参考：https://www.jianshu.com/p/9f3d64205ee6

#### 4.NAT网络访问问题

Nat模式下，虚拟机可以使用宿主机的网络，所以可以直接ping通宿主机，而宿主机访问虚拟机则可以通过端口转发来访问虚拟机：

![image-20211008173820247](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110081738369.png)

192.168.152.222地址是宿主机的局域网地址，通过配置2222端口和虚拟机的22端口映射，这样可以通过宿主机直接访问2222端口来转发到虚拟机的22端口上

#### 5. NAT网络访问独立IP

创建一个本地网络适配器并开启DHCP（一般默认选择手动配置网卡就行）：

![image-20211008180831479](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110081808977.png)

之后在全局设置中配置多个NAT网络地址：

![image-20211008181013652](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110081810253.png)

之后在虚拟机的网络设置中配置2个网络设置(NAT网络一个虚拟机一个地址)：

![image-20211008181149266](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110081811318.png)

网卡2的配置（公用同一个适配器地址）：

![image-20211008181210949](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110081812980.png)

这样启动虚拟机就会根据DHCP自动的进行IP分配了，在虚拟机中我们可以直接访问宿主机的IP：

![image-20211008181401253](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110081814296.png)

同时在宿主机中也可以直接ping通分配的虚拟机IP：

![image-20211008181448630](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110081814665.png)

如果有多个虚拟机，则后面的虚拟机需要删除/etc/sysconfig/netwrok-scripts/ifcfg-enp0s8,并重启，这样才会自动分配IP，或者直接在ifcfg-enp0s8中自定义配置IP地址：

```
ONBOOT=
IPADDR=192.168.152.222
NETMASK=255.255.255.0
BROADCAST=192.168.152.1
```



#### 6.桥接网络连通问题

虚拟机创建流程：

https://blog.csdn.net/weixin_42385705/article/details/103064124

处理ping不通虚拟机问题：

https://www.kafan.cn/edu/9891581.html

https://www.cnblogs.com/dbslinux/p/12982385.html

处理虚拟机ping不通宿主机问题：

主机防火墙打开请求规则

![image-20210414193403832](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210414193403.png)

处理没有host only适配器问题：

https://blog.csdn.net/zlt995768025/article/details/79986744

处理虚拟机网段不同问题：

https://blog.csdn.net/zhanglei082319/article/details/95923117

处理虚拟机设置无法设置适配器：

https://www.cnblogs.com/youmin3205/p/11727138.html