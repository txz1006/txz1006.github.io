上一章我们知道service-discovery-registry URL的具体SPI实现类是RegistryProtocol，我们先看看从ServiceConfig到RegistryProtocol的调用链，会发现和injvm本地发布一样，RegistryProtocol也会被同一批四个Wrapper对象进行包装：

![image-20211112160207064](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111121602107.png)

这里提一下QosProtocolWrapper对象，这个对象在当前URL下会开启一个QosServer，端口是2222，主要业务是窗口质量服务，可以让运维通过命令行在线调整、变更、查询dubbo服务的状态。

我们直接定位到这个类的export方法，下面来看看具体是个什么东西：

```java
public class RegistryProtocol implements Protocol {
    public static final String[] DEFAULT_REGISTER_PROVIDER_KEYS = new String[]{"application", "codec", "exchanger", "serialization", "cluster", "connections", "deprecated", "group", "loadbalance", "mock", "path", "timeout", "token", "version", "warmup", "weight", "dubbo", "release"};
    public static final String[] DEFAULT_REGISTER_CONSUMER_KEYS = new String[]{"application", "version", "group", "dubbo", "release"};
    private static final Logger logger = LoggerFactory.getLogger(RegistryProtocol.class);
    private final Map<URL, NotifyListener> overrideListeners = new ConcurrentHashMap();
    private final Map<String, RegistryProtocol.ServiceConfigurationListener> serviceConfigurationListeners = new ConcurrentHashMap();
    private final RegistryProtocol.ProviderConfigurationListener providerConfigurationListener = new RegistryProtocol.ProviderConfigurationListener();
    private final ConcurrentMap<String, RegistryProtocol.ExporterChangeableWrapper<?>> bounds = new ConcurrentHashMap();
    protected Protocol protocol;
    protected RegistryFactory registryFactory;
    protected ProxyFactory proxyFactory;
    private ConcurrentMap<URL, ReExportTask> reExportFailedTasks = new ConcurrentHashMap();
    private HashedWheelTimer retryTimer;
    private static RegistryProtocol INSTANCE;

    public void setProtocol(Protocol protocol) {
        this.protocol = protocol;
    }

    public void setRegistryFactory(RegistryFactory registryFactory) {
        this.registryFactory = registryFactory;
    }

    public void setProxyFactory(ProxyFactory proxyFactory) {
        this.proxyFactory = proxyFactory;
    }

    public <T> Exporter<T> export(final Invoker<T> originInvoker) throws RpcException {
        //获取当前URL对象
        URL registryUrl = this.getRegistryUrl(originInvoker);
        //获取接口原始URL对象
        URL providerUrl = this.getProviderUrl(originInvoker);
        //根据原始URL设置一个覆盖发布URL
        //例如：provider://192.168.152.86:20880/org.apache.dubbo.samples.basic.api.DemoService?anyhost=true&application=demo-provider&bind.ip=192.168.152.86&bind.port=20880&category=configurators&check=false&deprecated=false&dubbo=2.0.2&dynamic=true&generic=false&interface=org.apache.dubbo.samples.basic.api.DemoService&metadata-type=remote&methods=testVoid,sayHello&pid=12176&release=3.0.2.1&service-name-mapping=true&side=provider&timestamp=1636686369917&token=0854708b-e331-4d85-aaf3-7d648e29514e
        URL overrideSubscribeUrl = this.getSubscribedOverrideUrl(providerUrl);
        //处理订阅服务的监听对象
        RegistryProtocol.OverrideListener overrideSubscribeListener = new RegistryProtocol.OverrideListener(overrideSubscribeUrl, originInvoker);
        this.overrideListeners.put(overrideSubscribeUrl, overrideSubscribeListener);
        providerUrl = this.overrideUrlWithConfig(providerUrl, overrideSubscribeListener);
        //进行具体dubbo接口的发布工作(这里的发布是DubboProtocol)
        RegistryProtocol.ExporterChangeableWrapper<T> exporter = this.doLocalExport(originInvoker, providerUrl);
        //获取注册服务对象
        Registry registry = this.getRegistry(registryUrl);
        //获取注册服务提供者的URL
        URL registeredProviderUrl = this.getUrlToRegistry(providerUrl, registryUrl);
        boolean register = providerUrl.getParameter("register", true);
        //是否需要判断当前dubbo服务是否需要注册
        if (register) {
            //向注册中心注册，这里指的zookeeper
            this.register(registry, registeredProviderUrl);
        }

        this.registerStatedUrl(registryUrl, registeredProviderUrl, register);
        exporter.setRegisterUrl(registeredProviderUrl);
        exporter.setSubscribeUrl(overrideSubscribeUrl);
        registry.subscribe(overrideSubscribeUrl, overrideSubscribeListener);
        this.notifyExport(exporter);
        return new RegistryProtocol.DestroyableExporter(exporter);
    }
    //......
    private <T> RegistryProtocol.ExporterChangeableWrapper<T> doLocalExport(final Invoker<T> originInvoker, URL providerUrl) {
        String key = this.getCacheKey(originInvoker);
        return (RegistryProtocol.ExporterChangeableWrapper)this.bounds.computeIfAbsent(key, (s) -> {
            Invoker<?> invokerDelegate = new RegistryProtocol.InvokerDelegate(originInvoker, providerUrl);
            return new RegistryProtocol.ExporterChangeableWrapper(this.protocol.export(invokerDelegate), originInvoker);
        });
    }
}
```

这个方法引入了RegistryFactory的一套逻辑，这里我们先不管，我们先看最关键的方法**this.doLocalExport(originInvoker, providerUrl)**，这个方法会使用dubbo开头的URL协议再发布一次this.protocol.export(invokerDelegate)，返回一个Exporter后封装成ExporterChangeableWrapper。

由于dubbo开头的URL协议对应的SI实现类是DubboProtocol，所以会再一次嵌套执行：

![image-20211112173035875](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111121730917.png)

我们来看看DubboProtocol是怎么发布的接口：

```java
public class DubboProtocol extends AbstractProtocol {
    public static final String NAME = "dubbo";
    public static final int DEFAULT_PORT = 20880;
    private static final String IS_CALLBACK_SERVICE_INVOKE = "_isCallBackServiceInvoke";
    private static DubboProtocol INSTANCE;
    private final Map<String, Object> referenceClientMap = new ConcurrentHashMap();
    private static final Object PENDING_OBJECT = new Object();
    private final Set<String> optimizers = new ConcurrentHashSet();
    
    
    public <T> Exporter<T> export(Invoker<T> invoker) throws RpcException {
        URL url = invoker.getUrl();
        String key = serviceKey(url);
        //创建一个DubboExporter
        DubboExporter<T> exporter = new DubboExporter(invoker, key, this.exporterMap);
        this.exporterMap.put(key, exporter);
        Boolean isStubSupportEvent = url.getParameter("dubbo.stub.event", false);
        Boolean isCallbackservice = url.getParameter("is_callback_service", false);
        if (isStubSupportEvent && !isCallbackservice) {
            String stubServiceMethods = url.getParameter("dubbo.stub.event.methods");
            if ((stubServiceMethods == null || stubServiceMethods.length() == 0) && this.logger.isWarnEnabled()) {
                this.logger.warn(new IllegalStateException("consumer [" + url.getParameter("interface") + "], has set stubproxy support event ,but no stub methods founded."));
            }
        }
		//创建Socket，开启服务端的Netty监听
        this.openServer(url);
        this.optimizeSerialization(url);
        return exporter;
    }
}
```

主要逻辑只有两个，一个是创建DubboExporter，另一个是使用Netty开始服务端的Socket监听。

开启服务的流程我们简单的了解一下：

```java
    private ProtocolServer createServer(URL url) {
        URL url = URLBuilder.from(url).addParameterIfAbsent("channel.readonly.sent", Boolean.TRUE.toString()).addParameterIfAbsent("heartbeat", String.valueOf(60000)).addParameter("codec", "dubbo").build();
        //设置URL中的server关键字，这里默认用的netty
        String str = url.getParameter("server", "netty");
        if (str != null && str.length() > 0 && !ExtensionLoader.getExtensionLoader(Transporter.class).hasExtension(str)) {
            throw new RpcException("Unsupported server type: " + str + ", url: " + url);
        } else {
            ExchangeServer server;
            try {
                //创建server
                server = Exchangers.bind(url, this.requestHandler);
            } catch (RemotingException var5) {
                throw new RpcException("Fail to start server(url: " + url + ") " + var5.getMessage(), var5);
            }

            str = url.getParameter("client");
            if (str != null && str.length() > 0) {
                Set<String> supportedTypes = ExtensionLoader.getExtensionLoader(Transporter.class).getSupportedExtensions();
                if (!supportedTypes.contains(str)) {
                    throw new RpcException("Unsupported client type: " + str);
                }
            }

            return new DubboProtocolServer(server);
        }
    }
```

我们找到关键方法**Exchangers.bind(url, this.requestHandler)**来继续分析：

```java
   public static ExchangeServer bind(URL url, ExchangeHandler handler) throws RemotingException {
        if (url == null) {
            throw new IllegalArgumentException("url == null");
        } else if (handler == null) {
            throw new IllegalArgumentException("handler == null");
        } else {
            url = url.addParameterIfAbsent("codec", "exchange");
            return getExchanger(url).bind(url, handler);
        }
    }
    
    public static Exchanger getExchanger(URL url) {
        String type = url.getParameter("exchanger", "header");
        return getExchanger(type);
    }

    public static Exchanger getExchanger(String type) {
        return (Exchanger)ExtensionLoader.getExtensionLoader(Exchanger.class).getExtension(type);
    }
```

这里有一层服务端的选择层Exchanger对象来决定到底怎么创建监听连接，由于当前URL协议没有exchanger的关键字，所以默认使用header，则对应SPI配置文件中的实现类是HeaderExchanger，代码如下：

```java
public class HeaderExchanger implements Exchanger {
    public static final String NAME = "header";

    public HeaderExchanger() {
    }

    public ExchangeClient connect(URL url, ExchangeHandler handler) throws RemotingException {
        return new HeaderExchangeClient(Transporters.connect(url, new ChannelHandler[]{new DecodeHandler(new HeaderExchangeHandler(handler))}), true);
    }
	//bind调用的就是这个方法
    public ExchangeServer bind(URL url, ExchangeHandler handler) throws RemotingException {
        return new HeaderExchangeServer(Transporters.bind(url, new ChannelHandler[]{new DecodeHandler(new HeaderExchangeHandler(handler))}));
    }
}
```

我们继续分析Transporters.bind(X,X)的逻辑：

```java
public static RemotingServer bind(URL url, ChannelHandler... handlers) throws RemotingException {
    if (url == null) {
        throw new IllegalArgumentException("url == null");
    } else if (handlers != null && handlers.length != 0) {
        Object handler;
        if (handlers.length == 1) {
            handler = handlers[0];
        } else {
            handler = new ChannelHandlerDispatcher(handlers);
        }

        return getTransporter().bind(url, (ChannelHandler)handler);
    } else {
        throw new IllegalArgumentException("handlers == null");
    }
}

public static Transporter getTransporter() {
    return (Transporter)ExtensionLoader.getExtensionLoader(Transporter.class).getAdaptiveExtension();
}
```



这里又有一层Transporter动态配置对象，可以让我们来选择具体的Transporter，因为当前URl协议中的关键字是netty，所以对应实现类是NettyTransporter，我们来看一下：

```java
//netty=org.apache.dubbo.remoting.transport.netty4.NettyTransporter
public class NettyTransporter implements Transporter {
    public static final String NAME = "netty";

    public NettyTransporter() {
    }

    //创建具体的Netty服务
    public RemotingServer bind(URL url, ChannelHandler handler) throws RemotingException {
        return new NettyServer(url, handler);
    }

    public Client connect(URL url, ChannelHandler handler) throws RemotingException {
        return new NettyClient(url, handler);
    }
}
```

到这里就是Netty具体的服务开启，端口绑定相关的工作了，我们先到此为止，后续对于Netty我们再具体的学习。

