redis-3(持久化与集群部署)

#### 1.redis持久化

redis提供了两种持久化方式：RDB机制和AOF机制，redis持久化的意义在于备灾恢复

##### 1.1RDB机制

RDB机制是redis默认开启的持久化机制，当我使用redis后，会默认在redis文件夹下生成一个dump.rdb(默认名称)持久化文件，这个文件是redis自动备份的数据文件，可以用来进行数据恢复。

主要逻辑是redis主进程会fork出一个子进程，通过子进程来进行IO写入持久化RDB文件。

RDB机制采用数据快照的存储方式，会将redis中的数据以二进制的格式存储在dump.rdb中；执行备份的大概逻辑是redis会fork当前redis进程(fork过程中会阻塞、会丢失fork后的redis新数据)，在创建的子redis进程中进行数据持久化操作，所以RDB会周期性的备份一次redis全量数据(生成的dump.rdb文件会覆盖旧rdb文件)。

执行RDB快照有三种方式：

- **执行save命令**

执行此命令后，redis会执行快照逻辑，在快照未完成前redis处于阻塞状态，生成新的dump.rdb文件后会覆盖删除旧的rdb文件

- **执行bgsave命令**

此命令会在后台异步执行快照逻辑，仅在fork进程时会阻塞(时间极短)，fork完成后可以正常进行redis操作

- **自动快照保存规则**

在redis.conf配置文件中找到SNAPSHOTTING配置下的三行save命令

```sh
save 900 1
save 300 10
save 60 10000
```

每900秒内有1条数据发生改变时，或是每300秒内有10条数据发生改变时，或是每60秒内有10000条数据发生改变时会执行快照保存逻辑，此处触发的快照命令是bgsave命令(也可以手动调用save或bgsave命令来生成RDB文件)。

若不想使用RDB机制可以注释三行save命令即可。

RDB机制的优缺点：

优点：某个时间段前数据全量备份、恢复速度快(适用大数据量)、备份文件小，对redis影响小

缺点问题：在持久化过程中不会存储新增加改变的数据，会有数据丢失

- **rdb文件如何使用？**

redis进程进行重启时，会自动读取最近一个的appendonly.aof或dump.rdb文件进行数据恢复，如果aof和rdb文件都有，redis会优先适用aof文件进行数据恢复~~(注意文件恢复时需要手动将aof持久化关闭，否则redis会自动创建一个新的aof空持久化文件，之后再通过热命令打开aof即可)，或者关闭aof，使用rdb文件恢复数据，再打开aof持久化，将rdb文件转为aof，再停止redis将redis config中的appendonly改为yes~~

将appendonly.aof或dump.rdb备份文件复制到redis目录中，重启redis就可以自动恢复数据

```
##热开启aof
config set appendonly yes
```

**数据备份方案**

写crontab将rdb数据文件复制到一个目录下，一个标准是按小时执行，保留48小时的数据，还有一个标准是按照天执行，保存1个月的数据

##### 2.AOF机制

AOF是redis提供的另一种持久化机制，他和RDB的主要区别是AOF存储的数据不是redis内存数据，而是redis的执行命令；在redis中AOF机制是默认关闭的需要在redis.conf配置文件中开启。

在redis.conf文件中找到APPEND ONLY MODE配置，其下就是AOF持久化的配置：

```sh
#AOF机制的开关
appendonly no
#生成AOF文件名称
appendfilename "appendonly.aof"
#########################
#下面是给AOF文件记录redis命令的三种方式

# appendfsync always
appendfsync everysec
# appendfsync no

```

appendfsync always意为每执行一条redis命令就记录一次命令；appendfsync everysec意为每秒通过fsync命令将os cache中的数据写入AOF文件(记录一次期间执行的redis命令)；appendfsync no则是不进行命令记录

| 机制  | always | everysec | no  |
| --- | --- | --- | --- |
| 优点  | 记录命令不会存在丢失 | 记录大多命令，性能也不差(默认机制) | 无   |
| 缺点  | 需要消耗额外资源，非常影响性能 | 有1秒钟的数据丢失 | 只负载将 数据写入os chahce，不管何时刷盘 |

当然AOF文件不会无限的扩大，当redis内存中的数据达到设置内存上限时，会通过LRU缓存清理算法，清楚内存中基本不被访问的数据，从而空出大片空间给redis继续存储数据，而AOF文件达到一定大小后，redis会执行一个rewrite机制，将当前内存中的数据拷贝一个快照数据，创建一个新的AOF文件，之后将旧AOF文件删除。

1.redis fork一个子进程

2.子进程复制当前内存中的数据 构建临时AOF文件

3.主进程继续写新数据到旧的AOF文件中

4.子进程构建新AOF文件完成后，主进程会将fork子进程时刻之后的新数据从旧AOF文件中追加到新AOF文件中，并删除旧AOF文件

**rewirte触发机制**

如果当前AOF文件大小，比上一次AOF文件大auto-aof-rewrite-percentage个百分比时，并且当前重写后的AOF文件大小要大于auto-aof-rewrite-min-size才触发rewirte。

```
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
```

**AOF文件损坏修复**

```sh
./redis-check-aof -fix /var/local/redis/appendonly.aof
```

之后选择确定就好了，redis会将aof文件中错误的命令删除掉

AOF机制优缺点：

优点：记录数据更加高效，而且可以用于恢复误操作数据

缺点：AOF文件往往比较大，因为记录的是命令不是数据，所以在数据恢复时速度比较慢，而且会有可能恢复不了100%的数据(因为bug或异常)

但是因为AOF文件中的数据比较完整，一般还以AOF文件作为恢复数据文件，而RDB文件多作为冷备份数据，代表记录某一时刻下redis的数据快照。所以还是AOF和RDB都开启为妙，一旦AOF文件异常无法适用，还可以使用RDB文件进行恢复。

参考：https://baijiahao.baidu.com/s?id=1654694618189745916&wfr=spider&for=pc

#### 2.redis集群

单个redis往往可用性有限，如果进程挂了，那么就会出现数据丢失问题，所以就有了多个redis搭建集群的需求。这样我们就可以写数据走主redis，读取缓存走从redis。

redis部署集群采用的是去中心化的设置方式，对外表现为一整个redis集群对象；当我们给集群插入一条数据时，会根据key做一个请求哈希值的运算\[`CRC16(key) % 16384`\]，得到的结果在0~16384之间，而集群会根据节点数量平分0~16384这个区间的落点给每个redis节点，若计算结果落到了哪台redis节点的落点上，则这条数据就会存储到这个redis节点中；

在实际使用中，至少需要6个redis节点才能构成集群，因为redis集群之间会进行互相通信，若是某个节点挂了则剩余节点会进行投票判断该节点是否挂了，投票机制需要过半数才能确定节点是否挂了，所以至少需要3个redis节点才能构成集群。

又因为集群中的每个redis节点都会存储一部分的数据，若是某个节点挂了，则之后存储数据的key命中这个节点的落点范围时，就无法进行存储，导致整个集群的数据丢失，所以每个节点至少需要又一个备用节点保证该节点的高可用性；总需要共3主节点、3个备节点。

CRC16(key)求得的值有16bit，对应的哈希值范围是0~65536(2^16)，至于为什么在取模时没有选择65536。而是16384，主要是考虑信息传输效率的选择。因为65536会导致传输的信息头会多传一些数据，而小于16384则会导致数据存储不够均匀。

##### 1.搭建集群操作

由于没有6台服务器做真正的分布式集群，所以，下面的集群是部署在一台集群的6个redis伪集群，每个redis的端口不同而已，若是真正到的分布式环境中，只需要修改redis的IP配置就可以。

部署配置：一个redis环境，6个redis.conf配置文件

![image-20201113155305098](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201113155312.png)

首先，修改6个redis.conf为6套不同的redis节点配置

```sh
#将端口修改为7001
port 7001

#指定节点的日志输出文件
logfile /usr/local/redis/var/redis_7001.log

#指定节点的备份输出文件
dbfilename dump_7001.rdb

#开启集群配置(配置默认会被注释)
cluster-enabled yes

#开启配置集群节点配置文件(配置默认会被注释)
cluster-config-file nodes-7001.conf
```

根据上述配置修改出6套端口为7001~7006的配置文件

通过redis-server启动6个redis进程：

```sh
#cd到redis/bin文件夹下,根据不同配置启动6个redis节点进程
~: ./redis-server ../etc/redis01.conf
~: ./redis-server ../etc/redis02.conf
~: ./redis-server ../etc/redis03.conf
~: ./redis-server ../etc/redis04.conf
~: ./redis-server ../etc/redis05.conf
~: ./redis-server ../etc/redis06.conf
#查询开启的redis进程
ps aux |grep redis
```

![image-20201113155849767](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201113155849.png)

当查询到6个cluster的redis进程则可以开始配置集群了

配置集群需要知道redis的版本，在redis5之前的版本需要安装ruby环境，通过ruby脚本创建redis集群，而redis5之后的版本将脚本集成到了redis-cli中，可以直接配置集群。

```sh
#通过redis-server -v查询redis版本
~: ./redis-server -v
Redis server v=5.0.5 sha=00000000:0 malloc=jemalloc-5.1.0 bits=64 build=b3c936b052e1d25a
```

本机安装的redis是5.0.5版本，不需要使用ruby脚本安装，使用ruby脚本安装请参考：https://blog.csdn.net/qq_42815754/article/details/82912130

通过redis-cli --cluster create命令创建集群：

```sh
~: ./redis-cli --cluster create 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 127.0.0.1:7006 --cluster-replicas 1
```

最后的--cluster-replicas 1说明每个主节点有1个从节点

命令执行后会自动创建主从节点和集群信息，中间需要输入一次yes确定创建集群：

![image-20201113162315081](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201113162315.png)

上图第一个框的信息是0~16384的落点槽的分配，三个主节点会均分落点范围

第二个图是主从节点的管理，7001的从节点是7005，7002的从节点是7006，

第三个图的创建后的集群各节点信息，3主3从，每个节点信息包括一个节点id、节点地址、hash落点槽、是主/从节点

通过上述命令就创建了集群，我们可以通过redis-cli连接某个节点

```sh
#注意需要使用-c集群参数，如果不加会出现(error) MOVED 5798 127.0.0.1:7002错误
./redis-cli -c -h 127.0.0.1 -p 7001
```

进入节点后可以通过**cluster info**和**cluster nodes**命令查询集群信息：

```sh
127.0.0.1:7001> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:6
cluster_my_epoch:1
cluster_stats_messages_ping_sent:177
cluster_stats_messages_pong_sent:177
cluster_stats_messages_sent:354
cluster_stats_messages_ping_received:172
cluster_stats_messages_pong_received:177
cluster_stats_messages_meet_received:5
cluster_stats_messages_received:354

127.0.0.1:7001> cluster nodes
b05f8b4e121c76910198c95b9063510e95e9137f 127.0.0.1:7003@17003 master - 0 1605248551799 3 connected 10923-16383
7ff1b69c665e90cc2858dc4898bbbf7a09fbbdf3 127.0.0.1:7002@17002 master - 0 1605248549000 2 connected 5461-10922
41e8b1a08a60e68d68b7228a469132dd415cf0cd 127.0.0.1:7006@17006 slave 7ff1b69c665e90cc2858dc4898bbbf7a09fbbdf3 0 1605248549000 6 connected
10c67e3f88690df9923c7c440fcaa17a49a25675 127.0.0.1:7005@17005 slave f38d7496a424f7fe5e7b7b8bfc317d639dbd971a 0 1605248550797 5 connected
d980e0fdbe884727c313b3bb32cbde7f66db6e91 127.0.0.1:7004@17004 slave b05f8b4e121c76910198c95b9063510e95e9137f 0 1605248549793 4 connected
f38d7496a424f7fe5e7b7b8bfc317d639dbd971a 127.0.0.1:7001@17001 myself,master - 0 1605248550000 1 connected 0-5460

```

在插入不同数据时，我们发现会插入到不同的节点中：

```sh
127.0.0.1:7002> set str1 1
-> Redirected to slot [5416] located at 127.0.0.1:7001
OK
127.0.0.1:7001> set str2 2
-> Redirected to slot [9547] located at 127.0.0.1:7002
OK
127.0.0.1:7002> set str3 3
-> Redirected to slot [13674] located at 127.0.0.1:7003
OK
127.0.0.1:7003> set str4 4
-> Redirected to slot [1421] located at 127.0.0.1:7001
OK

#从任何一个节点都可以访问所以节点的数据
127.0.0.1:7001> get str3
-> Redirected to slot [13674] located at 127.0.0.1:7003
"3"
```

参考：https://baijiahao.baidu.com/s?id=1660566302486460631&wfr=spider&for=pc

https://www.cnblogs.com/zhoujinyi/p/11606935.html

#### 3.redis主从复制

**原理：**

1.  主从节点建立socket命令
    
2.  从节点发送psync命令给主节点
    
3.  主节点收到命令后会执行full resynchronization(全量复制，首先主节点生成一个rdb文件发送给从节点，并记录之后新写入主节点的数据到缓冲区中，等到从节点将rdb文件重写到内存后，主节点会将缓冲区中新写入的数据追加发给从节点中，这样就实现了全量复制)
    
4.  之后主节点每新写入数据，就会异步发送给从节点
    

**流程:**

1.  从节点启动后从配置slaveof中获取主节点的ip和端口信息(redis6.2版本后该配置改为replicaof)
2.  从节点向主节点发送ping命令，获取和主节点的网络连接(从节点会开启一个心跳定时任务，每秒钟检查是否有新的主节点要连接和复制；而主节点也有各心跳任务，每10秒钟检查一次从节点信息)
3.  口令认证，如果主节点设置了requirepass，那么从节点要在配置masterauth中设置主节点的口令密码
4.  主节点执行full resynchronization，将主节点数据全量复制内从节点
5.  后续主节点通过异步复制将数据追加修改到从节点中（主节点在异步传输数据时，也会同时写入一个backlog中，其中记录每次复制传输的数据和offset标记，断点续传也是基于backlog实现的，backlog默认为1M）

**断点续传和无磁盘化复制：**

1.  主从节点连接后都会维护一个offset标记(backlog日志中)，这个标记会随着数据的同步不断递增，当从节点因为一些问题出现主从断开后又重连的情况时，主节点会根据offset标记将之后的数据写入到从节点中，并不会直接再进行全量复制；只有当主从节点之间的出现异常，如主节点重启后runid和从节点记录的runid不一致时，才会重新触发全量复制
    
2.  主节点异步是通过传输rdb文件进行全量复制，当然也可以不生成rdb，直接将内存数据传输给从节点
    
    ```
    #需要开启配置
    repl-diskless-sync
    repl-diskless-sync-delay，等待一定时长再开始复制，因为要等更多slave重新连接过来
    ```
    

注意点：

```yml
#如果在进行异步传输rdb文件，时间超过60s，则会复制失败，可以通过 repl-timeout来调整
#如果复制的数据量在4G~6G之间，那么很可能全量复制时间消耗到1分半到2分钟
repl-timeout 60

#如果在复制期间，内存缓冲区追加数据持续消耗超过64MB，或者一次性超过256MB，那么停止复制，复制失败，通过client-output-buffer-limit来调整(60s内)
client-output-buffer-limit slave 256MB 64MB 60
```

**操作：**

从节点配置：在从redis的redis.conf配置文件中修改slaveof 关键字为

```
##指定主节点ip和端口
slaveof [masterip] [masterport]
```

第二，设置bind \[ip\]为自己的局域网ip或外网ip

第三，设置主从redis节点安全验证，在从节点中加入masterauth指定主节点配置的密码

```
masterauth <master-password>
```

第四，设置从节点为只读节点

```
slave-read-only yes
```

主节点配置：设置bind \[ip\]为自己的局域网ip或外网ip

第二：设置安全配置,和从节点的masterauth相对应

```
#这也是主节点的登陆密码
requirepass <pwd>
```

============

注意，配置好后，还要将各服务器的redis对外防火墙端口打开

之后先启动主服务器，再启动从服务器

并且可通过**info replication**命令查看主从信息，主redis负责写，从服务器只负责读，不能写

处理主从数据不一致问题：

缺点：无法动态选举主redis，一旦主redis挂了，就无法写数据了

#### 4.redis哨兵

**redis测压**
1.使用redis-benchmark工具
-c 并发量 , -n 数据量 ,-d 每条数据的字节数
2.主从集群，水平扩展，增加redis的读取QPS（单个机器的redis读取量*机器数量）

3.影响redis性能的主要问题：一个是复杂的数据操作，另一个是单个key的val很大等等

**redis高可用**
1.什么是系统高可用性?（99%时间能用）
2.redis高可用叫故障转移，一旦主节点故障，马上实现主备切换，即将某个从节点切换为主节点（哨兵节点实现）

**哨兵集群**
1.sential(哨兵)功能作用，他是redis高可用的一个组件，可以实现集群监控、消息通知、故障转移、配置中心(保证高可用，不保证数据0丢失)
2.哨兵功能本身也是分布式部署，至少要3节点(哨兵节点数是>=2的数量，当哨兵为2时，其中一个哨兵挂了，另一个无法独占完成故障转移，所以至少需要3个)
3.quorum(认为可以开始进行故障转移的哨兵数量)，majority(赞成此次故障转移的的哨兵数，最低为2，3哨兵为2，4哨兵也为2，5哨兵为3)，满足2个条件才能实施故障转移

4.当有quorum数量的哨兵认为master宕机了，需要选举新master节点；那么就会选出一个哨兵来做故障转移，这个哨兵还需要得到majority数量的哨兵同意后才能开始工作。
(当quorum配置&lt;majority时，满足majority数量的哨兵授权就能切换；而当quorum配置&gt;=majority时,就得有quorum数量的哨兵授权才能切换)

5.执行切换的哨兵会从要成为新master的节点中获取一个configuration epoch，这个是一个version号(唯一)；
如果这个哨兵切换失败了，那么其他哨兵会等待failover-timeout时间后，会接替继续执行切换工作，重新获取一个新configuration epoch作为新版本号 ，直到切换完成后，成为新master的节点会更新生成新的master配置信息，然后通过节点通信方式同步为其他哨兵，哨兵之间就以新的configuration epoch版本号作为最新数据版本

**哨兵导致数据丢失问题**
1.主节点在异步复制数据给从节点时，宕机，导致主节点内存数据未到从节点中而丢失
2.网络分区导致哨兵认为主节点挂了，而将另一个从节点升级为主节点，实际上就有2个主节点了(脑裂问题)。分区导致数据隔离，也会数据丢失

3.解决方法
min-slaves-to-wirte 1(至少又一个从节点在工作)
min-slaves-max-lag 10 (主节点发现数据复制同步延迟超过了10s(从节点数据落后主节点数据超10s)，该主节点会停止接受写请求，而客户端就会将之后的请求写入本地磁盘中等到)

**sdown(主观宕机)和odown(客观宕机)**
sdown是某个哨兵节点在ping master节点时，如果时间超过了is-master-down-after-milliseconds指定的毫秒时间后，就认为master宕机了
odown则是有quorum个哨兵节点都认为master节点宕机了，这就是odown

**哨兵节点如何通信，互相发现**
哨兵节点是通过redis的pub/sub系统实现的通信，大概就是哨兵会往\_\_sentinel\_\_:hello这个channel中发送自己的信息(host、ip、runid、监控配置信息)，每个哨兵会和其他哨兵进行信息交换通信

**slave->master选举算法**
1.跟master节点断开的时长，时间越长越不会被选举成master
超过down-after-milliseconds*10时间后基本不会被选为master

2.slave-priority配置优先级越高，越会选举成功

3.slave复制数据的offset越靠后，越会选举成功
4.runid越小，越会选举成功

##### **哨兵节点配置信息**

一般来说哨兵节点需要独子运行时一个进程，端口是5000，使用redis-sentinel客户端进行启动，来需要有一个sentinel.conf配置文件，这个文件需要配置监控master-slave架构的master信息，主要配置如下：

```sh
#后台运行
daemonize yes
#定日志输出文件位置
logfile /var/sentinal/5000/sentinel01.log
##绑定网络ip(不同机器绑定自己的ip)
bind 192.168.31.187
##设置端口
port 5000
##指定哨兵工作空间 (输出日志等，该文件夹需要提前建立好)
dir /var/sentinal/5000
##sentinel monitor  <主节点名称> <主节点地址> <主节点端口> <quorum> (都指向master节点信息)
##其中quorum是判断需要执行故障转移的哨兵数量
##哨兵监控主节点后会自动获取从节点信息，也就是每个哨兵会监控全部的节点
sentinel monitor mymaster 192.168.31.187 6379 2
## 指定down-after-milliseconds(主观宕机时限)，下面是30S
sentinel down-after-milliseconds mymaster 30000
##指定failover-timeout(主备前切换失败等待时间)，下面是3分钟
sentinel failover-timeout mymaster 180000
```

以一个三哨兵集群为例的配置文件如下：

```sh
##创建哨兵输出信息的路径
mkdir /etc/sentinal
mkdir -p /var/sentinal/5000

##在/etc/sentinal路径下放入5000.conf哨兵配置文件
/etc/sentinel/5000.conf

port 5000
bind 192.168.31.187
dir /var/sentinal/5000
sentinel monitor mymaster 192.168.31.187 6379 2
sentinel down-after-milliseconds mymaster 30000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1

port 5000
bind 192.168.31.19
dir /var/sentinal/5000
sentinel monitor mymaster 192.168.31.187 6379 2
sentinel down-after-milliseconds mymaster 30000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1

port 5000
bind 192.168.31.227
dir /var/sentinal/5000
sentinel monitor mymaster 192.168.31.187 6379 2
sentinel down-after-milliseconds mymaster 30000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
```

启动哨兵节点

```sh
#只启动哨兵
redis-sentinel ./etc/sentinel.conf
#
redis-server /etc/sentinal/5000.conf --sentinel
```

当三个哨兵节点都指向通一个master节点监控时，那么当master宕机就可以正常进行故障转移了，最小的哨兵节点架构数是3个(虽然2个哨兵就可以构成监控)，

**检查哨兵状态**

redis-cli -h 192.168.31.187 -p 5000

检查哨兵节点监控是否正常

```sh
sentinel master mymaster

SENTINEL slaves mymaster

SENTINEL sentinels mymaster

#获取监控主节点信息
SENTINEL get-master-addr-by-name mymaster
```

##### **备灾演练**

1.哨兵节点下线或slave节点下线

- 停止sentinel进程，在其他哨兵节点中执行sentinel reset *命令
- 通过sentinel master <mastername>查询哨兵的数量是否已更新</mastername>

2.备灾测试
(一主二从节点架构，分别有3个哨兵节点监控master节点)

- 停掉master节点
- 哨兵监控确认master宕机后开始进行故障转移，选举一个新slave节点成为新master节点
- 故障转移成功后,将之前的就master节点重启
- 哨兵监控到旧master信息后会将他变为slave节点，挂到新master节点上去

https://zhuanlan.zhihu.com/p/139726374sh