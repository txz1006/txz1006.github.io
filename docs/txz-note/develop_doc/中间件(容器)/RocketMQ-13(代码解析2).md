### Namesrv启动流程

现在我们开始逐步分析Namesrv启动的流程，在实际的MQ启动中是依赖于脚本来启动的，windows下使用cmd脚本，Linux下使用sh脚本，Namesrv服务的启动脚本是mqnamesrv.sh，我们可以在distribution模块下的bin目录下看到这些启动脚本：

![image-20230411165803228](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111658280.png)

在mqnamesrv.sh脚本中，最重要的只有最后一行命令，其他的可以暂时不用关注。

```
sh ${ROCKETMQ_HOME}/bin/runserver.sh org.apache.rocketmq.namesrv.NamesrvStartup $@
```

这行脚本又调用了runserver.sh脚本，并以此脚本来触发org.apache.rocketmq.namesrv.NamesrvStartup启动类。

![image-20230411170307995](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111703042.png)

### NamesrvStartup启动流程分析

#### NamesrvStartup的主要作用

在具体分析代码前，我们先要想清楚一件事，就是NamesrvStartup是会启动一个NameServer的路由JVM服务，回忆一下之前学习到的NameServer的主要功能是什么：

- 接收Broker节点的注册和心跳请求，监控维护好Broker集群的健康状况
- 提供接口给生产者集群和消费者集群，用于从NameServer服务中拉取最新的broker路由信息

清楚NameServer的主要功能后，我们就可以大概得猜到NamesrvStartup启动类的大概逻辑了，再加上我们知道RocketMQ是基于Netty组件来作为网络通信基础的，所以，NamesrvStartup启动类一定是启动一个Netty网络服务，用来给Broker集群、生产者集群和消费者集群提供请求、注册，存储三方路由状态信息的用的。

![image-20230411174327805](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304111743847.png)

下面我们来根据具体代码来验证这个猜想。在学习的过程中，带着问题去寻找答案可能会让我们的学习目标更加的清晰明确。

我们从org.apache.rocketmq.namesrv.NamesrvStartup的main方法开始入手，这个入口方法执行了**main0(args);**方法，这个方法代码如下：

![image-20230412094451386](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304120944733.png)

在上面的代码中，只有红框标注的两行是关键代码，从代码意义来看，这两行代码的主要作用是创建一个名为NamesrvController的组件，然后在第二行启动了这个组件。

换句话说Namesrv服务核心是这个NamesrvController组件来完成的，示意图如下：

![image-20230412095416486](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304120954526.png)

根据我们之前的猜测，可以预想到在这个NamesrvController组件中，一定会创建一个Netty服务，下面我们就来进一步分析NamesrvController组件的代码来印证这一点。

#### NamesrvController是如何创建的

NamesrvController组件是通过静态方法org.apache.rocketmq.namesrv.NamesrvStartup#createNamesrvController(...)来创建的，我们可以初步看一下这个方法的主要逻辑：

```java
public static NamesrvController createNamesrvController(String[] args) throws IOException, JoranException {
    System.setProperty(RemotingCommand.REMOTING_VERSION_KEY, Integer.toString(MQVersion.CURRENT_VERSION));
    //PackageConflictDetect.detectFastjson();

    Options options = ServerUtil.buildCommandlineOptions(new Options());
    commandLine = ServerUtil.parseCmdLine("mqnamesrv", args, buildCommandlineOptions(options), new PosixParser());
    if (null == commandLine) {
        System.exit(-1);
        return null;
    }

    final NamesrvConfig namesrvConfig = new NamesrvConfig();
    final NettyServerConfig nettyServerConfig = new NettyServerConfig();
    nettyServerConfig.setListenPort(9876);
    if (commandLine.hasOption('c')) {
        String file = commandLine.getOptionValue('c');
        if (file != null) {
            InputStream in = new BufferedInputStream(new FileInputStream(file));
            properties = new Properties();
            properties.load(in);
            MixAll.properties2Object(properties, namesrvConfig);
            MixAll.properties2Object(properties, nettyServerConfig);

            namesrvConfig.setConfigStorePath(file);

            System.out.printf("load config properties file OK, %s%n", file);
            in.close();
        }
    }

    if (commandLine.hasOption('p')) {
        InternalLogger console = InternalLoggerFactory.getLogger(LoggerName.NAMESRV_CONSOLE_NAME);
        MixAll.printObjectProperties(console, namesrvConfig);
        MixAll.printObjectProperties(console, nettyServerConfig);
        System.exit(0);
    }

    MixAll.properties2Object(ServerUtil.commandLine2Properties(commandLine), namesrvConfig);

    if (null == namesrvConfig.getRocketmqHome()) {
        System.out.printf("Please set the %s variable in your environment to match the location of the RocketMQ installation%n", MixAll.ROCKETMQ_HOME_ENV);
        System.exit(-2);
    }

    LoggerContext lc = (LoggerContext) LoggerFactory.getILoggerFactory();
    JoranConfigurator configurator = new JoranConfigurator();
    configurator.setContext(lc);
    lc.reset();
    configurator.doConfigure(namesrvConfig.getRocketmqHome() + "/conf/logback_namesrv.xml");

    log = InternalLoggerFactory.getLogger(LoggerName.NAMESRV_LOGGER_NAME);

    MixAll.printObjectProperties(log, namesrvConfig);
    MixAll.printObjectProperties(log, nettyServerConfig);

    final NamesrvController controller = new NamesrvController(namesrvConfig, nettyServerConfig);

    // remember all configs to prevent discard
    controller.getConfiguration().registerConfig(properties);

    return controller;
}
```

这个方法的代码很长，可能初次看到会感觉很头大，不清楚应该如何入手，这里可以给大家一些看源码的建议：

- 我们的专注点应该先放到源码框架的主体流程上，主要搞清楚一个服务启动后，会创建多少个组件，这些组件的关系是怎么样的，以及这些组件的主要功能是什么。
- 搞清楚服务组件构成后，可以启动这个服务，根据官方介绍的框架使用场景，每个场景跑一个Demo，然后Debug源码，摸索出每个场景的代码执行链路；主要关注链路执行过程中，每个部分的功能是依赖哪个组件完成的。
- 学习源码的流程应该和看书一样，先理解框架的主干流程，初步搞清楚框架组件结构，不理解的部分可以先跳过，不要陷入到某个细节功能的实现中，这样就是舍本逐末了，对于过程中不理解的地方，和感兴趣的功能可以先记录下来，等了解到框架大体全貌之后，再对于之前的问题一一学习研究总结。
  等同于先构建一个认知系统，有主体结构，然后在分步学习中每个结构的内容，补充系统内容。
- 源码组件、变量、方法的名称一般就说明了这块的代码是做什么的，我们可以先把这些代码当做一个黑箱子，猜一下主要功能就可以略过去了。

清楚了如何读源码后，我们再看上面的createNamesrvController方法代码，就会发现逻辑分布比较清晰了：

首先，涉及commandLine变量的就是解析启动NamesrvStartup类的的配置参数的，**commandLine.hasOption('c')**是处理 **java -c**命令参数的，**commandLine.hasOption('p')**是处理**java -p**命令参数的，这些参数经过解析后到放到了局部变量namesrvConfig和nettyServerConfig对象中。

所以这个createNamesrvController方法主要逻辑代码就只有这几行：

```java
//创建一个Namesrv配置对象，一个NettyServer配置对象，设置NettyServer监听端口为9876
final NamesrvConfig namesrvConfig = new NamesrvConfig();
final NettyServerConfig nettyServerConfig = new NettyServerConfig();
nettyServerConfig.setListenPort(9876);
//解析脚本-c、-p命令参数放到已上两个组件容器中
//...
//使用已上两个对象创建NamesrvController
final NamesrvController controller = new NamesrvController(namesrvConfig, nettyServerConfig);

```

#### NamesrvConfig和NettyServerConfig有什么

我们可以先看看NamesrvController的两个核心配置类有哪些东西，先来看看NamesrvConfig配置类。

![image.png](http://wechatapppro-1252524126.cdn.xiaoeknow.com/image/ueditor/35265300_1581347522.png?imageView2/2/q/80%7CimageMogr2/ignore-error/1)

这个类主要记录几个MQ的配置文件路径信息，和几个MQ的全局配置参数，没有太多复杂的地方。

![image.png](http://wechatapppro-1252524126.cdn.xiaoeknow.com/image/ueditor/57128200_1581347522.png?imageView2/2/q/80%7CimageMogr2/ignore-error/1)

而NettyServerConfig则记录一些Netty服务的主要配置信息，包括监听端口，各种线程池线程数，网络通信缓冲区配置，IO模型等等。如果大家对于Netty不太熟悉，可以先去补充学习一下相关知识；亦或者先不用关系太多细节，只用知道Netty是用来做网络通信的组件即可，RocketMQ是依靠Netty组件来完成接收处理各方请求的。

实际上，我们也可以根据NameServer的启动日志来看到上面配置对象运行时的具体值，在之前MQ根目录下的logs目录中找到namesrv.log日志文件：

![image-20230412114158301](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304121141353.png)

到现在我们已经初步梳理出了NamesrvController组件的主要构成逻辑：

![image-20230412113948858](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304121139909.png)

#### NamesrvController组件还包含什么

在NamesrvController对象被实例化出来后，就可以直接用了吗？里面的Netty服务启动了没有？下面我们来研究下这些问题，首先是NamesrvController的构造方法，代码如下：

![image-20230412115312391](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304121153427.png)

我们可以看到在NamesrvController对象构造方法中，没有执行任何业务，而且NamesrvController组件也不仅仅依赖NamesrvConfig、NettyServerConfig两个配置，还有还有其他四个成员变量对象被创建出来，这些对象可以先有个印象，等被用到的时候再进行分析。

到这里就可以回答Netty服务启动了没有的问题了，答案是并没有，那么Netty服务到底是在哪启动的呢？

还记得NamesrvController对象被创建后的下一步动作吗，也就是在**start(controller)**方法中，Netty服务启动才会被启动起来。

```java
NamesrvController controller = createNamesrvController(args);
start(controller);
```

#### NamesrvController是怎么启动Netty服务的

我们接着看**start(controller)**方法的代码，是如何启动Netty服务的：

```java
public static NamesrvController start(final NamesrvController controller) throws Exception {

    if (null == controller) {
        throw new IllegalArgumentException("NamesrvController is null");
    }
	//NamesrvController初始化
    boolean initResult = controller.initialize();
    if (!initResult) {
        controller.shutdown();
        System.exit(-3);
    }
	//设置JVM关闭挂钩，当JVM关闭时也关闭NamesrvController对象
    Runtime.getRuntime().addShutdownHook(new ShutdownHookThread(log, new Callable<Void>() {
        @Override
        public Void call() throws Exception {
            controller.shutdown();
            return null;
        }
    }));
	//启动NamesrvController
    controller.start();
    return controller;
}
```

以上代码关键步骤就两步，一步是**controller.initialize()**，对创建的NamesrvController对象，进行初始化。第二步是

**controller.start()**，在初始化后执行启动命令，Netty服务要么是在第一步初始化中启动的，要么就是在第二步start流程中启动的，下面我们进一步来具体分析。

#### NamesrvController是如何初始化的

继续查看**controller.initialize()**的具体代码，我们就知道初始化到底做了哪些事情：

```java
public boolean initialize() {

    this.kvConfigManager.load();

    this.remotingServer = new NettyRemotingServer(this.nettyServerConfig, this.brokerHousekeepingService);
 
    //省略若干代码
}
```

这个方法代码也有些长，这里我们只截取了最核心的几行代码片段，主要逻辑就是创建一个RemotingServer网络通信对象，这个对象具体是NettyRemotingServer类的实例，也就是Netty服务的对象是在NamesrvController初始化的过程中创建的。

而NettyRemotingServer类又做了什么呢，我们进入到这个类构造方法看看：

```java
public NettyRemotingServer(final NettyServerConfig nettyServerConfig,
    final ChannelEventListener channelEventListener) {
    super(nettyServerConfig.getServerOnewaySemaphoreValue(), nettyServerConfig.getServerAsyncSemaphoreValue());
    this.serverBootstrap = new ServerBootstrap();
 //省略若干代码
    
}
```

这个类的关键代码就只有一行**this.serverBootstrap = new ServerBootstrap();**

这行代码就是使用Netty框架创建一个网络通信对象，后续的IO线程池、监听端口，网络请求处理链路，都是在ServerBootstrap实例对象的基础上操作的。

#### NamesrvController的start方法做了什么

我们回到org.apache.rocketmq.namesrv.NamesrvController#start()启动方法中，看看启动是如何实现的：

```java
public void start() throws Exception {
    this.remotingServer.start();

    if (this.fileWatchService != null) {
        this.fileWatchService.start();
    }
}
```

这个代码就很好懂了，NamesrvController#start()方法调用的NettyRemotingServer#start()方法，也就是说NamesrvController的初始化和启动两步主要就是创建和启动NettyRemotingServer这个Netty服务。

下面我们继续分析NettyRemotingServer#start()方法的代码：

```java
ServerBootstrap childHandler =
    this.serverBootstrap.group(this.eventLoopGroupBoss, this.eventLoopGroupSelector)
        .channel(useEpoll() ? EpollServerSocketChannel.class : NioServerSocketChannel.class)
        .option(ChannelOption.SO_BACKLOG, 1024)
        .option(ChannelOption.SO_REUSEADDR, true)
        .option(ChannelOption.SO_KEEPALIVE, false)
        .childOption(ChannelOption.TCP_NODELAY, true)
        .childOption(ChannelOption.SO_SNDBUF, nettyServerConfig.getServerSocketSndBufSize())
        .childOption(ChannelOption.SO_RCVBUF, nettyServerConfig.getServerSocketRcvBufSize())
        .localAddress(new InetSocketAddress(this.nettyServerConfig.getListenPort()))
        .childHandler(new ChannelInitializer<SocketChannel>() {
            @Override
            public void initChannel(SocketChannel ch) throws Exception {
                ch.pipeline()
                    .addLast(defaultEventExecutorGroup, HANDSHAKE_HANDLER_NAME, handshakeHandler)
                    .addLast(defaultEventExecutorGroup,
                        encoder,
                        new NettyDecoder(),
                        new IdleStateHandler(0, 0, nettyServerConfig.getServerChannelMaxIdleTimeSeconds()),
                        connectionManageHandler,
                        serverHandler
                    );
            }
        });

if (nettyServerConfig.isServerPooledByteBufAllocatorEnable()) {
    childHandler.childOption(ChannelOption.ALLOCATOR, PooledByteBufAllocator.DEFAULT);
}

try {
    ChannelFuture sync = this.serverBootstrap.bind().sync();
    InetSocketAddress addr = (InetSocketAddress) sync.channel().localAddress();
    this.port = addr.getPort();
} catch (InterruptedException e1) {
    throw new RuntimeException("this.serverBootstrap.bind().sync() InterruptedException", e1);
}
```

这个是Start方法的核心代码片段，主要逻辑是给ServerBootstrap对象设置各种配置参数，端口信息，请求处理通道对象等等，比如**localAddress(new InetSocketAddress(this.nettyServerConfig.getListenPort()))**就会将之前外部设置9876端口设置到ServerBootstrap中，之后的connectionManageHandler,serverHandler等对象都是Netty的请求处理Channel链路对象，这些Channel可以简单理解为SpringMVC中的controllor，只不过Channel链路是多个Channel处理类构成，每一次请求都会经过所有的Channel对象处理。

所里，这里我们可以细化我们的流程图了：

![image-20230412142245670](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202304121422717.png)

