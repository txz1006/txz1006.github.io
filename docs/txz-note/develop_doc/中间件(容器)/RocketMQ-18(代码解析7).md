### Consumer作为消费者是如何创建出来的？

我们按照之前看Producer的经验，直接从DefaultMQPushConsumer#start()方法开始入手，直接定位到最终实现类org.apache.rocketmq.client.impl.consumer.DefaultMQPushConsumerImpl#start方法。

下面来看看在消费者启动后主要开启了哪些组件来工作。

```java
//创建一个Netty客户端和Broker交互用
this.mQClientFactory = MQClientManager.getInstance().getOrCreateMQClientInstance(this.defaultMQPushConsumer, this.rpcHook);
```

首先是老生常谈的网络通信组件：mQClientFactory，一个以Netty为基础构建的NettyClient客户端，负责和Broker构建起网络连接。

```java
//自平衡组件，用于消费者组增加或减少节点时，自动平衡和Topic所有的CustomerQueue分片对应关系
this.rebalanceImpl.setConsumerGroup(this.defaultMQPushConsumer.getConsumerGroup());
this.rebalanceImpl.setMessageModel(this.defaultMQPushConsumer.getMessageModel());
this.rebalanceImpl.setAllocateMessageQueueStrategy(this.defaultMQPushConsumer.getAllocateMessageQueueStrategy());
this.rebalanceImpl.setmQClientFactory(this.mQClientFactory);
```

然后是这个rebalanceImpl组件，他的具体实现类是RebalancePushImpl，作用呢是用于自动平衡消费者分组节点数量变化和Topic的CustomerQueue分片数量之间的对应关系，保证每个消费者节点消费的Topic消息数量尽量均衡。不会出现新增的消费者节点收不到Topic消息，或者大部分消息只会倾斜在某几个消费者节点上。

```java
//信息拉取组件，获取Topic消息用
this.pullAPIWrapper = new PullAPIWrapper(
    mQClientFactory,
    this.defaultMQPushConsumer.getConsumerGroup(), isUnitMode());
this.pullAPIWrapper.registerFilterMessageHook(filterMessageHookList);
```

这个pullAPIWrapper组件是用于拉取用的，具体来说就是拉取Broker中的Topic消息用的。

```java
//维护topic消息的消费进度，也就是偏移量数据
if (this.defaultMQPushConsumer.getOffsetStore() != null) {
    this.offsetStore = this.defaultMQPushConsumer.getOffsetStore();
} else {
    switch (this.defaultMQPushConsumer.getMessageModel()) {
        case BROADCASTING:
            this.offsetStore = new LocalFileOffsetStore(this.mQClientFactory, this.defaultMQPushConsumer.getConsumerGroup());
            break;
        case CLUSTERING:
            this.offsetStore = new RemoteBrokerOffsetStore(this.mQClientFactory, this.defaultMQPushConsumer.getConsumerGroup());
            break;
        default:
            break;
    }
    this.defaultMQPushConsumer.setOffsetStore(this.offsetStore);
}
this.offsetStore.load();
```

接着是offsetStore对象，这个组件是用于维护topic消息的消费进度，也就是偏移量数据的，保证数据不会重新的消费。

所以消费者在启动后核心工作做了这么几件事：

- 创建NettyClient和Broker节点构建起网络连接
- 使用rebalanceImpl自平衡组件，定期平衡消费者可用节点数和Topic分片的数目对应关系
- 而消费数据依托于pullAPIWrapper组件去拉取消息
- 消费数据后需要记录维护好消费进度



### 一个消费组中的多个Consumer是如何均匀分配消息队列的？

下面我们来聊一聊这个rebalanceImpl自平衡组件是怎么分配消费节点和Topic分片队列的对应关系的。

![image-20230427114234547](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304271142588.png)

如果现在有一个Topic，共3个数据分片，每个分片分散在不同的broker节点中，但是消费者组中只有B2和B2两个消费节点，那么他们会如何分配这3个数据分片呢？

首先，Consumer启动后会向所有的Broker节点注册自己的Consumer信息（当前消费节点会分配到一个cid，消费者id），这样每个broker节点都清楚每个Topic下有哪些分组，每个分组下面有几个消费者节点信息。

然后每个Consumer启动后会立即进行一次自平衡，其实就是随机从某个Broker中获取当前消费组全部的的消费节点列表，然后根据某个MessageQueue分配策略，使用Topic的全部分片列表、Topic的全部消费者分组列表，当前消费者的cid，使用分配策略算法计算出当前消费者节点应该对应哪几个MessageQueue分片。

```java
//获取当前消费节点，在所有消费节点列表中的索引位置
int index = cidAll.indexOf(currentCID);
//使用数据分片总数对消费节点总数取余，获取余数
int mod = mqAll.size() % cidAll.size();
//计算获取每个消费节点平均可以对应几个分片
int averageSize =
    mqAll.size() <= cidAll.size() ? 1 : (mod > 0 && index < mod ? mqAll.size() / cidAll.size()
        + 1 : mqAll.size() / cidAll.size());
//计算出当前消费者需要消费的分片范围
int startIndex = (mod > 0 && index < mod) ? index * averageSize : index * averageSize + mod;
int range = Math.min(averageSize, mqAll.size() - startIndex);
//将计算出的消费分片返回
for (int i = 0; i < range; i++) {
    result.add(mqAll.get((startIndex + i) % mqAll.size()));
}
return result;
```

默认分配的策略对象为AllocateMessageQueueAveragely，是接口AllocateMessageQueueStrategy的实现之一，算法代码如上所示。

自平衡周期默认每隔20秒就会执行一次，通过RebalanceService线程对象执行run方法，可以通过配置参数rocketmq.client.rebalance.waitInterval来修改这个周期。

比如现在一共有3个MessageQueue，然后有2个Consumer，那么此时就会给1个Consumer分配2个MessageQueue，同时给另外1个Consumer分配剩余的1个MessageQueue。

假设有4个MessageQueue的话，那么就可以2个Consumer每个人分配2个MessageQueue了

总之，一切都是平均分配的，尽量保证每个Consumer的负载是差不多的。

当消费者节点知道自己应该从哪几个MessageQueue消费数据时，就可以从对应broker中拉取消息进行消费了。



