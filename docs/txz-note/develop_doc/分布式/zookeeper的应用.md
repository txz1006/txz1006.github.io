Zookeeper的应用

#### 数据结构

zk的数据结构是一个类似于文件系统的树结构，每个节点都是一个Znode对象，能够存储数据。初始状态只有一个根节点/，让我们写入数据到zk后，会将写入数据创建为一个新的Znode节点挂在根节点下面，以此类推会创建出一个多层级的树结构Znode结构。

#### Znode类别

zk的节点类型一般来说有三种：

**持久化节点**：创建的节点会被持久化的磁盘中

**临时节点**：节点生命周期和创建该节点的客户端生命周期相同，只有客户端主动发出删除命令或者客户端异常与zk断开连接时，临时节点才会被删除

**有序节点**：每创建一个节点，会给改节点分配一个递增的序列号，该序列号在同一级的节点中是唯一的，上面的持久化节点和临时节点都可以设置为有序节点

#### Watcher机制

像ZK这种服务发现，最重要的功能就是需要动态的感知数据的变化，并给连接的客户端发送通知，这个功能在ZK中是就是Watcher机制。当Znode节点的数据状态发生变化或者客户端的连接状态发生变化是就会触发事件通知机制，一般来说常用的事件有三种：

- getData()，被监听的节点发生增、删、改操作时，通过getData()获取节点的变化情况。
- getChildren()，被监听的节点发生增、删、改操作时，通过getChildren()获取监听节点的所有子节点
- exists()，监听节点是否还存在

#### ZK的实际使用

- 临时节点的使用

  同一时间内连接zk的所有客户端，只能有一个客户端创建同名节点成功。利用该特性可以作为分布式锁使用，比如Master选举，ZK集群中，多个ZK创建一个/master节点，创建成功的就是Master节点，剩下的是Slave节点。

  

- 作为例如dubbo等服务的注册中心

  ZK会完成如下的功能：服务数据注册记录、心跳检查各客户端连接状态、服务注册数据读取能力、服务注册数据变更后的通知功能。

  dubbo生产者，将接口服务和客户端地址信息注册到ZK当中，供消费者RPC调用；其中接口服务是持久化数据、客户端信息是临时节点数据。

  dubbo消费者根据dubbo.cloud.subscribed-services指向dubbo生产者服务的应用名称就可以完成订阅(多个用逗号分开)，dubbo服务应用可以同名，但是dubbo端口要不同，这样消费端指向同一个dubbo服务名就可以完成负载均衡。

dubbo还提供其他高级特性：

服务容错：RPC调用异常情况下兜底功能：比如：再次重试请求、抛出异常、忽略异常、记录异常的请求等等

负载均衡策略：多个生产者提供了同一接口服务时，dubbo消费者会获取所有的服务地址，通过某种负载策略选择其中一个生产者地址进行请求；常见策略有随机算法、轮训算法、Hash算法、最小活跃算法等。

@Service(cluster="failfast", loadbalance="roundrobin")

服务降级：在RPC调用失败的情况下，提供一个静态数据或旧版本数据返回给用户

