### Producer是何时从NameServer拉取broker路由信息的？

在之前的学习中，我们已经知道NameServer和Broker之间的交互关系，Broker会定时给NameServer集群发送定时心跳信息，NameServer则会定时检查所有broker是否存活，通过判断broker上一次的心跳时间来判断broker是否故障。

![image-20230420162855243](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304201628305.png)

清楚这个逻辑后，我们可以认为现在有一个NameServer和Broker集群都是正常工作的了，下面我们来了解下生产者Producer和NameServer之间的交互关系。

我们知道Producer会拉取NameServer的Topic信息、Broker信息等，但这个拉取时机是在什么时候？是在Producer启动的时候？显然不是，Producer启动过程还不知道要拉取什么Topic信息。

这里我们有一个要点，就是无论是生产者系统还是消费者系统，都不可能和全部的Broker节点构建起连接，而是只会和Topic对应MessageQueue分片所在的Broker构建起连接。

而一个Topic的MessageQueue分片信息可能在一个Broker中，但更多的时候是分散在不同的Broker节点上的，Topic只是逻辑上的一个概念而已，类型下面的结构图。

![image-20230420164640073](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304201646118.png)

既然Producer不是在启动的时候拉取NameServer信息，那多半会在给Topic发送消息的时候会拉取信息了，因为只有发送的时候才知道本次请求会往哪个Topic发送一条什么信息。

Producer发送消息前需要构建一个DefaultMQProducer对象，代码如下：

    DefaultMQProducer producer = new DefaultMQProducer("please_rename_unique_group_name");
    producer.setNamesrvAddr("127.0.0.1:9876");
    producer.start();
    
    //发送消息
    Message msg = new Message("TopicTest" /* Topic */,
                        "TagA" /* Tag */,
                        ("Hello RocketMQ " + i).getBytes(RemotingHelper.DEFAULT_CHARSET) /* Message body */
                    );
    SendResult sendResult = producer.send(msg);

从上面的代码我们可以分析出DefaultMQProducer是Producer和Broker沟通的一个桥梁，它构建起了Producer和NameServer的连接，可以通过NameServer获取到要发送Topic的路由信息、MessageQueue分片等信息，但是由于这个组件比较复杂，我们这里先不去研究它，只需要知道通过DefaultMQProducer组件，我们可以将消息投递到对应的某个Broker中即可。

那我们从哪里开始入手呢？这里可以直接查看**producer.send(msg)**方法，直接探索producer在发送消息时与NameServer和Broker之间交互逻辑。

DefaultMQProducer类中具体的操作对象是defaultMQProducerImpl，大部分业务都是这个对象完成的。

这里我们直接跟进到defaultMQProducerImpl.sendDefaultImpl方法，这里有发送消息的主要逻辑：

![image-20230420170506236](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304201705284.png)

在这个方法中，我们可以很容易找到其中的关键代码：

```java
TopicPublishInfo topicPublishInfo = this.tryToFindTopicPublishInfo(msg.getTopic());
```

通过方法名称就可以知道，这行代码的主要作用是获取Topic信息，Topic信息在哪里呢，自然是NameServer里，

![image-20230420172536255](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304201725299.png)

我们查看这个方法的代码，就可以知道和正常的缓存逻辑类似，先尝试从缓存中获取信息，缓存信息不存在或者缓存状态异常，则从NameServer中拉取最新信息缓存起来，否则就是直接返回缓存数据。

而发送的方式是通过remotingClient组件想NameServer发送GET_ROUTEINTO_BY_TOPIC请求码获取的。

```java
RemotingCommand request = RemotingCommand.createRequestCommand(RequestCode.GET_ROUTEINTO_BY_TOPIC, requestHeader);

RemotingCommand response = this.remotingClient.invokeSync(null, request, timeoutMillis);
```

这里我就不贴其他代码了，按之前了解的RocketMQ的代码风格，我们可以很容易找到NameServer是如何处理这个请求的。到这里，大家应该会有一点看源码的感觉了，实际上学习源码的技巧主要有两方面，

一是学习源码的设计模式、对象的封装与隔离等非业务技术；二是学习通源码中提炼不同场景的业务流程和各种业务的实现方式。



### Producer是如何感知NameServer中的数据信息变化的呢？

在DefaultMQProducer对象中有一个MQClientInstance组件，这个组件有一个定时调度线程池scheduledExecutorService，当MQClientInstance组件执行start方法时，就会开始执行各种定时调度任务，其中有一个任务就是定时拉取最新NameServer配置信息的。

![image-20230420180909722](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304201809770.png)

默认参数下，每30秒就会从NameServer拉取一次最新Topic相关信息缓存到本地。



### Producer是如何选择MessageQueue去发送的？

我们回到DefaultMQProducerImpl#sendDefaultImpl发送消息方法中，继续看后续的逻辑，此前我们已经获取到Topic的路径信息对象，也就是topicPublishInfo，之后我们下一个关注点就是从Topic中选择一个MessageQueue分片，将消息发送到这个分片所在的Broker上。

![image-20230421102754438](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304211027486.png)

上述代码中选择MessageQueue是由selectOneMessageQueue方法完成的，进一步追踪代码，会发现是在mqFaultStrategy组件中完成的路由选择，下面路由选择的主要逻辑：

![image-20230421132125785](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304211321832.png)

![image-20230421132203072](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304211322118.png)

这里不考虑延时容错机制参数sendLatencyFaultEnable开启的情况，但有一点指的注意，如果sendLatencyFaultEnable开启后，而且消息有顺序性的要求，且在发送时没有做过特殊处理，那么就有可能会出现乱序的情况。因为当broker1被回避后，消息可能会发往其他Broker2，如果broker1还没有消费完数据，那么机会存在broker1和broker2同时消费消息的情况，这种场景是没有顺序性的。

我们可以自己看这一行代码的执行结果。

```
tpInfo.selectOneMessageQueue(lastBrokerName)
```

![image-20230421132843638](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304211328676.png)



这就是一个基础的轮训算法，通过index递增，对messageQueueList进行取余，就会出现消息均匀发往不同的broker。比如如果messageQueueList数量为4，那么pos的轮训值就会是0,1,2,3,0,1,2,3一直反复循环。

这里我可以简单画一下Producer和NameServer之间的交互图：

![image-20230421102223882](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304211022146.png)

### Producer是如何把消息发送给Broker的？

回到DefaultMQProducerImpl#sendDefaultImpl发送消息方法中，前面我们已经从NAmeServer获取了Topic信息，又根据策略选择Topic中的一个分片所属Broker，下面要做的就是将消息发送到这个broker了。

我们可以在sendDefaultImpl方法直接看到这个发送方法：

![image-20230421135554885](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304211355933.png)

今日到这个方法中，我们关注其中的主要业务代码即可：

![image-20230421135731015](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304211357059.png)

这里只贴出了方法开头的一部分代码，主要逻辑是根据Broker的名称获取具体的ip地址，之后又判断当前生产者对象是否开启了VIP通道，如果开启了就会覆盖掉之前ip地址。

接下来的源码部分就有些繁琐了，但是大体的逻辑是封装发送消息对象RemotingCommand，请求码为SEND_MESSAGE，批量请求码为SEND_BATCH_MESSAGE，重试请求码为SEND_REPLY_MESSAGE。然后通过

```java
RemotingCommand response = this.remotingClient.invokeSync(addr, request, timeoutMillis)
```

remotingClient将请求发送给Broker。

到这里，我们大致上过了一遍Producer发送一条消息的大体流程，最后总结一下整体流程：

![image-20230421140748107](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304211407155.png)
