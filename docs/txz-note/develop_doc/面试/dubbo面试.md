dubbo面试

dubbo面试
dubbo是一个分布式rpc框架，即可以让服务和服务之间进行rpc数据接口交互，就绪访问本地方法一样。
dubbo提供有赋值均衡策略和机器容错策略，可使服务调用变得高可用化。
dubbo一般而言需要使用三方服务发现组件(redis、zk、Simple、Multicast)来用作动态服务记录，不需要维护静态的配置了。

（1）dubbo工作原理

第一层：service层，接口层，给服务提供者和消费者来实现的

第二层：config层，配置层，主要是对dubbo进行各种配置的

第三层：proxy层(破绕洗)，服务代理层，透明生成客户端的stub和服务单的skeleton

第四层：registry层（ruai嘴思吹），服务注册层，负责服务的注册与发现

第五层：cluster层（克拉斯特），集群层，封装多个服务提供者的路由以及负载均衡，将多个实例组合成一个服务

第六层：monitor层（模拟特），监控层，对rpc接口的调用次数和调用时间进行监控

第七层：protocol层（破瑞特扣），远程调用层，封装rpc调用

第八层：exchange层（渴死称职），信息交换层，封装请求响应模式，同步转异步

第九层：transport层（穿丝剥特），网络传输层，抽象mina和netty为统一接口

第十层：serialize层（希瑞来自），数据序列化层

工作流程：

1）第一步，provider向注册中心去注册

2）第二步，consumer从注册中心订阅服务，注册中心会通知consumer注册好的服务

3）第三步，consumer调用provider

4）第四步，consumer和provider都异步的通知监控中心

（2）注册中心挂了可以继续通信吗？

可以，因为刚开始初始化的时候，消费者会将提供者的地址等信息拉取到本地缓存，所以注册中心挂了可以继续通信

1.  dubbo的负载均衡策略
    random loadbalance 根据每台机器设置的权重随机给服务端调用请求，权重越高流量越多(一般默认用这个就行)

roundrobin loadbalance 根据每台机器数量，进行请求轮询，也就是每台机器份到的流量差不多；当然也可以调整每台机器的权重，进行流量倾斜。

leastactive loadbalance 该策略下dubbo会自动判断每台机器处理请求的情况，然后给性能差的机器分片尽量少的请求

consistanthash loadbalance 该策略使用hash一致性算法，也就行根据请求参数，会将参数相同的请求发送到同一台服务器上。

2.  dubbo支持的通信协议有那些？

hession(序列化框架)、json(http通信)、SOAP(webservice)、java二进制(序列化)等，默认是hession序列化协议

3.  dubbo的集群容错策略

failover cluster模式，该策略下dubbo如果调用请求失败了会自动将请求发送到其他的机器进行重试，默认就是这个策略

failfast cluster模式，该模式下，如果调用服务失败了会直接报错，不再重试

failsafe cluster模式，该模式下，如果调用服务失败了会直接忽略，用于不重要数据服务的调用

failbackc cluster模式，该模式下，如果调用服务失败了，dubbo会将请求记录效率，然后定时重发，常用于消息对象

forking cluster模式，该模式下，dubbo会给所有服务器发送请求，但只接受第一个返回的请求结果

broadcacst cluster模式，该模式下，dubbo会依次给所有服务器发送请求

4.  dubbo的服务治理
 服务调用链路自动生成
服务接口请求压力信息(请求次数、请求延迟等)统计

服务降级

5.  dubbo如何保证连续请求的顺序一致性？

使用hash分发负载策略，即设置同一标识让dubbo将这批请求发送到同一台服务器上。

如果单台机器使用了多线程处理，那么最好给每个线程设置一个任务队列，让任务有序消费；这样线序的请求再通过hash分发瞳同一个内存队列中，有同一个线程来按顺序处理。


6. SPI机制？

SPI机制是一种动态可插拔实现类的扩展机制，即规则放只指定接口及其方法，实现类由各第三方来实现，使用时，将三方实现类打成jar(还需要在META/service/接口名文件中指定对应实现类路径)包放入项目依赖中。
启动项目，使用ServiceLoader.load(接口名.class)可以获取到META/service下的接口名文件中的实现类实例。
常见的实例就是数据库的jdbc.jar中的实现