下面以具体的dubbo实例来分析一个dubbo接口是怎么一步步的暴露发布成服务的。

实例项目集成了dubbo，并且以zookeeper作为dubbo的服务注册中心。

下面是接口提供服务的xml配置文件(/resources/spring/dubbo-demo-provider.xml)：

```xml
<beans xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:dubbo="http://dubbo.apache.org/schema/dubbo"
       xmlns="http://www.springframework.org/schema/beans" xmlns:context="http://www.springframework.org/schema/context"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd
       http://dubbo.apache.org/schema/dubbo http://dubbo.apache.org/schema/dubbo/dubbo.xsd http://www.springframework.org/schema/context http://www.springframework.org/schema/context/spring-context.xsd">
    <!--让xml配置可以使用占位符，比如下面的${zookeeper.address} -->
    <context:property-placeholder/>
	<!--配置当前应用信息 -->
    <dubbo:application name="demo-provider"/>
	<!--设置zookeeper注册地址 -->
    <dubbo:registry address="zookeeper://${zookeeper.address:127.0.0.1}:2181"/>
	<!--配置接口的随机token令牌(也可以固定),防止消费者绕过注册中心直接访问接口提供方 -->
    <dubbo:provider token="true"/>
	<!--创建bean -->
    <bean id="demoService" class="org.apache.dubbo.samples.basic.impl.DemoServiceImpl"/>
    <!--设置要暴露的接口服务 -->
    <dubbo:service interface="org.apache.dubbo.samples.basic.api.DemoService" ref="demoService"/>

</beans>
```

配置好后直接启动一个spring容器即可，dubbo配置的有sping监听器，会随着spring一起启动：

```java
public static void main(String[] args) throws Exception {
    new EmbeddedZooKeeper(2181, false).start();
    // wait for embedded zookeeper start completely.
    Thread.sleep(1000);

    ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("spring/dubbo-demo-provider.xml");
    context.start();

    System.out.println("dubbo service started");
    new CountDownLatch(1).await();
}
```

启动后我们在DubboProtocol、JavassistProxyFactory或者ExtensionLoader类中打个断点，等运行到断点时，我们就可以观察整个dubbo接口暴露流程调用链表了。主要的调用链表如下图所示：

![image-20211109132728942](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111091327626.png)

通过上图我们可以知道dubbo是通过**DubboBootstrapApplicationListener.onApplicationEvent(event)**整合到spring容器上的，在spring容器启动时会触发dubbo进行初始化启动，DubboBootstrapApplicationListener主要方法如下：

```java
public class DubboBootstrapApplicationListener implements ApplicationListener, ApplicationContextAware, Ordered {
    public static final String BEAN_NAME = "dubboBootstrapApplicationListener";
    private final Log logger = LogFactory.getLog(this.getClass());
    private final DubboBootstrap dubboBootstrap = this.initBootstrap();
    private ApplicationContext applicationContext;
    
    private DubboBootstrap initBootstrap() {
        DubboBootstrap dubboBootstrap = DubboBootstrap.getInstance();
        if (dubboBootstrap.getTakeoverMode() != BootstrapTakeoverMode.MANUAL) {
            dubboBootstrap.setTakeoverMode(BootstrapTakeoverMode.SPRING);
        }
        return dubboBootstrap;
    }
    
 	//...
    //spring启动触发应用监听接口方法
    public void onApplicationEvent(ApplicationEvent event) {
        if (this.isOriginalEventSource(event)) {
            if (event instanceof DubboAnnotationInitedEvent) {
                this.initDubboConfigBeans();
            } else if (event instanceof ApplicationContextEvent) {
                //实际调用
                this.onApplicationContextEvent((ApplicationContextEvent)event);
            }
        }
    }
    //...
    private void onApplicationContextEvent(ApplicationContextEvent event) {
        if (DubboBootstrapStartStopListenerSpringAdapter.applicationContext == null) {
            DubboBootstrapStartStopListenerSpringAdapter.applicationContext = event.getApplicationContext();
        }
        if (event instanceof ContextRefreshedEvent) {
            //实际调用
            this.onContextRefreshedEvent((ContextRefreshedEvent)event);
        } else if (event instanceof ContextClosedEvent) {
            this.onContextClosedEvent((ContextClosedEvent)event);
        }
    }

    private void onContextRefreshedEvent(ContextRefreshedEvent event) {
        if (this.dubboBootstrap.getTakeoverMode() == BootstrapTakeoverMode.SPRING) {
            //实际的dubbo启动类
            this.dubboBootstrap.start();
        }
    }
}
```

这个监听类主要创建了DubboBootstrap对象，并调用了start()方法，DubboBootstrap类是dubbo真正的启动引导类，而start方法主要做了两件事，一个是初始化、另一个是开始暴露dubbo接口的流程：

```java
this.initialize();
this.doStart();
```

在具体进入解析暴露dubbo接口的流程前，我们需要了解一个对象ConfigManager，这个对象是DubboBootstrap类中的一个成员变量，在DubboBootstrap创建实例时，这个对象也会被跟随创建，由于也是采用了SPI机制，所以这个接口的实际创建对象是**org.apache.dubbo.config.context.ConfigManager**，他也是dubbo初始化的关键类之一，会在spring启动过程中加载dubbo配置文件，将每个配置项封装成具体的对象，比如<dubbo:service/>会被封装成ServiceBean，<dubbo:registry/>会被封装成RegistryConfig等等，这些对象创建好后会不仅会让如Spring IOC容器中还会被放入到ConfigManager中对外提供服务，中间可能会涉及一些父子类的上下转型，如ServiceBean实际会转型为父类ServiceConfig存储到ConfigManager中。

这样DubboBootstrap可以直接通过ConfigManager来获取各种dubbo配置对象信息了。在其中的this.doStart()方法中我们可以追溯到方法exportServices()。这个是发布dubbo接口的开端：

```java
private void exportServices() {
    //获取配置文件中全部的<dubbo:service/>封装的对象
    Iterator var1 = this.configManager.getServices().iterator();

    while(var1.hasNext()) {
        ServiceConfigBase sc = (ServiceConfigBase)var1.next();
        ServiceConfig<?> serviceConfig = (ServiceConfig)sc;
        serviceConfig.setBootstrap(this);
        if (!serviceConfig.isRefreshed()) {
            serviceConfig.refresh();
        }

        if (!sc.isExported()) {
            //需要不要异步发布
            if (sc.shouldExportAsync()) {
                ExecutorService executor = this.executorRepository.getServiceExportExecutor();
                CompletableFuture<Void> future = CompletableFuture.runAsync(() -> {
                    try {
                        if (!sc.isExported()) {
                            sc.export();
                            this.exportedServices.add(sc);
                        }
                    } catch (Throwable var3) {
                        this.logger.error("export async catch error : " + var3.getMessage(), var3);
                    }

                }, executor);
                this.asyncExportingFutures.add(future);
            } else if (!sc.isExported()) {
                //普通发布
                sc.export();
                this.exportedServices.add(sc);
            }
        }
    }
}
```

我们可以看看this.configManager.getServices()具体的状况，发现这个就是之前dubbo-demo-provider.xml配置的暴露接口：

![image-20211109145400973](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111091454008.png)

随着调用链的不断深入我们知道了DubboBootstrap的主要作用就是封装了dubbo配置文件中的各种对象到ConfigManager中，并遍历了要暴露的接口对象ServiceConfig，每个对象都执行具体的export()方法。

下面我们就要转换视角看看ServiceConfig是如何发布出去的。

