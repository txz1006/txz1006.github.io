在分析ServiceConfig的export()方法前，我们先给出整个dubbo暴露方法的调用链表，让大家可以有一个全局视角，不至于迷失在某个代码角落里。

![image-20211109150144434](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111091501491.png)

下面是ServiceConfig的export方法：

```java
public synchronized void export() {
    if (this.shouldExport() && !this.exported) {
        //初始化(记录要暴露接口配置的原始信息)
        this.init();
        if (!this.bootstrap.isInitialized()) {
            throw new IllegalStateException("DubboBootstrap is not initialized");
        }
        if (!this.isRefreshed()) {
            this.refresh();
        }
        if (!this.shouldExport()) {
            return;
        }
        if (this.shouldDelay()) {
            //延迟发布
            DELAY_EXPORT_EXECUTOR.schedule(this::doExport, (long)this.getDelay(), TimeUnit.MILLISECONDS);
        } else {
            //立即发布
            this.doExport();
        }
        if (this.bootstrap.getTakeoverMode() == BootstrapTakeoverMode.AUTO) {
            this.bootstrap.start();
        }
    }
}
```

继续深入到 this.doExport()方法，我们可以追溯到两个方法：

```java
//发布要暴露的接口
this.doExportUrls();
//设置接口暴露后的映射关系
this.exported();
```

我们先来看看this.doExportUrls()这个方法具体做了什么：

```java
private void doExportUrls() {
    ServiceRepository repository = ApplicationModel.getServiceRepository();
    //这是一个全局的服务存储对象，用来存储要暴露的接口信息(暂时不用管)
    ServiceDescriptor serviceDescriptor = repository.registerService(this.getInterfaceClass());
    repository.registerProvider(this.getUniqueServiceName(), this.ref, serviceDescriptor, this, this.serviceMetadata);
    //根据dubbo配置信息(不涉及dubbo:service)组织服务注册发现用的URL对象，这个是动态选择哪个SPI接口实现类执行方法的管件类
    List<URL> registryURLs = ConfigValidationUtils.loadRegistries(this, true);
    Iterator var4 = this.protocols.iterator();

    while(var4.hasNext()) {
        ProtocolConfig protocolConfig = (ProtocolConfig)var4.next();
        String pathKey = URL.buildKey((String)this.getContextPath(protocolConfig).map((p) -> {
            return p + "/" + this.path;
        }).orElse(this.path), this.group, this.version);
        repository.registerService(pathKey, this.interfaceClass);
        //拿着ProtocolConfig对象和zookeeper注册中心生成两个URL对象来做具体发布工作
        this.doExportUrlsFor1Protocol(protocolConfig, registryURLs);
    }

}
```

这个方法主要逻辑是根据dubbo的xml配置信息拼装出多个URL对象，然后看看是否存在<dubbo:protocol/>标签封装的ProtocolConfig对象列表(this.protocols)，如果有，每个<dubbo:protocol/>都会暴露一次接口。这里简单提一下<dubbo:protocol/>可以设置暴露接口使用何种协议解析(dubbo/hessian/rmi/thrift/redis)，如果没有就默认按照dubbo协议暴露接口。

由于我们在xml配置中没有设置<dubbo:protocol/>标签，所以这里的this.protocols只有一个元素，还是一个空的ProtocolConfig对象(默认值)，就是会使用dubbo协议来暴露接口。

这里细说一下**ConfigValidationUtils.loadRegistries(this, true)**，这个工具类会获取<dubbo:application/>标签封装的ApplicationConfig和<dubbo:registry/>标签封装的RegistryConfig(配置中心可以有多个)，然后组装解析成一个ServiceConfigURL(后面就简称URL对象了)列表对象(有几个配置中心有生成几个ServiceConfigURL对象，我们在配置文件中只配置了一个zookeeper所以只有一个ServiceConfigURL对象)，生成的URL对象展开字符串如下所示：

```
registry://127.0.0.1:2181/org.apache.dubbo.registry.RegistryService?application=demo-provider&dubbo=2.0.2&pid=17748&registry=zookeeper&release=3.0.2.1&timestamp=1636444467260
```

到目前为止，这个用来发布dubbo接口的URL还不完整，会在此基础上再增加一个服务发现注册用的URL对象，其展开内容如下：

```
service-discovery-registry://127.0.0.1:2181/org.apache.dubbo.registry.RegistryService?application=demo-provider&dubbo=2.0.2&pid=17748&registry=zookeeper&release=3.0.2.1&timestamp=1636444467260
```

目前为止，我们已知一个注册中心会生成两个URL对象。

下面我们顺着**this.doExportUrlsFor1Protocol(protocolConfig, registryURLs)**方法继续向下走：

```java
private void doExportUrlsFor1Protocol(ProtocolConfig protocolConfig, List<URL> registryURLs) {
    //从当前对象ServiceConfig和protocolConfig中解析要暴露的接口信息成一个map
    Map<String, String> map = this.buildAttributes(protocolConfig);
    this.serviceMetadata.getAttachments().putAll(map);
    //根据三种数据，封装我们具体要发布的URL对象
    URL url = this.buildUrl(protocolConfig, registryURLs, map);
    //具体发布
    this.exportUrl(url, registryURLs);
}


private void exportUrl(URL url, List<URL> registryURLs) {
    //获取发布接口的应用范围
    String scope = url.getParameter("scope");
    if (!"none".equalsIgnoreCase(scope)) {
        if (!"remote".equalsIgnoreCase(scope)) {
            //暴露本地接口服务
            this.exportLocal(url);
        }

        if (!"local".equalsIgnoreCase(scope)) {
            //暴露远程接口服务
            url = this.exportRemote(url, registryURLs);
            MetadataUtils.publishServiceDefinition(url);
        }
    }
    //记录发布后的URL对象
    this.urls.add(url);
}
```

这是dubbo接口发布的最主要外围方法了，依然还是组织发布要用的资源对象，首先是从ServiceConfig和ProtocolConfig中解析要暴露的接口信息成一个map，具体内容如下图所示：

![image-20211109164427588](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111091644641.png)

然后又将protocolConfig, registryURLs, map三者封装成一个URL对象，这个URL的内容才是我们要暴露的接口对象：

```
dubbo://192.168.152.86:20880/org.apache.dubbo.samples.basic.api.DemoService?anyhost=true&application=demo-provider&bind.ip=192.168.152.86&bind.port=20880&deprecated=false&dubbo=2.0.2&dynamic=true&generic=false&interface=org.apache.dubbo.samples.basic.api.DemoService&metadata-type=remote&methods=testVoid,sayHello&pid=17748&release=3.0.2.1&side=provider&timestamp=1636448079005&token=6a9a739d-c2e7-4272-8735-b286dc8cccc1
```

下面我们继续来分析下 **this.exportLocal(url)**和**this.exportRemote(url, registryURLs)**具体是怎么发布dubbo接口服务的。

