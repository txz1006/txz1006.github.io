### 什么是zookeeper?

zookeeper是一个应用在分布式项目中的协调管理框架。从名称意义中我们就可以知道zookeeper是一个协调管理者，能够协调各个分布式节点服务之间的数据竞争、共享同步等问题。

在官方释义中，我们可以进一步了解到zookeeper维护了一个多层次的文件树结构模型作为核心，以此结构对外提供配置维护、数据同步、命名服务等功能。

### 为什么要用zookeeper？

在分布式项目中，必须要有一个角色能够完成动态数据共享，或单节点的数据独占，以及实时数据同步等需求。而zookeeper提供了一套较为通用的分布式项目必备的沟通协调管理方案，这就是zookeeper的应用场景。

再具体一点，zookeeper可以进行集群部署，保证高可用；在数据管理上有原子性、顺序性；对于各节点而言又有独立性和数据最终一致性等诸多优点，基本可以满足多数开发场景。

### zookeeper具体使用

#### zk安装

下载一个zk的压缩包，上传到linux中，这里我们放到/usr/local目录下，然后使用tar命令解压：

```
tar -zxvf zookeeper-3.4.13.tar.gz
```

然后我们进入到解压目录中的/conf目录下，设置配置文件：

```
cp  zoo_sample.cfg  zoo.cfg
```

在zoo.cfg文件中我们可以配置zk的端口、数据日志路径、集群等信息，这里就不在深入了

然后我们需要在linux中配置一个zk的环境变量就可以使用，我们编辑/etc/profile文件，在最后添加如下两行配置：

```
export ZOOKEEPER_INSTALL=/usr/local/zookeeper-3.4.13/
export PATH=$PATH:$ZOOKEEPER_INSTALL/bin
```

配置好后，我们回到zk的解压/bin目录，执行如下命令启动zk：

```
./zkServer start
```

看到Starting zookeeper ... STARTED等字样说明zk已经成功启动，此外也可以通过JPS命令看看是否存在QuorumPeerMain的java应用来验证zk是否已经启动成功

#### zk使用

我们可以通过./zkCli.sh命令来进入zk的客户端界面来使用zk，看到[zk: localhost:2181(CONNECTED) 0] 一类的命令主体就说明我们可以可以操作zk了。

zk的主要结构是一个文件树，类似于java的TreeMap，每个节点都可以存储数据，但是必须要一级一级的创建节点，不可以直接创建父节点不存在的节点。

下面是一些常用的命令：

```java
//创建节点一个data，没有数据
create /data

//在data节点想创建一个666节点，并存储数据12345
create /data/666 12345

//将data节点数据修改为67
set /data 67
    
//获取节点内容
get /data/666

//删除节点(不能直接删除存在子节点的父节点)
delete /data/666    

//父子节点一起删   
deleteall /data
```

了解到这些之后，就可以简单的使用zk的进行项目开发了

### zookeeper的架构与原理

#### 架构模式

在zookeeper的实际应用中，多会进行zk的集群部署，保证高可用，而zk的节点之间的关系一般如下图所示：

![image-20211119131640101](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111191316535.png)

节点存在两种类型：leader和follower，leader节点负责接收执行数据写请求，以及给各从节点同步执行后的结果数据。follower节点负责连接客户端的读请求(写请求会转交给leader节点执行)。

#### Zab协议

Zab协议是zk的核心事件传播规则，主要有两种模式：

第一种是恢复模式，会在zk启动时或者leader节点宕机时触发这种模式模式的执行，具体而言会使用Paoxs算法通过各节点的投票选举出一个新的leader节点出来

选举规则：各节点投票数大于总节点数据的一半，如三台机器宕机一台：2>3/2则触发重新选举，

第二种是广播模式，主要是leader节点同步数据和状态到各从节点时触发

#### 一致性

zk在执行请求命令时为保证事务一致性，会给要执行的请求设置一个递增的事务id，并按照顺序依次执行，这个就是zxid。

zxid是一个64位的数值，前32位是当前leader的epoch值(选举出leader节点后，会产生一个随机epoch值，作为leader节点的唯一标识，在数据同步时会同步给其他follower节点)，后32位是一个递增的32位事务数值。





