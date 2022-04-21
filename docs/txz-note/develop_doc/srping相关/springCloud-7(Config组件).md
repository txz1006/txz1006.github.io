springCloud-7(Config组件)

### Config组件的使用

Config组件和Eureka组件一样，分为Server和Client两端，其中Server端需要配置远程git地址，用于将git项目中的配置文件拉取到本地；Client端需要配置一个bootstrap.yml文件，这个文件在项目启动之初就进行加载，用于将bootstrap.yml中的配置信息从Server端读取过来，以供项目使用。

此实例以之前的8881端口的Eureka Server为前提

##### 0.github搭建配置列表项目

在项目新建一个mian分支存储配置文件，项目结构如下：

![image-20201127160258561](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210812110703.png)

其中config-file-prod.yml的内容如下

```yml
test: "I Want Fly"
sex: "F"
```



##### 1.搭建Config Server服务端

在根项目下新建一个module命名为config-client-a，选择eureka-client、Web和Config-Server三个Starter依赖，pom文件如下：

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-config-server</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
</dependency>
```

在项目启动类上加上 @EnableEurekaClient注册到Eureka中，加上@EnableConfigServer启用Config配置

```java
@SpringBootApplication
@EnableConfigServer
@EnableEurekaClient
public class ConfigServiceAApplication {
    public static void main(String[] args) {
        SpringApplication.run(ConfigServiceAApplication.class, args);
    }

}
```

在application.yml中配置对应git相关信息：

```yml
spring:
  application:
    name: config-service-a
  #集中配置git项目
  cloud:
    config:
      server:
        git:
          uri: https://github.com/Alex171337601/ConfigCenter   #配置文件git地址(最后不要加/)
          default-label: main   #配置信息所属分支
          search-paths: test-config  #搜索git项目中此路径下的配置文件
          username: 171337601@qq.com
          password: 1pengwenbo

eureka:
  client:
    #需要被注册
    register-with-eureka: true
    #需要被发现
    fetch-registry: true
    service-url:
      defaultZone: http://127.0.0.1:8881/eureka
  instance:
    #使用ip注册服务
    prefer-ip-address: true
    instance-id: ${spring.cloud.client.ip-address}${server.port}

# 应用服务 WEB 访问端口
server:
  port: 8886
```

启动项目就可以访问配置信息了，配置信息的访问规则和url的对应关系如下：

![image-20201127160400329](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201127160400.png)

下面以git项目中config-file-prod.yml为例；

- /{application}/{profile}[/{label}]规则

![image-20201127160915090](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201127160915.png)

- /{application}-{profile}.yml规则

![image-20201127161007521](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201127161007.png)

- /{label}/{application}-{profile}.yml规则

![image-20201127161026040](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201127161026.png)

- /{application}-{profile}.properties规则

![image-20201127161108182](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201127161108.png)

- /{label}/{application}-{profile}.properties规则

![image-20201127161137615](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201127161137.png)

在上述规则中，我们发现访问这些配置信息是可以在properties、yml格式互相转化的，而且实际上url也可以以json结尾，输出json格式：

![image-20201127161430760](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201127161430.png)

##### 2.搭建Config Client客户端

新建一个module命名为config-client-a，选择eureka-client、Web和Config三个Starter依赖，pom文件如下：

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
</dependency>
<dependency>
    　　<groupId>org.springframework.cloud</groupId>
    　　<artifactId>spring-cloud-starter-config</artifactId>
</dependency>
```

在启动类上加入@EnableEurekaClient，注册发现eureka服务

```java
@SpringBootApplication
@EnableEurekaClient
public class ConfigClientAApplication {

    public static void main(String[] args) {
        SpringApplication.run(ConfigClientAApplication.class, args);
    }

}
```

之后在resource下创建bootstrap.yml启动配置

```yml
#项目端口
server:
  port: 8887
#服务注册
eureka:
  client:
    #需要被注册
    register-with-eureka: true
    #需要被发现
    fetch-registry: true
    service-url:
      defaultZone: http://127.0.0.1:8881/eureka
  instance:
    #使用ip注册服务
    prefer-ip-address: true
    instance-id: ${spring.cloud.client.ip-address}${server.port}
#远程配置信息
spring:
  cloud:
    config:
      label: main  #分支名称
      name: config-file  #配置文件名称
      profile: prod  #配置名称后缀
      discovery:
        enabled: true  #开启服务搜索
        service-id: config-service-a  #配置服务id
  application:
    name: config-client-a
```

创建一个读取配置信息的controller，用于测试是否读取到git项目中的配置信息：

```java
@RestController
public class ConfigController {
    @Value("${test}")
    private String test;

    @Value("${server.port}")
    private String port;

    @RequestMapping("config-a")
    public String testConfig(){
        return port + "获取到配置"+ test;
    }
}
```

启动项目，会在启动日志中发现，项目最开始会进行配置信息拉取：

```verilog
2020-11-27 15:39:51.129  INFO 24684 --- [           main] c.c.c.ConfigServicePropertySourceLocator : Fetching config from server at : http://10.0.20.11:8886/
2020-11-27 15:39:56.334  INFO 24684 --- [           main] c.c.c.ConfigServicePropertySourceLocator : Located environment: name=config-file, profiles=[prod], label=main, version=898d38a08386fd2711d181cea36fb0d6aa6504d6, state=null
2020-11-27 15:39:56.335  INFO 24684 --- [           main] b.c.PropertySourceBootstrapConfiguration : Located property source: [BootstrapPropertySource {name='bootstrapProperties-configClient'}, BootstrapPropertySource {name='bootstrapProperties-https://github.com/Alex171337601/ConfigCenter/test-config/config-file-prod.yml'}]
```

项目启动后，测试config-a接口是否能获取到test信息：

![image-20201127165236771](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201127165236.png)

##### 3.手动刷新配置文件

在上面的示例其实存在一个挺大的问题，如果修改了git项目的配置信息，就需要再重启一次项目，这是十分不方便的。所以，就有了一些动态修改配置信息的方案，下面来看方案一：

在config-service-a和config-client-a客户端中都要引入bus-amqp组件，用于连接rabbitmq，service会异步发送配置刷新请求，client用于接受配置刷新请求。

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-bus-amqp</artifactId>
</dependency>
```

在config-service-a和config-client-a的配置文件中都加入rabbitmq的配置信息：

```yml
#远程配置信息
spring:
  #配置mq
  rabbitmq:
    host: 127.0.0.1
    port: 5672
    username: guest
    password: guest
    
  #还需要指定下消息对象总线的id生成规则，避免client消费不到信息  
  cloud:
    bus:
      id: ${spring.application.name}:${spring.cloud.config.profile}:${random.value}    
```

使用Actuator组件实现配置信息的手动刷新：

Actuator是springCloud中的一个服务节点监控管理组件，主要用于管理整个服务集群的工作状况，这里用于更新Config组件的配置信息。

在config-service-a服务的config-server中默认为我们引用了Actuator组件，所以我们直接配置就行了

![image-20201128195459598](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201128195507.png)

我们在config-service-a的配置文件中加入如下配置，将bus消息总线的刷新请求暴漏给用户，这样我们就可以使用/actuator/bus-refresh或/actuator/refresh请求来刷新配置了

```yml
management:
  endpoints:
    web:
      exposure:
        include: "*"
```

此外，还要在controller类名上使用@RefreshScope，用于刷新当前类中使用的配置信息

```java
//用于刷新读取的配置信息
@RefreshScope
@RestController
public class ConfigController {
 //。。。。   
}
```

配置已完成后，依次启动config-service和config-client，访问config-client下的config-a接口得到一次配置数据结果：

![image-20201128201444449](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201128201444.png)

我们修改下git项目中配置信息为：

```
test: "I Want Fly！！！！！！"
```

之后需要使用postman发用一个post请求用于刷新配置，地址是

```java
//header需要改成application/json
//注意，这里是刷新config-service:8886的服务
http://localhost:8886/actuator/bus-refresh
```

执行完成后可以在config-client-a项目的控制台看到项目重新请求了配置数据，这个重新配置就是通过rabbitmq异步传过来的配置刷新请求

```
Fetching config from server at : http://10.0.20.11:8886/
...
```

当我们再次请求config-a接口时，发现结果变成了：

![image-20201128201903581](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201128201903.png)

说明配置被我手动修改成功

##### 4.自动刷新配置文件

上一节我们使用Actuator和bus总线组件手动完成了配置信息的更新，主要原理是利用消息中间件作为配置信息的载体，我们给config-service执行/bus-refresh时，会通过MQ给使用服务发送配置刷新请求，MQ就会自动的将最新的配置信息推送给所有使用统一配置的服务；但是这样还是比较麻烦，需要给config-service手动执行一次刷新才行。所以后来就出了一个新的功能用于自动刷新配置文件，这个组件就是config-monitor

下面来看看具体是怎么操作的：

我们在config-service中加入依赖：

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-config-monitor</artifactId>
</dependency>
```

这个依赖会将/bus-refresh转换为/monitor请求，并和git项目上webhooks联系起来(webhooks的作用是在每次提交git请求到git网端时，会默认执行一个请求，这个请求需要我们自己配置)。

我们开一个内网穿透，将config-service 的8886端口映射到外网

![image-20201128202637630](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201128202637.png)

之后在github上给我们的统一配置项目配置webhooks信息

![image-20201128202737368](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201128202737.png)

配置的路径是外网域名加/monitor请求

![image-20201128203442501](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201128203442.png)

```java
以上面的穿透域名为例就是：
https://spring11.utools.club/monitor
```

这样每次提交一个git请求就等同于给config-service执行一次/bus-refresh配置刷新请求

之后我们试着修改一次配置文件并提交到git，会发现config-client-a的确收到了配置刷新的日志：

![image-20201128203300933](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201128203301.png)

再次访问/config-a端口发现配置的确改了

参考：

https://www.cnblogs.com/nastynail/p/12517247.html

https://blog.51cto.com/zero01/2171735

https://artisan.blog.csdn.net/article/details/89117473

https://www.freesion.com/article/5119651046/