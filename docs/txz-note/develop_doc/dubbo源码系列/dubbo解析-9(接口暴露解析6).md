我们先不去分析netty的具体逻辑，这里我们回到RegistryProtocol中export方法中，把剩下的逻辑走完。此时，我们依然处于**RegistryProtocol.ExporterChangeableWrapper<T> exporter = this.doLocalExport(originInvoker, providerUrl);**

当DubboProtocol创建了一个DubboExporter对象后，就进行了返回，过程中当然也避免不了被很多的Wrapper对象包装，最后我们得到一个这样的对象：

![image-20211115103149050](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111151031021.png)

这个对象之后还有一些后续处理，我们继续来看export方法:

```java
RegistryProtocol.ExporterChangeableWrapper<T> exporter = this.doLocalExport(originInvoker, providerUrl);
//根据registryUrl协议从registryFactory中获取到一个Registry对象
Registry registry = this.getRegistry(registryUrl);
//设置获取已注册的URL协议对象
URL registeredProviderUrl = this.getUrlToRegistry(providerUrl, registryUrl);
//是否需要注册，默认是需要
boolean register = providerUrl.getParameter("register", true);
if (register) {
    //使用Registry对象注册registeredProviderUrl
    this.register(registry, registeredProviderUrl);
}

this.registerStatedUrl(registryUrl, registeredProviderUrl, register);
exporter.setRegisterUrl(registeredProviderUrl);
exporter.setSubscribeUrl(overrideSubscribeUrl);
//使用Registry对象执行订阅
registry.subscribe(overrideSubscribeUrl, overrideSubscribeListener);
//将exporter持久化到本地
this.notifyExport(exporter);
return new RegistryProtocol.DestroyableExporter(exporter);
```

在拿到exporter后，这个方法又从registryFactory中获取到一个Registry对象，并用这个Registry对象完成了一系列的注册工作；这里的注册主要包括好几种方式，可以是本地注册、也可以是服务中心的注册，具体需要看registryFactory具体调用的哪个Registry对象，由于registryFactory接口的方法注解是@Adaptive({"protocol"})，所以会从URL对象获取protocol作为extName，又因为当前的URL协议的protocol值：service-discovery-registry，来获取具体的SPI实现类接口：ServiceDiscoveryRegistryFactory，而ServiceDiscoveryRegistryFactory类中的getRegistry(URL url)方法会创建一个具体的Registry对象：ServiceDiscoveryRegistry，这个对象才是实际干活的。

在执行this.register(registry, registeredProviderUrl)时，具体的逻辑如下：

```java
public final void register(URL url) {
    if (this.shouldRegister(url)) {
        this.doRegister(url);
    }
}

//this.writableMetadataService = InMemoryWritableMetadataService
public void doRegister(URL url) {
    url = this.addRegistryClusterKey(url);
    if (this.writableMetadataService.exportURL(url)) {
        if (this.logger.isInfoEnabled()) {
            this.logger.info(String.format("The URL[%s] registered successfully.", url.toString()));
        }
    } else if (this.logger.isWarnEnabled()) {
        this.logger.warn(String.format("The URL[%s] has been registered.", url.toString()));
    }
}


```

这个注册的要逻辑是使用InMemoryWritableMetadataService对象存储了具体发布的URL协议对象。到目前为止，service-discovery-registry协议已经完成发布注册，最后返回到ServiceConfig对象中存储的Exporter对象如下图所示：

![image-20211115112016036](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111151120077.png)

---------------

我们回到最初的ServiceConfig#exportRemote方法中，开始第二个注册URL的执行，这次执行的URL内容如下：

```
registry://127.0.0.1:2181/org.apache.dubbo.registry.RegistryService?application=demo-provider&dubbo=2.0.2&pid=13220&registry=zookeeper&release=3.0.2.1&timestamp=1636946441635
```

上面的URL对应具体的SPI实现类是registry=org.apache.dubbo.registry.integration.InterfaceCompatibleRegistryProtocol，这个类是RegistryProtocol类的子类，对于URL做了一些修改，我们后面再细说。

在PROTOCOL.export((Invoker)invoker)中，形成的调用链如下图所示：

![image-20211115140536916](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111151405961.png)

最终实际调用的还是RegistryProtocol#export方法，但是一些设置URL属性被子类重写了，我们来看一下：

```java
URL registryUrl = this.getRegistryUrl(originInvoker);
//对应于InterfaceCompatibleRegistryProtocol
protected URL getRegistryUrl(Invoker<?> originInvoker) {
    URL registryUrl = originInvoker.getUrl();
    if ("registry".equals(registryUrl.getProtocol())) {
        //这个registry实际为zookeeper
        String protocol = registryUrl.getParameter("registry", "dubbo");
        registryUrl = registryUrl.setProtocol(protocol).removeParameter("registry");
    }
    return registryUrl;
}

//结果获取到的registryUrl是zookeeper://127.0.0.1:2181/org.apache.dubbo.registry.RegistryService?application=demo-provider&dubbo=2.0.2&pid=13220&release=3.0.2.1&timestamp=1636946441635
```

然后**this.doLocalExport(originInvoker, providerUrl)**还是在DubboProtocol中创建一个Exporter，但是不会再次创建一个NettyServer，只会对之前创建的NettyServer进行重置。

当然这里最重要的是**Registry registry = this.getRegistry(registryUrl)**，因为这次的registryUrl是zookeeper开头的，所以实际上创建的是ZookeeperRegistryFactory，通过ZookeeperRegistryFactory.getRegistry()得到最终实现类是ZookeeperRegistry。

在创建ZookeeperRegistry时会创建一个Zookeeper连接：

```java
public ZookeeperRegistry(URL url, ZookeeperTransporter zookeeperTransporter) {
    super(url);
    if (url.isAnyHost()) {
        throw new IllegalStateException("registry address == null");
    } else {
        String group = url.getGroup("dubbo");
        if (!group.startsWith("/")) {
            group = "/" + group;
        }

        this.root = group;
        //创建一个zk连接
        this.zkClient = zookeeperTransporter.connect(url);
        //设置zk的监听对象
        this.zkClient.addStateListener((state) -> {
            if (state == 2) {
                logger.warn("Trying to fetch the latest urls, in case there're provider changes during connection loss.\n Since ephemeral ZNode will not get deleted for a connection lose, there's no need to re-register url of this instance.");
                this.fetchLatestAddresses();
            } else if (state == 4) {
                logger.warn("Trying to re-register urls and re-subscribe listeners of this instance to registry...");

                try {
                    this.recover();
                } catch (Exception var3) {
                    logger.error(var3.getMessage(), var3);
                }
            } else if (state == 0) {
                logger.warn("Url of this instance will be deleted from registry soon. Dubbo client will try to re-register once a new session is created.");
            } else if (state != 3 && state == 1) {
            }

        });
    }
}
```

需要注意的一点是，在父类中会对dubbo接口进行了本地文件的持久化，也就是如果本地持久化文件一直存在的话，还可以实现启动时的预加载：

```java
public AbstractRegistry(URL url) {
    this.setUrl(url);
    this.localCacheEnabled = url.getParameter("file.cache", true);
    if (this.localCacheEnabled) {
        this.syncSaveFile = url.getParameter("save.file", false);
        String defaultFilename = System.getProperty("user.home") + "/.dubbo/dubbo-registry-" + url.getApplication() + "-" + url.getAddress().replaceAll(":", "-") + ".cache";
        String filename = url.getParameter("file", defaultFilename);
        File file = null;
        if (ConfigUtils.isNotEmpty(filename)) {
            //创建本地文件
            file = new File(filename);
            if (!file.exists() && file.getParentFile() != null && !file.getParentFile().exists() && !file.getParentFile().mkdirs()) {
                throw new IllegalArgumentException("Invalid registry cache file " + file + ", cause: Failed to create directory " + file.getParentFile() + "!");
            }
        }

        this.file = file;
        this.loadProperties();
        this.notify(url.getBackupUrls());
    }

}
```

创建后的Registry对象如下图所示：

![image-20211115160458855](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111151604981.png)

我们拿到这样的一个Registry对后，后面的注册方法registry.register(registeredProviderUrl)中会就将dubbo接口的URL对象作为一个节点存储到zookeeper中：

```java
public void doRegister(URL url) {
    try {
        this.zkClient.create(this.toUrlPath(url), url.getParameter("dynamic", true));
    } catch (Throwable var3) {
        throw new RpcException("Failed to register " + url + " to zookeeper " + this.getUrl() + ", cause: " + var3.getMessage(), var3);
    }
}
```

除了直接存储URL到zookeeper中外，还会存储一些其他信息，在之后的**this.registry.subscribe(url, listener)**方法中，就会存储一些dubbo接口的分类新：

```java
String[] var15 = this.toCategoriesPath(url);
int var16 = var15.length;

for(int var17 = 0; var17 < var16; ++var17) {
    path = var15[var17];
    //.....
    this.zkClient.create(path, false);
    List<String> children = this.zkClient.addChildListener(path, zkListener);
    if (children != null) {
        urls.addAll(this.toUrlsWithEmpty(url, path, children));
    }
}
//将dubbo接口信息持久化的本地文件中(AbstractRegistry#notify(URL, NotifyListener, List<URL>))
this.notify(url, listener, urls);
```

我们可以看看持久化文件中具体存储的内容：

```
#Dubbo Registry Cache
#Mon Nov 15 16:23:49 CST 2021
org.apache.dubbo.samples.basic.api.DemoService=empty\://192.168.152.86\:20880/org.apache.dubbo.samples.basic.api.DemoService?anyhost\=true&application\=demo-provider&bind.ip\=192.168.152.86&bind.port\=20880&category\=configurators&check\=false&deprecated\=false&dubbo\=2.0.2&dynamic\=true&generic\=false&interface\=org.apache.dubbo.samples.basic.api.DemoService&metadata-type\=remote&methods\=testVoid,sayHello&pid\=13220&release\=3.0.2.1&service-name-mapping\=true&side\=provider&timestamp\=1636946442116&token\=b522c071-0d67-405d-a151-f96688747986
```

到这里整个接口的的发布流程基本已经走完，最后我们得到的Exporter是这样的：

![image-20211115162936680](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111151629729.png)

----------------

到这里一个dubbo接口的注册发布已经全部走完了，我们可以在ServiceConfig中查看我们创建的三个Exporter对象：

![image-20211115163201308](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111151632366.png)

后面会有客户端来分别调用这些Exporter对象，来进行远程RPC通信。

![image-20211115163532940](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111151635014.png)
