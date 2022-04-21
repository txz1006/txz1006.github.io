上一章中我们知道**PROTOCOL.export((Invoker)invoker)**的实际SPI实现类是InjvmProtocol类，下面我们看看他是如何发布一个Invoker对象的。

```java
public class InjvmProtocol extends AbstractProtocol implements Protocol {
    public static final String NAME = "injvm";
    public static final int DEFAULT_PORT = 0;
    private static InjvmProtocol INSTANCE;

    public InjvmProtocol() {
        INSTANCE = this;
    }

    public static InjvmProtocol getInjvmProtocol() {
        if (INSTANCE == null) {
            ExtensionLoader.getExtensionLoader(Protocol.class).getExtension("injvm");
        }

        return INSTANCE;
    }

    public <T> Exporter<T> export(Invoker<T> invoker) throws RpcException {
        return new InjvmExporter(invoker, invoker.getUrl().getServiceKey(), this.exporterMap);
    }
    
    //....
}
```

这里仅显示关键方法export()，发现InjvmProtocol也仅仅是一个单例工作对象，他会把要发布的invoker接口封装成一个InjvmExporter对象。而InjvmExporter也仅仅是一个存储invoker的容器对象，InjvmExporter代码如下：

```java
class InjvmExporter<T> extends AbstractExporter<T> {
    private final String key;
    private final Map<String, Exporter<?>> exporterMap;
    InjvmExporter(Invoker<T> invoker, String key, Map<String, Exporter<?>> exporterMap) {
        super(invoker);
        this.key = key;
        this.exporterMap = exporterMap;
        exporterMap.put(key, this);
    }

    public void afterUnExport() {
        this.exporterMap.remove(this.key);
    }
}
```
需要注意的一点是，所有的发布的本地服务都会记录在InjvmProtocol的this.exporterMap变量中。

此外，在执行InjvmProtocol.export目标方法之前，会有若干个包装对象需要执行，每个包装对象可以认为是对Protocol.export(Invoker)整个流程的一次拦截，可以在包装类中完成对Invoker的加工处理。

![image-20211112100913347](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111121009382.png)

这些包装类的来源我在之前的SPI解析中讲过，这里简单说两句，在SPI接口创建过程中会做三件事情，第一是实例化一个目标SPI接口实现类，这里指的是InjvmProtocol；然后遍历InjvmProtocol类set方法，对其中的SPI接口成员变量创建一个代理类反射注入；最后获取该SPI接口的包装类列表，遍历创建执行将InjvmProtocol包裹起来。

```java
//ExtensionLoader.createExtension(name)方法片段
		//实例化
        T instance = (T) EXTENSION_INSTANCES.get(clazz);
        if (instance == null) {
            EXTENSION_INSTANCES.putIfAbsent(clazz, (T) clazz.newInstance());
            instance = (T) EXTENSION_INSTANCES.get(clazz);
        }
        //SPI属性初始化赋值
        injectExtension(instance);
        //是否存在实例的包装对象，如果存在则构建一个包装实例对象并返回
        Set<Class<?>> wrapperClasses = cachedWrapperClasses;
        if (wrapperClasses != null && wrapperClasses.size() > 0) {
            for (Class<?> wrapperClass : wrapperClasses) {
                instance = injectExtension((T) wrapperClass.getConstructor(type).newInstance(instance));
            }
        }
```

我们可以在SPI接口配置文件中找到这些包装对象

```xml
filter=org.apache.dubbo.rpc.cluster.filter.ProtocolFilterWrapper
listener=org.apache.dubbo.rpc.protocol.ProtocolListenerWrapper
serializationwrapper=org.apache.dubbo.rpc.protocol.ProtocolSerializationWrapper
qos=org.apache.dubbo.qos.protocol.QosProtocolWrapper
```

这些包装类型的执行顺序会按照@Activate注解的order参数进行升序排列(dubbo:3.0.2.1版本)，由于这些包装类只会在现有流程的基础上进行变动，如增加一些过滤对象Filter、增加一些监听对象Listener等，所以基本不影响整个流程的执行，这里就不再一个一个详细深入了，后面会挑重点文档关键对象来说。

--------------------------------

到目前为止，我们知道**PROTOCOL.export((Invoker)invoker)**返回了一个InjvmProtocol对象，具体内容如下：

![image-20211112113006528](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111121130567.png)

发现InjvmProtocol被一个ListenerExporterWrapper包裹了，同时在InjvmProtocol中的invoker也包裹了一个Filter链(Invoker被调用会先走这些过滤对象)，这些工作分别是在ProtocolListenerWrapper对象和ProtocolFilterWrapper对象中完成的，他们扩展增强了整个流程的功能点，我也可以进行模仿，创建一些Wrapper来自定义一些功能。

返回的InjvmProtocol会被记录到ServiceConfig的全局变量**List<Exporter<?>> exporters**中，到目前为止，本地接口服务流程已经走完，但是我们可以发现这个流程和我们之前章节里面的全局流程不对应啊，只走了一半调用链，后面的Netty相关的没有走啊。大家别急，这个流程对应的是远程服务的发布，本地方法的服务不涉及网络部分的功能，继续往后走代码大家会明白的。我们回到org.apache.dubbo.config.ServiceConfig#exportUrl方法，继续执行，发现下面会进行把当前dubbo接口进行远程发布：

![image-20211112114229908](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111121142949.png)

随断点我们来看看远程服务发布到底做了哪些工作：

```java
private URL exportRemote(URL url, List<URL> registryURLs) {
    if (CollectionUtils.isNotEmpty(registryURLs)) {
        Iterator var3 = registryURLs.iterator();
		//遍历registryURLs，每个URL对象都走一次this.doExportUrl方法，
        while(var3.hasNext()) {
            URL registryURL = (URL)var3.next();
            //判断是否是服务发现注册用的URL，是则给原始URL设置一个参数service-name-mapping：true
            if ("service-discovery-registry".equals(registryURL.getProtocol())) {
                url = url.addParameterIfAbsent("service-name-mapping", "true");
            }
		   //只处理非本地接口的URL对象
            if (!"injvm".equalsIgnoreCase(url.getProtocol())) {
                //把注册URL中的dynamic属性设置到原始URL中
                url = url.addParameterIfAbsent("dynamic", registryURL.getParameter("dynamic"));
                //把注册URL中的monitor属性设置到原始URL中
                URL monitorUrl = ConfigValidationUtils.loadMonitor(this, registryURL);
                if (monitorUrl != null) {
                    url = url.putAttribute("monitor", monitorUrl);
                }

                //根据原始接口的URL，判断是否需要给注册URL添加proxy属性
                String proxy = url.getParameter("proxy");
                if (StringUtils.isNotEmpty(proxy)) {
                    registryURL = registryURL.addParameter("proxy", proxy);
                }

                if (logger.isInfoEnabled()) {
                    if (url.getParameter("register", true)) {
                        logger.info("Register dubbo service " + this.interfaceClass.getName() + " url " + url.getServiceKey() + " to registry " + registryURL.getAddress());
                    } else {
                        logger.info("Export dubbo service " + this.interfaceClass.getName() + " to url " + url.getServiceKey());
                    }
                }
				//注意，这里把原始的dubbo接口URL对象作为一个属性放入了注册URL对象中，并且设置了携带元数据参数为true
                this.doExportUrl(registryURL.putAttribute("export", url), true);
            }
        }
    }
    //.....
}
```

这个方法也比较简单，主要逻辑是遍历registryURLs，让每个注册URL对象都执行一遍this.doExportUrl方法。我们回顾下原始URL和registryURLs都是哪些东西：

```
原始URL:
dubbo://192.168.152.86:20880/org.apache.dubbo.samples.basic.api.DemoService?anyhost=true&application=demo-provider&bind.ip=192.168.152.86&bind.port=20880&deprecated=false&dubbo=2.0.2&dynamic=true&generic=false&interface=org.apache.dubbo.samples.basic.api.DemoService&metadata-type=remote&methods=testVoid,sayHello&pid=4276&release=3.0.2.1&side=provider&timestamp=1636507185495&token=bfe447ce-d5cb-4301-8280-6a4da5055ec8
==============================
两个注册URL：
service-discovery-registry://127.0.0.1:2181/org.apache.dubbo.registry.RegistryService?application=demo-provider&dubbo=2.0.2&pid=17748&registry=zookeeper&release=3.0.2.1&timestamp=1636444467260

registry://127.0.0.1:2181/org.apache.dubbo.registry.RegistryService?application=demo-provider&dubbo=2.0.2&pid=17748&registry=zookeeper&release=3.0.2.1&timestamp=1636444467260
```

首先遍历的是service-discovery-registry URL，前面我们已经知道Protocol接口确定实现类的方式是URL.getProtocol()，也就在SPI接口配置文件中寻找关键字是service-discovery-registry的实现类：

```
service-discovery-registry=org.apache.dubbo.registry.integration.RegistryProtocol
```

