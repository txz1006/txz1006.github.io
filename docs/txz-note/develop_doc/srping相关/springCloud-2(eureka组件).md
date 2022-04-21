springCloud-2(eureka组件)

### Eureka组件的使用

我们需要使用springboot搭建两个服务，一个作为eureka的服务端，负载记录其他注册的服务；另一个作为客服端，会将服务信息注册导eureka服务端中。

##### 1.Eureka服务端环境搭建

新建项目，选择spring initializr，构建项目

![image-20201118174019134](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201118174019.png)

在NEXT第三步中选择Eureka Server组件依赖后完成项目的构建

![image-20201118174156846](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201118174156.png)

项目构建完成后，找到springboot启动类，添加启动eureka server注解@EnableEurekaServer

```java
@SpringBootApplication
@EnableEurekaServer
public class SpringcloudApplication {

    public static void main(String[] args) {
        SpringApplication.run(SpringcloudApplication.class, args);
    }

}
```

在resources目录下创建配置文件application.yml，并写入下面的配置

```yml
# 应用名称(对外暴漏的本服务名称)
spring:
  application:
    name: springcloud
#端口
server:
  port: 8881

eureka:
  client:
    #设置本服务为eureka容器
    service-url:
      defaultZone: http://127.0.0.1:8881/eureka
    #注册中心本身不需要搜索服务
    fetch-registry: false
    #注册中心本身不需要注册服务
    register-with-eureka: false
```

启动项目，访问http://127.0.0.1:8881，得到eureka容器监控信息：

![image-20201118175200101](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201118175200.png)

##### 2.Eureka客户端搭建

在当前项目新增一个module，在选择依赖时需要选择Web和Eureka client两个starter

![image-20201118175905557](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201118175905.png)

在启动类中添加eureka client注册注解@EnableEurekaClient

```java
@SpringBootApplication
@EnableEurekaClient
public class ServiceAApplication {

    public static void main(String[] args) {
        SpringApplication.run(ServiceAApplication.class, args);
    }

}
```

创建application.yml配置文件

```yml
# 应用名称
spring:
  application:
    name: service-a
# 应用服务 WEB 访问端口
server:
  port: 8882

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
```

启动项目后，再次回到Eureka监控页面，刷新后可以看到service-a服务已经注册导eureka 中

![image-20201118180434688](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201118180434.png)