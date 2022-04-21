回到org.apache.dubbo.config.ServiceConfig#exportLocal方法中，我们来看看本地服务方法是怎么发布的：

```java
private void exportLocal(URL url) {
    //修改url的Protocol属性和IP端口为本地接口服务处理方式
    URL local = URLBuilder.from(url).setProtocol("injvm").setHost("127.0.0.1").setPort(0).build();
    this.doExportUrl(local, false);
    logger.info("Export dubbo service " + this.interfaceClass.getName() + " to local registry url : " + local);
}

private void doExportUrl(URL url, boolean withMetaData) {
    //PROXY_FACTORY生成代理对象Invoker，入参:ref是要暴露的dubbo接口实现类对象，interfaceClass是接口的class对象，URL是配置对象
    Invoker<?> invoker = PROXY_FACTORY.getInvoker(this.ref, this.interfaceClass, url);
    //如果需要携带dubbo接口元数据，则使用DelegateProviderMetaDataInvoker进行包装
    if (withMetaData) {
        invoker = new DelegateProviderMetaDataInvoker((Invoker)invoker, this);
    }
	//PROTOCOL来曝光代理Invoker对象
    Exporter<?> exporter = PROTOCOL.export((Invoker)invoker);
    //存储要发布的对象
    this.exporters.add(exporter);
}
```

到这里我们终于看到了接口发布的老几样对象：Protocol、ProxyFactory：

首先通过ProxyFactory对象构建一个Invoker代理对象，然后通过Protocol对象将其曝光，过程中开启Netty服务监听，可以让客户端来访问到Invoker来间接调用发布的dubbo接口实现类的具体方法。这两个对象的创建也是SPI方式创建的：

```java
private static final Protocol PROTOCOL = (Protocol)ExtensionLoader.getExtensionLoader(Protocol.class).getAdaptiveExtension();
private static final ProxyFactory PROXY_FACTORY = (ProxyFactory)ExtensionLoader.getExtensionLoader(ProxyFactory.class).getAdaptiveExtension();
```

下面我们先看**PROXY_FACTORY.getInvoker(this.ref, this.interfaceClass, url)**的业务逻辑：

这里我们需要寻找ProxyFactory接口到底调用了哪个实现类，如何寻找呢？我们找到/META-INF/dubbo/internal想和接口包路径相同的文件，发现里面有三个关键字对应的实现类：stub\jdk\javassist。下面我们说一下选择实现类的规则：

- 首先，是看SPI接口中方法上的@Adaptive参数，@Adaptive参数是一个数组可以写多个关键字，在生成SPI代理类时，会根据这些关键字从左向右依次从从URL对象中获取extName(得到的结果就是SPI配置文件中的关键字，即上面的stub\jdk\javassist一类)，来决定到底调用哪个具体的SPI实现类
- 其次，在根据@Adaptive参数从左向右获取extName时，遵从先到先得原则，只要哪一个关键字取到值了那么后面的的逻辑就不在执行了
- 如果@Adaptive没有写参数，则用当前接口的名称(XxxYxxZzz会改造成xxx.yyy.zzz的格式再去查询)作为参数去URL找寻找extName
- 如果上面的规则都没有找到extName，就会直接用@SPI注解的参数作为extName

而对于ProxyFactory接口而言，代理类中获取extName的代码(反编译获取)就是：

```java
String extName = url.getParameter("proxy", "javassist");
com.alibaba.dubbo.rpc.ProxyFactory extension = (com.alibaba.dubbo.rpc.ProxyFactory)ExtensionLoader.getExtensionLoader(com.alibaba.dubbo.rpc.ProxyFactory.class).getExtension(extName);
return extension.getProxy(arg0);
```

我们再看看URL是怎么样的：

```
injvm://127.0.0.1/org.apache.dubbo.samples.basic.api.DemoService?anyhost=true&application=demo-provider&bind.ip=192.168.152.86&bind.port=20880&deprecated=false&dubbo=2.0.2&dynamic=true&generic=false&interface=org.apache.dubbo.samples.basic.api.DemoService&metadata-type=remote&methods=testVoid,sayHello&pid=4276&release=3.0.2.1&side=provider&timestamp=1636507185495&token=bfe447ce-d5cb-4301-8280-6a4da5055ec8
```

没有在其中找到proxy相关的内容，所以，就直接使用javassist作为extName了。

而javassist和/META-INF/dubbo/internal下的SPI配置文件中对应的实现类是JavassistProxyFactory

```java
public class JavassistProxyFactory extends AbstractProxyFactory {
    public JavassistProxyFactory() {
    }

    public <T> T getProxy(Invoker<T> invoker, Class<?>[] interfaces) {
        return Proxy.getProxy(interfaces).newInstance(new InvokerInvocationHandler(invoker));
    }

    public <T> Invoker<T> getInvoker(T proxy, Class<T> type, URL url) {
        //使用javassist包直接进行字节码修改，创建一个Wrapper类的子类，并重写invokeMethod方法
        final Wrapper wrapper = Wrapper.getWrapper(proxy.getClass().getName().indexOf(36) < 0 ? proxy.getClass() : type);	//创建一个匿名的AbstractProxyInvoker对象，这个对象持有wrapper，并在doInvoke方法中调用Wrapper.invokeMethod方法
        return new AbstractProxyInvoker<T>(proxy, type, url) {
            protected Object doInvoke(T proxy, String methodName, Class<?>[] parameterTypes, Object[] arguments) throws Throwable {
                return wrapper.invokeMethod(proxy, methodName, parameterTypes, arguments);
            }
        };
    }
}
```

JavassistProxyFactory类的主要功能是构建一个持有dubbo接口实现类的Invoker对象，而且dubbo接口实现类是被包裹在Wrapper中的，由wrapper.invokeMethod具体调用。下面我们对生成的Wrapper对象进行反编译一下，看看到底生成了一个什么样的类，这里使用的是Java的HSDB工具生成的Wrapper：

```java
package org.apache.dubbo.common.bytecode;

import java.lang.reflect.InvocationTargetException;
import java.util.Map;
import org.apache.dubbo.samples.basic.impl.DemoServiceImpl;

public class Wrapper1 extends Wrapper implements ClassGenerator.DC {
  public static String[] pns;
  public static Map pts;
  public static String[] mns;
  public static String[] dmns;
  public static Class[] mts0;
  public static Class[] mts1;

  public Class getPropertyType(String paramString){return (Class)pts.get(paramString);}

  //我们主要关注这个被使用的方法
  public Object invokeMethod(Object paramObject, String paramString, Class[] paramArrayOfClass, Object[] paramArrayOfObject) throws InvocationTargetException {
    DemoServiceImpl localDemoServiceImpl;
    try{
      //转型  
      localDemoServiceImpl = (DemoServiceImpl)paramObject;
    }catch (Throwable localThrowable1){
      throw new IllegalArgumentException(localThrowable1);
    }
    try{
      //通过方法名称和参数个数来决定具体调用哪个方法
      if ((!"sayHello".equals(paramString)) || (paramArrayOfClass.length == 1))
        return localDemoServiceImpl.sayHello((String)paramArrayOfObject[0]);
      if ((!"testVoid".equals(paramString)) || (paramArrayOfClass.length == 0)){
        localDemoServiceImpl.testVoid();
        return null;
      }
    }catch (Throwable localThrowable2){
      throw new InvocationTargetException(localThrowable2);
    }
    throw new NoSuchMethodException("Not found method \"" + paramString + "\" in class org.apache.dubbo.samples.basic.impl.DemoServiceImpl.");
  }

  public String[] getPropertyNames(){return pns;}

  public Object getPropertyValue(Object paramObject, String paramString){
    try{
      DemoServiceImpl localDemoServiceImpl = (DemoServiceImpl)paramObject;
    }catch (Throwable localThrowable){
      throw new IllegalArgumentException(localThrowable);
    }
    throw new NoSuchPropertyException("Not found property \"" + paramString + "\" field or getter method in class org.apache.dubbo.samples.basic.impl.DemoServiceImpl.");
  }

  public void setPropertyValue(Object paramObject1, String paramString, Object paramObject2){
    try{
      DemoServiceImpl localDemoServiceImpl = (DemoServiceImpl)paramObject1;
    }catch (Throwable localThrowable){
      throw new IllegalArgumentException(localThrowable);
    }
    throw new NoSuchPropertyException("Not found property \"" + paramString + "\" field or setter method in class org.apache.dubbo.samples.basic.impl.DemoServiceImpl.");
  }

  public String[] getMethodNames(){return mns;}

  public String[] getDeclaredMethodNames(){return dmns;}

  public boolean hasProperty(String paramString){return pts.containsKey(paramString);}
}
```

这里就比较清楚了这个Wrapper1的主要功能了。

下面我们继续跟进**PROTOCOL.export((Invoker)invoker)**到底做了那些工作。

首先我们按照同样的方法，知道Protocol生成的代理类获取extName的代码如下：

```java
//如果类名是Protocol，则直接通过url.getProtocol()获取extName，不再走url.getParameter
String extName = ( url.getProtocol() == null ? "dubbo" : url.getProtocol() );
```

由于url.getProtocol()在此时的URL中获取到的关键字是injvm(实际就是URL开头的字符串)，所以不需要走后面的默认参数dubbo了，对应到SPI配置文件上，我们要找的是InjvmProtocol而不是DubboProtocol。





