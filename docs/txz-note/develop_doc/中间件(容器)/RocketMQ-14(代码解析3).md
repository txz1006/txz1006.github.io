### Broker启动流程

在前面的学习中我们知道了，NameServer启动的主要流程就是根据配置信息启动了一个Netty服务端，创建了多个不同的线程池，来处理不同场景的业务，大致的结构图如下：

![image-20230413111847170](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131118537.png)

了解了NameServer大致的构成后，下面我们来学习一下BrokerServer的启动流程。

### BrokerStartup入口源码分析

在开始之前，我们先要有一个认知，就是MQ的源码是一帮人写的，那么代码的风格结构肯定是类似的，我们可以不以按照NameServer的解析流程来探索BrokerServer呢？

答案肯定是可以的，如果一套源码的风格过于多变，无论是对于开发者、还是对于使用者来说这都是一个灾难，所以一般而言，只要一个开源框架使用的人不在少数，那么开发规范一定会对代码风格结构有比较严格的要求。

之前我们探索学习NameServer是从**mqnamesrv**脚本开始的，这里我们在BrokerServer的启动流程中肯定也有一个类似的脚本。

我们在**mqnamesrv**脚本所在的distribution模块中进行搜索，发现了一个**mqbroker**的脚本，打开一看，就能看到同样格式的入口信息了：

```
sh ${ROCKETMQ_HOME}/bin/runbroker.sh org.apache.rocketmq.broker.BrokerStartup $@
```

根据mqnamesrv的启动经历，我们看都不用看，runbroker.sh脚本肯定是组织java进程启动命令行的脚本，最后会触发**apache.rocketmq.broker.BrokerStartup**入口类的执行。

我们进入到BrokerStartup类中，就会看到入口的main方法：

![image-20230413113759030](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131137066.png)

和NameServer启动的代码结构几乎一模一样。先通过createBrokerController(args)方法创建一个BrokerController组件，然后在start方法中启动这个组件。

所以这个BrokerController就是BrokerServer服务的最核心类了，我们后面的学习也是围绕的这个对象来进行的。

### BrokerController是如何创建的

根据之前的经验，我们可以直接去createBrokerController(args)方法看BrokerController组件的创建过程。

![image-20230413134741081](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131347122.png)

我们首先看到的就是这一类的配置信息代码，System.setProperty是设置项目环境变量的，NettySystemConfig配置的是Netty缓冲池大小。

这些东西并不需要大家去探索是在什么地方用到了这些配置，也不需要去想为什么要在这种地方写这样的代码，只需要有有个印象就行，知道在BrokerServer启动前，配置好多的变量参数，这些参数会在后续的业务场景中被用到就OK了。

因为你只是一个学习者，并不是一个熟知RocketMQ的开发者，维护者；所以初学阶段，我们的目的应该是跑通MQ的启动链路和一些常用场景的业务链路即可，这些不知道什么时候才会用的变量信息，可以等到你对MQ有一个整体概念后，可以慢慢的去摸索。

在上面的环境变量设置完后，后面的代码是这样的：

![image-20230413135815343](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131358390.png)

这块的代码大家肯定不陌生，之前在NameServer启动过程中也有这样的配置对象；这里代码的主要逻辑是创建了4个配置对象，BrokerConfig是当前broker配置对象，NettyServerConfig是Broker作为服务端的配置对象，NettyClientConfig是Broker作为客户端的配置对象，MessageStoreConfig是Broker的持久化配置对象。

这里大家可能会疑惑，为什么要在Broker中有客户端的配置对象NettyClientConfig呢？

实际上，大家想一想MQ的通信关系就能明白了，Broker和生产者和消费者交互的时候，是作为一个服务端存在的，生产者发送消息到Broker，消费者从Broker中拉取最新消息；但是Broker和NameServer的交互是作为客户端存在的，因为Broker要注册到所有NameServer中，同时还要定时为NameServer发送心跳请求。

接着往下走，看到的同样参数解析规则：

![image-20230413141650297](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131416341.png)

从命令行里解析-c的配置文件路径，然后读取到Properties对象中，接着将Properties解析好的参数写入之前的4个配置对象中，最后还记录一下broker本地配置文件的路径。

再往下走，就是一些配置参数格式校验和核心启动代码了，这里我就贴一下关键的代码片段：

```java
 //是否开启DLeger技术管理主从broker之间的CommitLog同步
if (messageStoreConfig.isEnableDLegerCommitLog()) {
    brokerConfig.setBrokerId(-1);
}

//.....

//基于4个配置，创建BrokerController对象
final BrokerController controller = new BrokerController(
    brokerConfig,
    nettyServerConfig,
    nettyClientConfig,
    messageStoreConfig);
// remember all configs to prevent discard
controller.getConfiguration().registerConfig(properties);

//执行BrokerController对象的初始化
boolean initResult = controller.initialize();
if (!initResult) {
    controller.shutdown();
    System.exit(-3);
}

```

以上代码的关键代码就两行，第一行是：

```java
final BrokerController controller = new BrokerController(
    brokerConfig,
    nettyServerConfig,
    nettyClientConfig,
    messageStoreConfig);
```

根据4个配置创建BrokerController对象，我们可以进一步看一下BrokerController对象的构造方法的逻辑：

![image-20230413145445179](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131454228.png)

![image-20230413145510373](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131455416.png)

![image-20230413145716230](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131457277.png)

我们可以看到构造方法中有创建非常多的对象，但这里大家没必要搞懂每个对象是干什么的，可以根据类的名称含义和类型先大概给这些成员变量分个类，比如这里我们可以简单将BrokerController的成分分为核心管理器组件和线程池两大部分，然后我们就可以根据这些信息来画个概况图：

![image-20230413151444419](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131514462.png)

### BrokerController是如何初始化

```
boolean initResult = controller.initialize();
```

在BrokerController实例化后，紧接着就进行初始化，我们接下来看看BrokerController初始化方法中做了哪些业务。

![image-20230413154228162](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131542198.png)

首先从磁盘中加载各种Topic相关的配置或消费状态、消费过滤等信息，如果这些信息都被成功的加载，则接着执行以下代码：


![image-20230413153327812](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131533865.png)

这块代码主要是创建了一个DefaultMessageStore对象，从变量名称来看是用来做消息持久化用的，大概率将消息写入到CommitLog的操作就是这个对象来完成的。

之后判断是否开启了DLeger机制，开启了就创建DLedgerRoleChangeHandler处理对象放到messageStore中，相当于使用DLeger机制接管了MQ的主从同步，消息持久化等功能。

之后创建的BrokerStats是信息统计用的，后面的代码我们也可以先不用关系，他们不是主流程中的必要关注代码。

messageStore对象创建完后，接着就是初始化的核心代码部分，代码片段如下：

![image-20230413153836944](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131538990.png)

以上代码中，创建了两个Netty服务器，一个是remotingServer、另一个是fastRemotingServer，之后往下的代码是一对线程池，从线程池的变量名称我们可以知道这些线程池大概是什么场景使用的。

再接着看剩下的代码，基本就是BrokerController中的一个定时线程池scheduledExecutorService，定时执行各种业务规则，比如统计信息，持久化各种消费数据到磁盘文件等等。

![image-20230413155706108](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131557162.png)

到这里，BrokerController的初始化流程基本就完成了，后面其实还有一些，事务、权限、安全认证一类的代码，但这些统统都不是影响MQ主要功能正常执行的部分组件，所以我们的可以暂时的忽略掉他们，到这里为止我们可以简单的总结下BrokerController组件的内容有哪些了：

![image-20230413161856478](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131618514.png)



### BrokerController是如何启动的

我们回到最开始的org.apache.rocketmq.broker.BrokerStartup#main方法中，我们到start()方法中看看启动做了哪些工作。

![image-20230413162013917](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131620956.png)

一下是start方法主要代码片段：

![image-20230413164053750](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131640793.png)

这个方法中全是一堆BrokerController成员变量组件的启动代码，这里我们也不必过于深究每个组件的start方法细节实现，因为代码毕竟是别人写的，在这么一个复杂的框架体系下，如果不涉及具体使用场景，谁知道这些个组件是干什么的，而且你现在去看messageStore、remotingServer、fastRemotingServer、brokerOuterAPI等这些组件的实现，你能理解几层？

大多数代码都是为了业务场景而写的，我们可以在后续的场景流程学习中去慢慢探索这些组件的用途。现在我们只需要有个概念，知道有这么个东西就可以了。

接着是最后一块，而且比较重要的代码：

![image-20230413165330769](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131653815.png)

这是一个定时任务，我们可以从方法名称知道这是一个注册接口，我们进到其中看一下注册到了哪个地方，具体代码如下：

![image-20230413170006367](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131700418.png)

这段代码并不完整，但从中我们可以知道，Broker这里注册到的位置是nameServerAddressList，也就是NameServer集群的地址列表，之后就是创建Request请求发送到各个NameServer了。

在开启Broker注册NameServer的定时任务后，BrokerController的主流程基本就走完了。

到这里我们可以初步的画一个Broker和NameServer的交互图了：

![image-20230413171155492](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131711545.png)

### BrokerOuterAPI是如何发送注册请求的

上面我们只是粗略的介绍了Broker是通过BrokerOuterAPI这个组件和NameServer进行请求交互的，下面我可以进一步看看BrokerOuterAPI是通过何种方式发送请求到NameServer的。这块的主要代码在org.apache.rocketmq.broker.out.BrokerOuterAPI#registerBrokerAll方法中：

![image-20230414161042861](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141610908.png)

这块的代码就是构建了一个RequestHeader和RequestBody，然后循环将两个对象发送到不同的namesrvAddr地址服务器上，这就是Broker注册到NameServer的请求。

由于请求是通过线程池来执行的，所以又使用了CountDownLatch来记录每个请求的记录状态，只有所有请求都发送成功了才会返回一个registerBrokerResultList注册结果列表。

继续深入到registerBroker方法中，看看每个注册请求是如何实现的：

![image-20230414162541567](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141625619.png)

看到这里大家应该清楚了，注册请求是通过remotingClient.invokeSync方法发送出去的，继续完善我们的结构图如下：

![image-20230414165826934](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141658009.png)

至于remotingClient是什么类型，我们可以在BrokerOuterAPI组件的构造方法中得到答案。

![image-20230414170300787](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141703838.png)

也就是说Broker发送请求的客户端是也是使用Netty构建的，没有使用传统的http工具包之类的组件。

既然是使用Netty搭建的请求工具，那么我们可以简单的看看里面的实现，但是没必要了解的过多，因为里面肯定用到了很多Netty相关的API，如果你没有接触过Netty那么看这块代码就会异常痛苦，所以我们把他当成一个http请求工具类就好，等到以后熟悉Netty了再回来学习实现也不迟。

下面我们看看org.apache.rocketmq.remoting.netty.NettyRemotingClient#invokeSync是如何发送请求的：

![image-20230414172644915](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141726983.png)

这里有两个重点，一个是使用getAndCreateChannel(addr)获取一个和NameServer构建连接的Channel对象，另一个是使用Channel发送请求数据，这块代码封装在invokeSyncImpl方法中。

**跟NameServer建立网络连接的Channel对象是怎么创建的**

我们继续跟进getAndCreateChannel方法的代码：

![image-20230414173039930](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141730991.png)

这里我们可以直接看createChannel方法的代码，Channel一般会在首次才会创建，二次调用就是直接获取了：

![image-20230414173625309](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141736362.png)

以上代码片段是createChannel方法中，最重要的代码片段，Netty就是使用bootstrap.connect方法和服务器端构建连接的，连接对象是具体是一个ChannelFuture，和Scoket类似，这个对象可以反复使用发送请求。

然后在invokeSyncImpl方法中，使用channel.writeAndFlush(request)将请求发送给NameServer的Netty服务端，然后使用ChannelFutureListener监听服务端返回的数据，客户端使用responseFuture来存储返回的数据，整个Netty的客户端服务端的交互基本如此。

![image-20230414180823038](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141808094.png)

到这里我们就清楚Broker是如何通过NettyClient发送请求到NameServer注册的流程了，最后，我们可以总结一下Broker的启动过程：

1. Broker启动后，需要将当前服务注册到NameServer中，这过程是BrokerOuterAPI组件完成的
2. Broker作为服务端启动了两个NettyServer，一个是fastNettyServer，用于接收外部的请求，至于这两个服务器用途区别，我们以后再分析
3. NettyServer接收到请求后，请求会交给线程池来处理，所以一定会有各种线程池来处理各种各样的请求
4. 线程池处理请求时，一定会组合使用BrokerController中的各种组件来完成业务流程，比如将请求的消息持久化到CommitLog文件中，写入索引到idnexfile和customerQueue文件中等等
5. 此外，会有各种定时线程池任务，定期的统计、心跳、检查状态等等