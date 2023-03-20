### MQ的核心Topic

Topic是MQ中间件的核心数据集合，生产者想要发送数据到MQ中，就得发送到Topic中，Topic需要在MQ中先进行创建，创建时需要对Topic进行命名，这个命名需要唯一，作为生产者，MQ，消费者之间关联的key使用。

例如，我创建了一个Topic名为product_info_topic，生产者可以根据这个key将数据推送到MQ中的Topic中，消费者也可以根据key从MQ中的Topic中拉取消费数据。

Topic数据集合是一个逻辑概念，存储在Broker中，每次Broker发送心跳数据给NameServer时，也会将Broker中的topic信息也都发送到NameServer，这样NameServer就清楚每个Broker中存放着什么数据了。

### 生产者如何将信息推到Broker中？

![image-20230314155048489](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303141550771.png)

生产者在与NameServer构建连接后，会拉取最新的broker地址列表和topic信息，以及各topic分布在broker中各服务器中的情况。当生产者需要将信息推送到MQ时，会根据topic命名获取这个topic分布的broker地址列表信息，然后通过某个算法路由选择一台broker的ip地址，将信息推送到这台broker中，broker收到信息后会将信息持久化到磁盘，同时会将信息同步给Slave broker节点。

### 消费者如何从Broker中拉取信息？

和生产者类似，消费者会先从NaneServer中拉取broker地址列表和topic信息，然后根据topic选择一台broker建立长连接，之后等待消息信息，如果发现有新消息写入MQ，则会拉取到消费端应用进行消费。

完整架构图如下：

![image-20230314164258623](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202303141642696.png)

NameServer集群部署，高可用，Slave Broker挂了对集群没有影响，Master Broker挂了会有Dledger技术选出一个Slave Broker成为新Master Broker，所以整个MQ都是高可用的。

架构配置：

1. NameServer：3台机器，每台机器都是8核CPU + 16G内存 + 500G磁盘 + 千兆网卡
2. Broker：6台机器，每台机器都是24核CPU（两颗x86_64 cpu，每颗cpu是12核） + 48G内存 + 1TB磁盘 + 千兆网卡（构成两个高可用broker节点，一个节点挂两个从节点）
3. 生产者：2台机器，每台机器都是4核CPU + 8G内存 + 500GB磁盘 + 千兆网卡
4. 消费者：2台机器，每台机器都是4核CPU + 8G内存 + 500GB磁盘 + 千兆网卡

### MQ的OS内核参数和jvm参数应该怎么设置？

linux os参数：

**vm.overcommit_memory**
该参数取值0/1/2

当值为0时，JVM进程启动申请物理内存时，如果物理内存不足，那么会拒绝进程的内存申请，这样进程就会报错

当值为1时，代表所有的物理内存都允许被进程申请，一般需要手动将这个os参数改为1，操作命令如下：

```
echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf
```

**vm.max_map_count**
该参数会影响JVM进程能申请的最大线程数，默认值是65536

如果该值设置过小，会导致进程中开启新线程失败，甚至直接让进程挂掉

建议将该值配置扩大10倍，保证进程可以开启足够的线程数，修改命令如下：

```
echo 'vm.max_map_count=655360' >> /etc/sysctl.conf
```

**vm.swappiness**

这个参数是用来控制进程的swap行为，在Linux中系统，会在磁盘中创建一个swap区域，当一个进程行为不太活跃时，就会将这个进程调整为睡眠状态，然后将这个进程占用的物理内存移动到swap区域，以此来释放出更多的物理内存给其他活跃进程使用。

这个参数默认值为60，如果值设置为0，代表代表尽量不把进程放入swap区域。如果值设置为100，代表尽量把不活跃的进程放入swap区域，由于默认值60比较高，可以适当把这个数值调低一些，比如设置为10或20，尽量用物理内存，别放磁盘swap区域去，操作命令如下：

```
echo 'vm.swappiness=10' >> /etc/sysctl.conf
```

**ulimit**
这个参数会限制进程同时操作磁盘文件的上限数量，也就是控制linux上的最大文件链接数，如果进程会有大量的网络IO或磁盘IO去写入文件，达到了ulimit参数的上限，那么操作就会报错，出现error: too many open files的错误日志，建议将这个参数调大，操作命令如下：

```
echo 'ulimit -n 1000000' >> /etc/profile
```

**MQ的JVM参数配置**

**-server**：这个参数就是说用服务器模式启动，这个没什么可说的，现在一般都是如此

**-Xms8g -Xmx8g -Xmn4g**：这个就是很关键的一块参数了，也是重点需要调整的，就是默认的堆大小是8g内存，新生代是4g内存，但是我们的高配物理机是48g内存的

所以这里完全可以给他们翻几倍，比如给堆内存20g，其中新生代给10g，甚至可以更多一些，当然要留一些内存给操作系统来用

**-XX:+UseG1GC -XX:G1HeapRegionSize=16m**：这几个参数也是至关重要的，这是选用了G1垃圾回收器来做分代回收，对新生代和老年代都是用G1来回收

这里把G1的region大小设置为了16m，这个因为机器内存比较多，所以region大小可以调大一些给到16m，不然用2m的region，会导致region数量过多的

**-XX:G1ReservePercent=25**：这个参数是说，在G1管理的老年代里预留25%的空闲内存，保证新生代对象晋升到老年代的时候有足够空间，避免老年代内存都满了，新生代有对象要进入老年代没有充足内存了

默认值是10%，略微偏少，这里RocketMQ给调大了一些

**-XX:InitiatingHeapOccupancyPercent=30**：这个参数是说，当堆内存的使用率达到30%之后就会自动启动G1的并发垃圾回收，开始尝试回收一些垃圾对象

默认值是45%，这里调低了一些，也就是提高了GC的频率，但是避免了垃圾对象过多，一次垃圾回收耗时过长的问题

**-XX:SoftRefLRUPolicyMSPerMB=0**：这个参数默认设置为0了，在JVM优化专栏中，救火队队长讲过这个参数引发的案例，其实建议这个参数不要设置为0，避免频繁回收一些软引用的Class对象，这里可以调整为比如1000

**-verbose:gc -Xloggc:/dev/shm/mq_gc_%p.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -XX:+PrintAdaptiveSizePolicy -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=30m**：这一堆参数都是控制GC日志打印输出的，确定了gc日志文件的地址，要打印哪些详细信息，然后控制每个gc日志文件的大小是30m，最多保留5个gc日志文件。

**-XX:-OmitStackTraceInFastThrow**：这个参数是说，有时候JVM会抛弃一些异常堆栈信息，因此这个参数设置之后，就是禁用这个特性，要把完整的异常堆栈信息打印出来

**-XX:+AlwaysPreTouch**：这个参数的意思是我们刚开始指定JVM用多少内存，不会真正分配给他，会在实际需要使用的时候再分配给他

所以使用这个参数之后，就是强制让JVM启动的时候直接分配我们指定的内存，不要等到使用内存的时候再分配

**-XX:MaxDirectMemorySize=15g**：这是说RocketMQ里大量用了NIO中的direct buffer，这里限定了direct buffer最多申请多少，如果你机器内存比较大，可以适当调大这个值，如果有朋友不了解direct buffer是什么，可以自己查阅一些资料。

**-XX:-UseLargePages -XX:-UseBiasedLocking**：这两个参数的意思是禁用大内存页和偏向锁，这两个参数对应的概念每个要说清楚都得一篇文章，所以这里大家直接知道人家禁用了两个特性即可。

**MQ应用参数配置**

配置文件位置

rocketmq/distribution/target/apache-rocketmq/conf/dledger

在这里主要是有一个较为核心的参数：**sendMessageThreadPoolNums=16**

这个参数的意思就是RocketMQ内部用来发送消息的线程池的线程数量，默认是16

其实这个参数可以根据你的机器的CPU核数进行适当增加，比如机器CPU是24核的，可以增加这个线程数量到24或者30，都是可以的。

**MQ压测要点**

要达到一个QPS和机器负载的一个平衡是最佳压测强度，没必要直接极限压测，将CPU、内存都干到快100%，这个QPS量级一般是应用的上限。我们在压测的时候，可以监控各应用机器负载的上升状况，当机器平均的CPU、内存稳定达到70%上下时，就可以认为这个QPS量级就是应用的最佳负载状况。

**MQ压测方式**

我们让两个Producer不停的往RocketMQ集群发送消息，每个Producer所在机器启动了80个线程，相当于每台机器有80个线程并发的往RocketMQ集群写入消息。

然后有2个Cosumer不停的从RocketMQ集群消费数据。

每条数据的大小是500个字节，**这个非常关键**，大家一定要牢记这个数字，因为这个数字是跟后续的网卡流量有关的。

我们发现，一条消息从Producer生产出来到经过RocketMQ的Broker存储下来，再到被Consumer消费，基本上这个时间跨度不会超过1秒钟，这些这个性能是正常而且可以接受的。

同时在RocketMQ的管理工作台中可以看到，Master Broker的TPS（也就是每秒处理消息的数量），可以稳定的达到7万左右，也就是每秒可以稳定处理7万消息。



在压测过程中，关注信息如下：

**CPU负载**

通过top命令查看cpu的负载情况，load average：12.03，12.05，12.08

类似上面那行信息代表的是cpu在1分钟、5分钟和15分钟内的cpu负载情况

比如我们一台机器是24核的，那么上面的12意思就是有12个核在使用中。换言之就是还有12个核其实还没使用，cpu还是有很大余力的。

**内存使用率**

通过free命令查询物理机内存占用情况

**JVM GC频率**

通过jstat命令查看JVM的gc情况，一般而言，多数gc都发生在年轻代，极少数对象进入老年代中。如果看到了频繁FGC，那么就改尝试调整一下参数了。

```
//打印gc信息，每秒一次，一共打印10次
jstat -gc [PID] 1000 10
```

**磁盘IO负载**

可以通过top命令中的cpu行来监控磁盘IO的状况

```
%Cpu(s):  0.6 us,  0.2 sy,  0.0 ni, 99.2 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
```

这个监控数据代表当前服务器的各种资源使用CPU的百分比情况，其中就有磁盘IO的指标。

以上指标的解读如下：

- us：代表用户态进程使用CPU的时间百分比情况

- sy：代表内核态进程使用CPU的时间百分比情况

- ni：代表高优先级进程使用CPU的时间百分比情况

- id：代表CPU空闲时间百分比

- wa：代表磁盘IO等待使用CPU的间百分比情况，具体指CPU在等待磁盘IO完成时花费的时间占总CPU时间的比例

- hi：表示硬件中断占用CPU的百分比，即处理硬件中断所占用的CPU时间百分比。

- si：表示软件中断占用CPU的百分比，即处理软件中断所占用的CPU时间百分比。

我们如果要看磁盘IO情况，就wa指标就可以了，在应用高峰期时，这个IO占比50%左右就是可以接受的极限了，否则就优化磁盘IO的速度了

此外，我们还可以使用`iostat -x 1`等命令查看更详细的磁盘IO信息

**网卡流量**

使用命令 `sar -n DEV 1 2`来查看当前服务器的网卡流量统计信息。

```
//-n DEV代表只显示网络IO相关数据
//1 2 代表每隔一秒打印一次数据，一共打印2次
sar -n DEV 1 2

//打印数据如下：
08:39:08 PM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s    rxcmp/s    txcmp/s   rxmcst/s     %ifutil
08:39:09 PM        lo      3.00      3.00      0.34      0.34      0.00      0.00      0.00       0.00
08:39:09 PM      ens3    165.00    200.00     36.02     41.26      0.00      0.00      0.00       0.00


IFACE：该列显示网卡名称
rxpck/s：接收的数据量（单位：KB）
txpck/s：发送的数据量（单位：KB）
rxkB/s：每秒钟接收的数据包数量
txkB/s：每秒钟发送的数据包数量
rxcmp/s：接收平均每个数据包的大小（单位：bytes）
txcmp/s：发送平均每个数据包的大小（单位：bytes）
rxmcst/s：每秒接收到的多播数据包数量。
%ifutil：表示接口使用率，即网络接口占总带宽的使用百分比
```

一般千兆网卡的流量理论上限可以达到128M/S，但是一般达不到这个极限值，一般实际传输流量在100M/S左右就到极限了，因为主Broker还要将信息同步给两个从Broker中，此外还有一些其他的网络开销。

因此当时我们发现的一个问题就是，在RocketMQ处理到每秒7万消息的时候，每条消息500字节左右的大小的情况下，每秒网卡传输数据量已经达到100M了，就是已经达到了网卡的一个极限值了。



