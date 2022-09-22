### Dubbo源码解析

#### 1.什么是Dubbo

简单的讲Dubbo是一个RPC框架，和Http协议一样，是可以让系统服务进行TCP/IP数据通信的框架。自从微服务兴起后，大型项目开始进行业务拆分，这样每个业务独立部署互相解耦，既可以根据业务用户数来分配具体服务的流量，也可以让服务之间并行开发加快迭代效率，同时，每个服务可以进行负载均衡，实现项目资源利用率的最大化。

Dubbo就是搭建在服务和服务之间的通信桥梁，他提供了远程通信方式、集群容错机制、负载均衡策略等等功能，只要我们使用Dubbo，那么就可以很大程度上忽略这些非业务的工作量，只需要关心实际业务开发就行，利用Dubbo进行非常简单的配置就可以完成服务之间的数据通信，而且安全可靠。

当然，不使用Dubbo，使用Http等其他通信方式也可以完成这些功能，但是这需要开发者做很多底层的工作，如数据通信格式、负载均衡策略、超时异常重试等等。这些工作Dubbo都已经帮开发者做好了，这就是他价值的体现。

下载dubbo-samples-master工程项目在dubbo-samples-basic子模块中分别启动EmbeddedZooKeeper#start、BasicProvider#main和BasicConsumer#main，然后debug代码调用流程。

#### 2.Dubbo中的SPI机制

Dubbo自己实现了SPI机制，这个功能比JDK提供的SPI功能更加强大，他可以指定接口要加载的具体实现类对象。下面就这个SPI机制来分析源码。

我们先来看看Dubbo中SPI机制的使用：

首先给接口指定一个SPI注解，并指定SPI注解具体的实现类

```java
@SPI("dubbo")
public interface Protocol {
    
    /**
     * 获取缺省端口，当用户没有配置端口时使用。
     * 
     * @return 缺省端口
     */
    int getDefaultPort();

    /**
     * 暴露远程服务：<br>
     * 1. 协议在接收请求时，应记录请求来源方地址信息：RpcContext.getContext().setRemoteAddress();<br>
     * 2. export()必须是幂等的，也就是暴露同一个URL的Invoker两次，和暴露一次没有区别。<br>
     * 3. export()传入的Invoker由框架实现并传入，协议不需要关心。<br>
     * 
     * @param <T> 服务的类型
     * @param invoker 服务的执行体
     * @return exporter 暴露服务的引用，用于取消暴露
     * @throws RpcException 当暴露服务出错时抛出，比如端口已占用
     */
    @Adaptive
    <T> Exporter<T> export(Invoker<T> invoker) throws RpcException;

    /**
     * 引用远程服务：<br>
     * 1. 当用户调用refer()所返回的Invoker对象的invoke()方法时，协议需相应执行同URL远端export()传入的Invoker对象的invoke()方法。<br>
     * 2. refer()返回的Invoker由协议实现，协议通常需要在此Invoker中发送远程请求。<br>
     * 3. 当url中有设置check=false时，连接失败不能抛出异常，并内部自动恢复。<br>
     * 
     * @param <T> 服务的类型
     * @param type 服务的类型
     * @param url 远程服务的URL地址
     * @return invoker 服务的本地代理
     * @throws RpcException 当连接服务提供方失败时抛出
     */
    @Adaptive
    <T> Invoker<T> refer(Class<T> type, URL url) throws RpcException;

    /**
     * 释放协议：<br>
     * 1. 取消该协议所有已经暴露和引用的服务。<br>
     * 2. 释放协议所占用的所有资源，比如连接和端口。<br>
     * 3. 协议在释放后，依然能暴露和引用新的服务。<br>
     */
    void destroy();

}
```

在上面的代码中，SPI注解指定的实现类关键字是dubbo，这个dubbo指的是哪个实现类呢？我们找到当前项目(或是接口所在的项目中)目录下的**/resources/META-INF/dubbo/internal**文件夹，找到类名是Protocol接口的包路径名的文件：

```
dubbo=com.alibaba.dubbo.rpc.protocol.dubbo.DubboProtocol
```

这个文件记录了SPI接口可以选择的实现类，如上面的dubbo关键字指定的实现类是DubboProtocol。我们找到这个关系后，那么怎么实例化呢？代码如下：

```java
Protocol protocol = ExtensionLoader.getExtensionLoader(Protocol.class).getAdaptiveExtension();
```

这样我们就拿到了一个DubboProtocol实例(实际上也可能是其包装对象)。

----------------

下面我们就实例化的过程做一个简单分析：

首先，我们看下**ExtensionLoader.getExtensionLoader(Protocol.class)**的业务逻辑：

```java
public static <T> ExtensionLoader<T> getExtensionLoader(Class<T> type) {
    if (type == null)
        throw new IllegalArgumentException("Extension type == null");
    if(!type.isInterface()) {
        throw new IllegalArgumentException("Extension type(" + type + ") is not interface!");
    }
    if(!withExtensionAnnotation(type)) {
        throw new IllegalArgumentException("Extension type(" + type + 
                ") is not extension, because WITHOUT @" + SPI.class.getSimpleName() + " Annotation!");
    }
    ExtensionLoader<T> loader = (ExtensionLoader<T>) EXTENSION_LOADERS.get(type);
    if (loader == null) {
        EXTENSION_LOADERS.putIfAbsent(type, new ExtensionLoader<T>(type));
        loader = (ExtensionLoader<T>) EXTENSION_LOADERS.get(type);
    }
    return loader;
}
```

主要内容就是创建了一个ExtensionLoader实例，并缓存进了EXTENSION_LOADERS中，EXTENSION_LOADERS是一个静态Map对象，在二次调用时就可以直接获取缓存了。通过这个缓存，我们知道每个SPI接口都有唯一对应的ExtensionLoader实例。

在ExtensionLoader实例化时，有两个全局变量需要我们注意：

```java
private ExtensionLoader(Class<?> type) {
    this.type = type;
    objectFactory = (type == ExtensionFactory.class ? null : ExtensionLoader.getExtensionLoader(ExtensionFactory.class).getAdaptiveExtension());
}
```

一个是type，记录SPI接口的class对象，另一个是通过递归创建的ExtensionFactory接口实例，他肯定也实际创建了某个实现类，这里我们可以暂时不管他，等后面用到时再说。

------------

**getExtensionLoader(Class<T> type)**方法并没有实际的创建实现类，所以大部分工作应该是**getAdaptiveExtension()**方法来完成的，下面我们来了解下具体逻辑：

```java
//com.alibaba.dubbo.common.extension.ExtensionLoader#getAdaptiveExtension
public T getAdaptiveExtension() {
    Object instance = cachedAdaptiveInstance.get();
    if (instance == null) {
        if(createAdaptiveInstanceError == null) {
            synchronized (cachedAdaptiveInstance) {
                instance = cachedAdaptiveInstance.get();
                if (instance == null) {
                    try {
                        instance = createAdaptiveExtension();
                        cachedAdaptiveInstance.set(instance);
                    } catch (Throwable t) {
                        createAdaptiveInstanceError = t;
                        throw new IllegalStateException("fail to create adaptive instance: " + t.toString(), t);
                    }
                }
            }
        }
        else {
            throw new IllegalStateException("fail to create adaptive instance: " + createAdaptiveInstanceError.toString(), createAdaptiveInstanceError);
        }
    }

    return (T) instance;
}
```

这个方法逻辑很简单，通过**createAdaptiveExtension()**来创建具体的实例，而且使用了成员变量**cachedAdaptiveInstance**来缓存创建好的实例对象。下面继续跟踪代码：

```java
private T createAdaptiveExtension() {
    try {//getAdaptiveExtensionClass()会创建SPI接口的的代理类的Class对象
        return injectExtension((T) getAdaptiveExtensionClass().newInstance());
    } catch (Exception e) {
        throw new IllegalStateException("Can not create adaptive extenstion " + type + ", cause: " + e.getMessage(), e);
    }
}
```

这个方法主要逻辑只有一行代码，通过方法名称我们可以知道这些方法的具体作用，**getAdaptiveExtensionClass()**方法会获取一个扩展类的class对象，之后通过**newInstance()**实例化，然后作为参数在**injectExtension(instance)**方法中进行属性注入。





