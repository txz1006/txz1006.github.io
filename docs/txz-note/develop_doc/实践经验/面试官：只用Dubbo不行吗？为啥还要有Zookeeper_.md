面试官：只用Dubbo不行吗？为啥还要有Zookeeper?

## 面试官：只用Dubbo不行吗？为啥还要有Zookeeper?

[![](https://upload.jianshu.io/users/upload_avatars/16826084/a89e8c30-426d-4082-aa86-ff733fa5c407.jpg?imageMogr2/auto-orient/strip|imageView2/1/w/96/h/96/format/webp)](https://www.jianshu.com/u/94111742c97c)

82019.06.05 21:07:14字数 1,557阅读 8,876

![](https://upload-images.jianshu.io/upload_images/16826084-dc09959f3da153aa.jpg?imageMogr2/auto-orient/strip|imageView2/2/w/1200/format/webp)

> **点关注，不迷路；持续更新Java架构相关技术及资讯热文！！！**

## 介绍

微服务是最近比较火的概念，而微服务框架目前主流的有Dubbo和Spring Cloud，两者都是为了解决微服务遇到的各种问题而产生的，即遇到的问题是一样的，但是解决的策略却有所不同，所以这2个框架经常拿来比较。没用过Dubbo的小伙伴也不用担心，其实Dubbo还是比较简单的，看完本文你也能掌握一个大概，重要的不是代码，而是思想。

Dubbo实现服务调用是通过RPC的方式，即客户端和服务端共用一个接口(将接口打成一个jar包，在客户端和服务端引入这个jar包)，客户端面向接口写调用，服务端面向接口写实现，中间的网络通信交给框架去实现，想深入了解的看推荐阅读。原文链接有代码GitHub地址

## 使用入门

**服务提供者**

定义服务接口

![](https://upload-images.jianshu.io/upload_images/16826084-938bda44fe0fae98.png?imageMogr2/auto-orient/strip|imageView2/2/w/229/format/webp)

在服务提供方实现接口

![](https://upload-images.jianshu.io/upload_images/16826084-9498797ce691575d.png?imageMogr2/auto-orient/strip|imageView2/2/w/335/format/webp)

用 Spring 配置声明暴露服务

provider.xml（省略了beans标签的各种属性）

![](https://upload-images.jianshu.io/upload_images/16826084-74fa4ca744cadecf.png?imageMogr2/auto-orient/strip|imageView2/2/w/453/format/webp)

加载 Spring 配置

![](https://upload-images.jianshu.io/upload_images/16826084-3fe44fc860bf7423.png?imageMogr2/auto-orient/strip|imageView2/2/w/580/format/webp)

**服务消费者**

consumer.xml

![](https://upload-images.jianshu.io/upload_images/16826084-8248869a6b52b194.png?imageMogr2/auto-orient/strip|imageView2/2/w/423/format/webp)

加载Spring配置，并调用远程服务

![](https://upload-images.jianshu.io/upload_images/16826084-d638916238695b2f.png?imageMogr2/auto-orient/strip|imageView2/2/w/577/format/webp)

这就是典型的点对点的服务调用。当然我们为了高可用，可以在consumer.xml中配置多个服务提供者，并配置响应的负载均衡策略

配置多个服务调用者在comsumer.xml的&lt;dubbo:reference&gt;标签的url属性中加入多个地址，中间用分号隔开即可

配置负载均衡策略在comsumer.xml的&lt;dubbo:reference&gt;标签中增加loadbalance属性即可，值可以为如下四种类型

1.  RoundRobin LoadBalance，随机，按权重设置随机概率。
2.  RoundRobin LoadBalance，轮询，按公约后的权重设置轮询比率。
3.  LeastActive LoadBalance，最少活跃调用数，相同活跃数的随机，活跃数指调用前后计数差。
4.  ConsistentHash LoadBalance，一致性 Hash，相同参数的请求总是发到同一提供者。

![](https://upload-images.jianshu.io/upload_images/16826084-4e0fe1b0093e9370.png?imageMogr2/auto-orient/strip|imageView2/2/w/402/format/webp)

现在整体架构是如下图（假设服务消费者为订单服务，服务提供者为用户服务）：

![](https://upload-images.jianshu.io/upload_images/16826084-4417ba422733b78e.png?imageMogr2/auto-orient/strip|imageView2/2/w/533/format/webp)

**这样会有什么问题呢？**

1.  当服务提供者增加节点时，需要修改配置文件
2.  当其中一个服务提供者宕机时，服务消费者不能及时感知到，还会往宕机的服务发送请求

这个时候就得引入注册中心了

## 注册中心

Dubbo目前支持4种注册中心,（multicast zookeeper redis simple） 推荐使用Zookeeper注册中心，本文就讲一下用zookeeper实现服务注册和发现（敲黑板，又一种zookeeper的用处），大致流程如下

![](https://upload-images.jianshu.io/upload_images/16826084-60be9eb7f5557498.png?imageMogr2/auto-orient/strip|imageView2/2/w/631/format/webp)

现在我们来看Dubbo官网对Dubbo的介绍图，有没有和我们上面画的很相似

![](https://upload-images.jianshu.io/upload_images/16826084-1ffb06b0b7ae44bb.png?imageMogr2/auto-orient/strip|imageView2/2/w/446/format/webp)

**节点角色说明**

![](https://upload-images.jianshu.io/upload_images/16826084-8ca94389f7a5d42b.png?imageMogr2/auto-orient/strip|imageView2/2/w/685/format/webp)

**调用关系说明**

1.  服务容器负责启动（上面例子为Spring容器），加载，运行服务提供者。
2.  服务提供者在启动时，向注册中心注册自己提供的服务。
3.  服务消费者在启动时，向注册中心订阅自己所需的服务。
4.  注册中心返回服务提供者地址列表给消费者，如果有变更，注册中心将基于长连接推送变更数据给消费者。
5.  服务消费者，从提供者地址列表中，基于软负载均衡算法，选一台提供者进行调用，如果调用失败，再选另一台调用。
6.  服务消费者和提供者，在内存中累计调用次数和调用时间，定时每分钟发送一次统计数据到监控中心。

要使用注册中心，只需要将provider.xml和consumer.xml更改为如下

![](https://upload-images.jianshu.io/upload_images/16826084-ab3b0451bfda9b29.png?imageMogr2/auto-orient/strip|imageView2/2/w/421/format/webp)

如果zookeeper是一个集群，则多个地址之间用逗号分隔即可

```
<dubbo:registry protocol="zookeeper" address="192.168.11.129:2181,192.168.11.137:2181,192.168.11.138:2181"/> 
```

把consumer.xml中配置的直连的方式去掉

![](https://upload-images.jianshu.io/upload_images/16826084-7a637c01ea5537fb.png?imageMogr2/auto-orient/strip|imageView2/2/w/440/format/webp)

注册信息在zookeeper中如何保存？

启动上面服务后，我们观察zookeeper的根节点多了一个dubbo节点及其他，图示如下

![](https://upload-images.jianshu.io/upload_images/16826084-a3eb46da5520bb9e.png?imageMogr2/auto-orient/strip|imageView2/2/w/556/format/webp)

最后一个节点中192.168.1.104是小编的内网地址，你可以任务和上面配置的localhost一个效果，大家可以想一下我为什么把最后一个节点标成绿色的。没错，最后一个节点是临时节点，而其他节点是持久节点，这样，当服务宕机时，这个节点就会自动消失，不再提供服务，服务消费者也不会再请求。如果部署多个DemoService，则providers下面会有好几个节点，一个节点保存一个DemoService的服务地址

其实一个zookeeper集群能被多个应用公用，如小编Storm集群和Dubbo配置的就是一个zookeeper集群，为什么呢？因为不同的框架会在zookeeper上建不同的节点，互不影响。如dubbo会创建一个/dubbo节点，storm会创建一个/storm节点，如图

![](https://upload-images.jianshu.io/upload_images/16826084-19f286654ad47ccb.png?imageMogr2/auto-orient/strip|imageView2/2/w/365/format/webp)

## 写在最后

**最后，欢迎做Java的工程师朋友们加入Java高级架构进阶Qqun：963944895**

**群内有技术大咖指点难题，还提供免费的Java架构学习资料（里面有高可用、高并发、高性能及分布式、Jvm性能调优、Spring源码，MyBatis，Netty,Redis,Kafka,Mysql,Zookeeper,Tomcat,Docker,Dubbo,Nginx等多个知识点的架构资料）**

**比你优秀的对手在学习，你的仇人在磨刀，你的闺蜜在减肥，隔壁老王在练腰， 我们必须不断学习，否则我们将被学习者超越！**

**趁年轻，使劲拼，给未来的自己一个交代！**

更多精彩内容，就在简书APP

"小礼物走一走，来简书关注我"

还没有人赞赏，支持一下

[![  ](https://upload.jianshu.io/users/upload_avatars/16826084/a89e8c30-426d-4082-aa86-ff733fa5c407.jpg?imageMogr2/auto-orient/strip|imageView2/1/w/100/h/100/format/webp)](https://www.jianshu.com/u/94111742c97c)

总资产92共写了105.3W字获得2,741个赞共2,200个粉丝

### 被以下专题收入，发现更多相似内容

### 推荐阅读[更多精彩内容](https://www.jianshu.com/)

- 不久前，我们讨论过Nginx+tomcat组成的集群，这已经是非常灵活的集群技术，但是当我们的系统遇到更大的瓶颈，...
    
    [![](https://upload-images.jianshu.io/upload_images/2656621-9d17749acfa16400.jpg?imageMogr2/auto-orient/strip|imageView2/1/w/300/h/240/format/webp)](https://www.jianshu.com/p/4c4328303710)
- 不久前，我们讨论过Nginx+tomcat组成的集群，这已经是非常灵活的集群技术，但是当我们的系统遇到更大的瓶颈，...
    
    [![](https://upload-images.jianshu.io/upload_images/2650014-777a540ab13dec25.jpg?imageMogr2/auto-orient/strip|imageView2/1/w/300/h/240/format/webp)](https://www.jianshu.com/p/fa3e0302c1c4)
- 这个春天，没有赶上看樱花发苞时的初芽，但我赶上了花落满地的浪漫，同样是一个美丽的邂逅。 就如同人生中相遇的人们，在...
    
    [![](https://upload-images.jianshu.io/upload_images/12969534-9ef5b2f93ee85328.jpg?imageMogr2/auto-orient/strip|imageView2/1/w/300/h/240/format/webp)](https://www.jianshu.com/p/db52a79d4ba8)
- Alexander Konovalov Ohio State University konovalov.2@osu...
    
- Java集合框架 Java集合类库也将接口与实现implementation分离 集合类的基本接口是Collect...