### NameServer是如何处理Broker注册请求的

通过之前的学习，我们已经知道了NameServer启动后会创建一个NettyServer服务器，接收处理生产者、消费者、Broker服务的请求。

![image-20230412142245670](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304121422717.png)

而BrokerServer启动后，会通过brokerOuterAPI组件构建一个NettyClient客户端，定时向所有NameServer发送broker的注册心跳信息。同时BrokerServer也会启动多个NettyServer服务器接收处理生产者、消费者的请求，这里我们先不展开讨论。

![image-20230414165826934](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141658009.png)

下面我们就NameServer是如何处理broker的注册请求的逻辑来进行详细分析。

#### broker请求的NameServer的哪个接口

我们知道是broker发起的注册请求到NameServer，那么我们首先需要搞清楚的是broker注册请求到了NameServer的哪个接口上。

在之前的Broker启动流程学习中，我们知道BrokerOuterAPI是Broker作为客户端对外通信的组件，所以我们可以在其中找到Broker和NameServer的注册交互类：org.apache.rocketmq.broker.out.BrokerOuterAPI#registerBroker

![image-20230414162541567](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304141625619.png)

在这个registerBroker方法中，我们主要看这个请求对象RemotingCommand：

```java
RemotingCommand request = RemotingCommand.createRequestCommand(RequestCode.REGISTER_BROKER, requestHeader);
request.setBody(body);
```

这个RemotingCommand对象明确的确定了请求码是RequestCode.REGISTER_BROKER，具体的code值是103。

这里可以告诉大家的是，broker和NameServer都是通过Netty构建的网络通信客户端和服务端，而在不同接口请求路由方式上选择的是接口请求码，而不是我们经常见到的URL方式区分，不同接口对应不同的URL地址。

我们找到了RequestCode后，下面可以去NameServer上寻找服务端的处理逻辑了。



#### NameServer是在哪里处理Broker请求的

这里我们可以直接使用搜索大法，看看这个请求码在怎么地方被使用了

![image-20230418111539106](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304181115295.png)

从搜索结果来看，只有一个类org.apache.rocketmq.namesrv.processor.DefaultRequestProcessor使用了REGISTER_BROKER这个请求码，其他的调用位置，也只有BrokerOuterAPI一个类。

所以这里我们可以说一个小技巧，在阅读源码时，可以根据业务请求链路上的某个关键字来搜索调用位置，这就就可以判断这个关键字所在的业务在哪些地方用到了。

但是这个方法需要选择合适的关键字，如果关键字选择的不好，可能会搜出一大堆的调用位置代码来，如果我们对代码不熟悉，那么最好的办法还是按图索骥，前面我们已经知道NameServer的Netty处理请求的组件是NettyRemotingServer了，那么我们就找一找这个组件是在哪里处理Broker请求的。

![image-20230419163109679](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191631418.png)

Netty中使用ChannelHandler请求链来处理用户请求，这里我们可以直接找到ChannelInitializer#initChannel方法，看看用到了哪些ChannelHandler来处理请求。

首先是encoder变量，这个类型是encoder = new NettyEncoder();，一看就知道是对请求做encode编码工作的；然后是NettyDecoder，这个是做Decode解码工作的，和NettyEncoder是一对。

然后是IdleStateHandler，这个是Netty中用于处理闲置请求的，而connectionManageHandler类型是NettyConnectManageHandler，这个是处理所有请求的，是个连接管理对象；最后一个serverHandler是NettyServerHandler类型，这就是具体处理请求业务的Handler了，除了他，Netty的其他Handler都不是处理业务的。

NettyServerHandler是一个内部类，具体代码如下：

![image-20230419170850093](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191708134.png)

其中的processMessageReceived方法是这样恶毒：

![image-20230419171811900](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191718945.png)

方法代码将请求分为两种，一种是普通的外部请求的处理，另一种是对外部请求的回应。

而Broker发送请求到NameServer注册肯定是选择第一种类型，我们继续跟进代码查看方法：

![image-20230419172218411](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191722542.png)

到processRequestCommand方法这里我们就找到了实际处理请求的位置，其中我们只需要关注一行代码，就是

```
final RemotingCommand response = pair.getObject1().processRequest(ctx, cmd);
```

具体接收RemotingCommand请求对象，返回responseRemotingCommand；随这这条路，我们有要找到pair对象到底是什么，在NettyRemotingServer类中搜索，只找到了registerDefaultProcessor这一个来源，getObject1()返回是一个NettyRequestProcessor接口对象。

![image-20230419173159346](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191731380.png)

我们继续查找registerDefaultProcessor方法的调用位置，找到了NamesrvController类的registerProcessor方法，而这个registerProcessor方法是在NamesrvController下的initialize()初始化方法中被调用的。

![image-20230419173450458](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191734496.png)

到这里我们也找到NameServer的最终处理NettyRequestProcessor接口对象的实现类DefaultRequestProcessor，这个结果和我们直接搜索REGISTER_BROKER关键字的结果是相符合的。

![image-20230419173758784](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191737824.png)

#### DefaultRequestProcessor是如何处理Broker注册请求的

在DefaultRequestProcessor#processRequest方法中，我们直接根据请求码找到处理Broker注册请求的位置是registerBroker方法：

![image-20230419174104641](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191741688.png)

在registerBroker方法中我们直接找到核心代码：

![image-20230419174626553](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191746596.png)

这里NameServer使用了RouteInfoManager路由管理组件来处理Broker注册请求的。

到这里我们的流程图可以进一步将BrokerServer和NameServer的交互逻辑清晰化了。

![image-20230419175458390](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304191754441.png)

在RouteInfoManager#registerBroker注册方法中，Broker信息被保存到了brokerAddrTable容器中，这个brokerAddrTable是一个Map对象，会存储所有的broker注册信息，包括主节点，从节点。

这里有几个问题可以思考一下：

1.RouteInfoManager中的Broker注册信息会被持久化吗？

答：不会，NameServer是内存型存储，并不保证所有的nameserver的数据一致；牺牲数据一致性，保证高可用；

2.为什么不用zookeeper？：

答：RocketMQ希望为了提高性能，CAP定理，客户端负载均衡





### NameServer是如何感知Broker故障的

NameServer心跳检查、故障感知是如何实现的呢？这个问题的关键主要依靠两点，第一是Broker不停的发送心跳请求给NameServer，第二是NameServer不停的检测所有broker的心跳时间，将上一次心跳时间大于某个阈值的broker认定为故障，从正常broker列表中去掉。

清楚这个动态感知流程后，我们来看第一点，broker是怎么发送心跳的。

回到BrokerController#start方法中，我们找到broker发送注册请求的位置，可以看到这个注册方法是在registerBrokerAll方法中执行的，外部是一个定时线程池任务。

![image-20230413165330769](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304131653815.png)

也就是说，无论是首次注册，还是后期的心跳请求都是这个定时任务来发送请求的。这个定时任务是项目启动后10后开始发送第一次注册请求， 之后每隔30秒发送一次心跳请求（默认配置时长），心跳间隔最大是60秒。

搞清楚了broker的心跳原理后，下面我们看看NameServer是如何检测broker心跳的。

这里其实我们可以大胆猜测一下，其实逻辑基本是差不多的，NameServer应该也是有一个定时任务，然后有一个线程定时检查存储Broker注册的map信息，对比当前时间和brokerAddrTableMap中的各Broker上一次心跳时间，删除超出阈值的broker注册信息，认定为broker故障。

我们回到NamesrvController#initialize初始化方法中，就可以直接看到一个定时调度任务，这个任务直接调用routeInfoManager组件的scanNotActiveBroker方法，从名称就可以知道，这个方法执行的工作是扫描不活跃的broker信息。

![image-20230420104317284](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304201043428.png)

定时任务，在NameServer启动5秒后执行第一次，之后每10秒扫描一次。

下面我们可以看看scanNotActiveBroker方法的主要逻辑：

![image-20230420110516655](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304201105702.png)

到这里，NameServer感知broker故障的逻辑就清楚，scanNotActiveBroker方法会遍历brokerAddrTableMap中的所有broker信息，将上次心跳时间在2分钟前的的broker认定为故障broker，然后关闭和故障broker的netty连接，并将broker信息从brokerAddrTableMap中移除。

![image-20230420114018571](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304201140627.png)





