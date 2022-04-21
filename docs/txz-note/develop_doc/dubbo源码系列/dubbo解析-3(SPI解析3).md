接上一章，我们知道在适应性实例返回的最后一步，通过injectExtension(T instance)进行属性填充，填充过程中使用到了objectFactory，这对象最终会调用的是SpiExtensionFactory类的getExtension(pt, property)方法。

下面我们来看下具体逻辑：

```java
public class SpiExtensionFactory implements ExtensionFactory {

    @Override
    public <T> T getExtension(Class<T> type, String name) {
        //判断被注入的对象是不是一个SPI接口实现类
        if (type.isInterface() && type.isAnnotationPresent(SPI.class)) {
            //是的话，会创建Adaptive代理层对象并返回
            ExtensionLoader<T> loader = ExtensionLoader.getExtensionLoader(type);
            if (loader.getSupportedExtensions().size() > 0) {
                return loader.getAdaptiveExtension();
            }
        }
        //不是SPI接口直接返回null
        return null;
    }

}
```

这个getExtension方法实际上只用到了适应性类中set方法的入参类型class，而且只有这个class对象也是SPI接口才会进行具体的逻辑，非SPI接口一律不处理返回null。

------------------

我们再次回到injectExtension(intance)方法中：

```java
private T injectExtension(T instance) {
    try {
        if (objectFactory != null) {
            //实例方法列表中是否存在set方法
            for (Method method : instance.getClass().getMethods()) {
                if (method.getName().startsWith("set")
                        && method.getParameterTypes().length == 1
                        && Modifier.isPublic(method.getModifiers())) {
                    Class<?> pt = method.getParameterTypes()[0];
                    try {
                        String property = method.getName().length() > 3 ? method.getName().substring(3, 4).toLowerCase() + method.getName().substring(4) : "";
                        //如果当前SPI实现类中存在Set方法对应的变量也是一个SPI接口，那么就会给这个变量创建一个SPI代理层$Adpative class对象，并通过反射赋值
                        Object object = objectFactory.getExtension(pt, property);
                        if (object != null) {
                            method.invoke(instance, object);
                        }
                    } catch (Exception e) {
                        logger.error("fail to inject via method " + method.getName()
                                + " of interface " + type.getName() + ": " + e.getMessage(), e);
                    }
                }
            }
        }
    } catch (Exception e) {
        logger.error(e.getMessage(), e);
    }
    return instance;
}
```

现在我们可以比较清晰的认识到这方法的主要逻辑了，主要是给适应性类中的其他SPI接口成员变量赋值，并且还需要这些这些变量存在对应set方法才行。后面在创建真正的SPI实现类时还会用到这个方法。

下面我们可以简单梳理想适应性类的创建过程：

![image-20211028103140768](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110281031681.png)

#### 1.SPI实际实现类的创建

适应性类$Adpative一般而言指的是一个中间代理对象，主要的逻辑是在URL中获取到extName(需要注意的是，如果SPI接口方法使用了@Adaptive标注，则会优先根据@Adaptive的参数数组值从URL中获取具体的数值作为extName，如`String extName = url.getParameter("client", url.getParameter( "transporter", "netty"));`对应的SPI接口如下：

```java
@SPI("netty")
public interface Transporter {
    @Adaptive({"server", "transporter"})
    RemotingServer bind(URL url, ChannelHandler handler) throws RemotingException;

    @Adaptive({"client", "transporter"})
    Client connect(URL url, ChannelHandler handler) throws RemotingException;
}

//以connect方法为例,中间代理类会根据关键字顺序优先从client->transporter->netty,从URL中获取具体的extName值
```

或者 `String extName = ( url.getProtocol() == null ? "dubbo" : url.getProtocol() );`对应SPI接口如下：

```java
@SPI("dubbo")
public interface Protocol {
    int getDefaultPort();

    @Adaptive
    <T> Exporter<T> export(Invoker<T> invoker) throws RpcException;

    @Adaptive
    <T> Invoker<T> refer(Class<T> type, URL url) throws RpcException;

    void destroy();

    default List<ProtocolServer> getServers() {
        return Collections.emptyList();
    }
}
//将SPI接口参数当做最后的关键字默认值， @Adaptive如果没有写参数，则以当前接口类名称作为关键字，如Protocol会转成protocol(首字母小写)对应生成的代码就如上面的示例所示，如果是XxxYyyWrapper类型这会转成xxx.yyy.wrapper这样的关键字，此时生成的代码则可能是String extName = url.getParameter("xxx.yyy.wrapper", "SPI接口参数(这是默认值)")
```

)，然后在通过ExtensionLoader.getExtension(extName)获取(首次创建)到代理目标实例后，调用目标的同名方法(所以根据入参URL的不同，可以选择不同的接口实现类调用)。

![image-20211028103628798](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110281036842.png)

下面来具体了解下getExtension(String name)方法的细节：

```java
public T getExtension(String name) {
   if (name == null || name.length() == 0)
       throw new IllegalArgumentException("Extension name == null");
   if ("true".equals(name)) {
       return getDefaultExtension();
   }
   Holder<Object> holder = cachedInstances.get(name);
   if (holder == null) {
       cachedInstances.putIfAbsent(name, new Holder<Object>());
       holder = cachedInstances.get(name);
   }
   Object instance = holder.get();
   if (instance == null) {
       synchronized (holder) {
            instance = holder.get();
            if (instance == null) {
                instance = createExtension(name);
                holder.set(instance);
            }
        }
   }
   return (T) instance;
}
```

很明显，在每个SPI接口对应的ExtensionLoader中，创建了一个Holder对象来缓存具体创建的对象，我们直接看createExtension(name)方法就行了：

```java
private T createExtension(String name) {
    //获取SPI指定实现类的class对象
    Class<?> clazz = getExtensionClasses().get(name);
    if (clazz == null) {
        throw findException(name);
    }
    try {
        //实例化
        T instance = (T) EXTENSION_INSTANCES.get(clazz);
        if (instance == null) {
            EXTENSION_INSTANCES.putIfAbsent(clazz, (T) clazz.newInstance());
            instance = (T) EXTENSION_INSTANCES.get(clazz);
        }
        //属性初始化赋值
        injectExtension(instance);
        //是否存在实例的包装对象，如果存在则构建一个包装实例对象并返回
        Set<Class<?>> wrapperClasses = cachedWrapperClasses;
        if (wrapperClasses != null && wrapperClasses.size() > 0) {
            for (Class<?> wrapperClass : wrapperClasses) {
                instance = injectExtension((T) wrapperClass.getConstructor(type).newInstance(instance));
            }
        }
        return instance;
    } catch (Throwable t) {
        throw new IllegalStateException("Extension instance(name: " + name + ", class: " +
                type + ")  could not be instantiated: " + t.getMessage(), t);
    }
}
```

这个方法的主要逻辑有以下几点：

- 根据入参关键字从 getExtensionClasses().get(name)中获取到SPI接口具体的实现类class
- 然后使用class对象实例化该实现类，将创建的实例存储到全局Map EXTENSION_INSTANCES中(有一点IOC的意思哈:P)
- 对实例中的其他SPI接口成员变量赋值，通过set方法进行属性注入
- 如果在getExtensionClasses()首次加载该接口的SPI配置时，发现有class对象中存在以当前SPI接口作为参数的构造方法，就会将这个class作为包装类放入cachedWrapperClasses中(详细逻辑见上一章)，这里会通过这个单参构造进行包装类的创建，如果有多个包装类，则会进行包装类的嵌套，最后执行目标方法。

例如在Protocol 接口的SPI配置文件中，就存在两个包装类

```
filter=com.alibaba.dubbo.rpc.protocol.ProtocolFilterWrapper
listener=com.alibaba.dubbo.rpc.protocol.ProtocolListenerWrapper
```

他们都存在单参SPI接口构造：

```java
public class ProtocolFilterWrapper implements Protocol {

    private final Protocol protocol;

    public ProtocolFilterWrapper(Protocol protocol){
        if (protocol == null) {
            throw new IllegalArgumentException("protocol == null");
        }
        this.protocol = protocol;
    }
    //...
}
```

包装接口的执行顺序随机，没有规律(主要在于cachedWrapperClasses的类型是dubbo基于ConcurrentHashMap实现的ConcurrentHashSet)。

最后我们来梳理一下目前的方法调用链条：

![image-20211028112419785](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202110281124820.png)

