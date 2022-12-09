## 前言

在现如今微服务大行其道的开发状况，一个完整的业务功能可能会涉及多个不同的服务模块，所以数据调用链路就会非常的复杂，服务与服务之间的数据依赖关系，基本依靠接口之间的调用来完成。但是如果一条调用链路中某个上游服务宕机了，那么整条业务链路就无法走通，对用户而言的表现就是某个功能突然不能用了，出现异常的结果。

```sh
#某个服务调用链路
用户----->某个系统功能----->A服务----->B服务----->C服务
#如果上游的B服务或C服务接口出现异常，那么整个功能就是不可用的
```

为了处理这种服务不可用的情况，保证各服务在异常状态下也可以正常工作，所以出现一些中间件来专门保证服务接口始终处于一个可用状态。

如果做到这种功能呢？首先我们要清楚服务在哪些情况下才会不可用，以及如何处理这些情况的问题：

| 问题                                                   | 解决方案                         |
| ------------------------------------------------------ | -------------------------------- |
| 接口请求用户过多，超出了系统资源限制，导致整个服务宕机 | 对用户请求量进行限流             |
| 上游服务宕机，导致当前服务调用超时或者返回异常结果     | 设置合理的超时时间，增加异常处理 |
| 当前服务业务复杂，返回结果过慢                         | 设置合理的超时时间               |
| ....                                                   | ....                             |

出现上面的问题后，我们可以给这些接口一个兜底且通用的处理逻辑：让本次调用服务立即快速失败，执行一个备用的逻辑，让备用逻辑返回一个失败结果或是一个过期的本地缓存数据。

其次，要做这样一个功能就必须要有一个动态的统计功能，可以统计单位时间内某个接口的总请求量、请求成功量、请求失败量等数据，当异常数据达到一定的比例或是数量时，我们就可以认为这个接口处于不正常状态了，需要进行熔断降级了，然后让之后的一段时间内请求直接走快速失败备用逻辑，等熔断时间过了，再请求正常的业务逻辑，然后再进行统计。

最后，实际上上面这些功能在市面上的一些中间件已经帮我们做过了，下面我们来了解这些组件：

| 功能           | Sentinel                                                   | Hystrix                 | resilience4j                     |
| :------------- | :--------------------------------------------------------- | :---------------------- | :------------------------------- |
| 隔离策略       | 信号量隔离（并发线程数限流）                               | 线程池隔离/信号量隔离   | 信号量隔离                       |
| 熔断降级策略   | 基于响应时间、异常比率、异常数                             | 基于异常比率            | 基于异常比率、响应时间           |
| 实时统计实现   | 滑动窗口（LeapArray）                                      | 滑动窗口（基于 RxJava） | Ring Bit Buffer                  |
| 动态规则配置   | 支持多种数据源                                             | 支持多种数据源          | 有限支持                         |
| 扩展性         | 多个扩展点                                                 | 插件的形式              | 接口的形式                       |
| 基于注解的支持 | 支持                                                       | 支持                    | 支持                             |
| 限流           | 基于 QPS，支持基于调用关系的限流                           | 有限的支持              | Rate Limiter                     |
| 流量整形       | 支持预热模式、匀速器模式、预热排队模式(流量规则处可配置)   | 不支持                  | 简单的 Rate Limiter 模式         |
| 系统自适应保护 | 支持                                                       | 不支持                  | 不支持                           |
| 控制台         | 提供开箱即用的控制台，可配置规则、查看秒级监控、机器发现等 | 简单的监控查看          | 不提供控制台，可对接其它监控系统 |

由于Hystrix基本已经不再维护、Hystrix和resilience4j都是基于配置断路器来实现的熔断降级，想动态配置规则需要较大适配改造。所以最后选择了Sentinel来作为集成组件。

## Sentinel使用简介

Sentinel 是面向分布式、多语言异构化服务架构的流量治理组件，主要以流量为切入点，从流量路由、流量控制、流量整形、熔断降级、系统自适应过载保护、热点流量防护等多个维度来帮助开发者保障微服务的稳定性。

这里参考了官方文档：[quick-start | Sentinel (sentinelguard.io)](https://sentinelguard.io/zh-cn/docs/quick-start.html)

Sentinel 基本没有过多个环境依赖，集成也十分的简单，下面我们来进行逐一说明：

下面我们来简单的集成Sentinel到项目中：

第一步，在pom文件中加入入口sentinel依赖，将Sentinel 核心jar包引入项目中：

```xml
<!--sentinel核心组件-->
<dependency>
    <groupId>com.alibaba.csp</groupId>
    <artifactId>sentinel-core</artifactId>
    <version>1.8.6</version>
</dependency>
<!--支持数据发送到控制台-->
<dependency>
    <groupId>com.alibaba.csp</groupId>
    <artifactId>sentinel-transport-simple-http</artifactId>
    <version>1.8.6</version>
</dependency>
<!--@SentinelResource注解AOP切面支持-->
<dependency>
    <groupId>com.alibaba.csp</groupId>
    <artifactId>sentinel-annotation-aspectj</artifactId>
    <version>1.8.6</version>
</dependency>
```

第二步，在需要进行拦截业务代码前后，使用如下代码包装：

```java
// 1.5.0 版本开始可以直接利用 try-with-resources 特性
try (Entry entry = SphU.entry("HelloWorld")) {
    // 被保护的业务逻辑
    System.out.println("hello world");
} catch (BlockException ex) {
    // 处理被流控、熔断的逻辑
    System.out.println("blocked!");
}
```

看到这里，经验丰富的同学就可以想象到，这块代码比较适合用在过滤器中，或是AOP切面中，能批量的对某一类接口请求、方法调用生效。

第三步，配置熔断限流规则：

```java
//下面是配置的一条限流规则
//熔断规则需要使用DegradeRule和DegradeRuleManager
private static void initFlowRules(){
    List<FlowRule> rules = new ArrayList<>();
    FlowRule rule = new FlowRule();
    rule.setResource("HelloWorld");
    rule.setGrade(RuleConstant.FLOW_GRADE_QPS);
    // Set limit QPS to 20.
    rule.setCount(20);
    rules.add(rule);
    FlowRuleManager.loadRules(rules);
}
```

这些规则可以动态的更新到内存对象中，配置完成后在项目的启动参数加入如下参数：

```sh
##设置当前项目在sentinel控制台的应用名称（不同项目不要重复）
-Dproject.name=open-campus
##指定sentinel控制台的ip和地址
-Dcsp.sentinel.dashboard.server=localhost:8850
```

然后启动sentinel控制台：

```sh
#控制台的默认z账号密码是sentinel/sentinel
java -Dserver.port=8850 -Dcsp.sentinel.dashboard.server=localhost:8850 -Dproject.name=sentinel-dashboard -jar sentinel-dashboard-1.8.6.jar
```

sentinel-dashboard控制台的数据都存储在内存中，通过http请求向sentinel-客户端传送动态规则，或从客户端获取规则展示出来，如果想要持久化这些规则到数据库、nacos、redis、zookeeper等容器中，需要进行相关自定义改造，官方也提供一些常用的扩展组件，可以参考：https://sentinelguard.io/zh-cn/docs/open-source-framework-integrations.html

启动项目，访问熔断接口，就会在sentinel-dashboard控制台看到对应sentinel-客户端信息，然后我们可以在其中给`SphU.entry(resourceName)`中的resourceName资源信息设置各种熔断限流规则。

sentinel客户端随项目启动后，会使用netty开启一个服务，用于接收sentinel-dashboard控制台发送的新规则数据，然后更新到自己的应用内存中。



## 生产使用sentinel

如果我们要在生产环境使用sentinel，需要考虑将规则进行实例化。

如果应用服务器是单台机器，则可以直接实现InitFunc接口，在init方法中设置本地文件注册到sentinel-dashboard控制台中，这样在控制台中修改规则数据，则客户端收到控制台推送的规则时，Sentinel 会先更新到内存，然后将规则写入到文件中。

![image-20221209173713429](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202212091737704.png)

```
注意，上述方式需要将实现了InitFunc接口的对象写入/resources/META-INF/service目录下的 com.alibaba.csp.sentinel.init.InitFunc 文件中，比如：
com.test.init.FileDataSourceInit
```

参考代码如下：

```java
public class FileDataSourceInit implements InitFunc {

    @Override
    public void init() throws Exception {
        String flowRulePath =this.getClass().getClassLoader().getResource("sentinel_degradeRule.json").getPath();

        ReadableDataSource<String, List<FlowRule>> ds = new FileRefreshableDataSource<>(
            flowRulePath, source -> JSON.parseObject(source, new TypeReference<List<FlowRule>>() {})
        );
        // 将可读数据源注册至 FlowRuleManager.
        FlowRuleManager.register2Property(ds.getProperty());

        WritableDataSource<List<FlowRule>> wds = new FileWritableDataSource<>(flowRulePath, this::encodeJson);
        // 将可写数据源注册至 transport 模块的 WritableDataSourceRegistry 中.
        // 这样收到控制台推送的规则时，Sentinel 会先更新到内存，然后将规则写入到文件中.
        WritableDataSourceRegistry.registerFlowDataSource(wds);
    }

    private <T> String encodeJson(T t) {
        return JSON.toJSONString(t);
    }
}
```

如果我们有多台服务器，则需要一个规则集中存储的容器，然后由这个容器将规则推送到各个服务器中；

![image-20221209173724857](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202212091737921.png)

这里需要对sentinel-dashboard控制台和客户端数据源规则进行改写，可以参考：[sentinel限流集成redis_荆茗Scaler的博客-CSDN博客_sentinel redis改造](https://blog.csdn.net/jll126/article/details/120334150)

或者https://gitee.com/Alex1713/sentinel-dashboard-plus/tree/sentinel_redis/

如果要使用@SentinelResource注解方式来标注资源，可以参考：[annotation-support | Sentinel (sentinelguard.io)](https://sentinelguard.io/zh-cn/docs/annotation-support.html)

因为是通过aop实现的，所以需要实现SentinelResourceAspect

```java
@Configuration
public class SentinelAspectConfiguration {

    @Bean
    public SentinelResourceAspect sentinelResourceAspect() {
        return new SentinelResourceAspect();
    }
}
```

使用方式如下所示：

```java
public class TestService {

    // 对应的 `handleException` 函数需要位于 `ExceptionUtil` 类中，并且必须为 static 函数.
    @SentinelResource(value = "test", blockHandler = "handleException", blockHandlerClass = {ExceptionUtil.class})
    public void test() {
        System.out.println("Test");
    }

    // 原函数
    @SentinelResource(value = "hello", blockHandler = "exceptionHandler", fallback = "helloFallback")
    public String hello(long s) {
        return String.format("Hello at %d", s);
    }
    
    // Fallback 函数，函数签名与原函数一致或加一个 Throwable 类型的参数.
    public String helloFallback(long s) {
        return String.format("Halooooo %d", s);
    }

    // Block 异常处理函数，参数最后多一个 BlockException，其余与原函数一致.
    public String exceptionHandler(long s, BlockException ex) {
        // Do some log here.
        ex.printStackTrace();
        return "Oops, error occurred at " + s;
    }
}
```

参考资料：

	https://hub.yzuu.cf/alibaba/Sentinel/wiki/%E5%9C%A8%E7%94%9F%E4%BA%A7%E7%8E%AF%E5%A2%83%E4%B8%AD%E4%BD%BF%E7%94%A8-Sentinel
	https://hub.yzuu.cf/alibaba/Sentinel/wiki/%E5%A6%82%E4%BD%95%E4%BD%BF%E7%94%A8
	https://www.cnblogs.com/manastudent/p/16521034.html
	https://www.jb51.net/article/221442.htm
	https://blog.csdn.net/jll126/article/details/120334150
	https://blog.csdn.net/weixin_43931625/article/details/123744276