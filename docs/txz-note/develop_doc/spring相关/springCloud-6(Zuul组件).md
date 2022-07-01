springCloud-6(Zuul组件)

### Zuul组件的使用

接上文service-a有两个服务节点：8882和8883，service-b一个节点8884

##### 1.创建Zuul服务

新建一个module，名称为service-zuul-a，在创建时引入web、eureka client和zuul starter，对应pom节点如下：

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
    <artifactId>spring-cloud-starter-netflix-zuul</artifactId>
</dependency>
```

在启动类中添加注册eureka服务注解@EnableEurekaClient和Zuul开启注解@EnableZuulProxy

```java
@SpringBootApplication
@EnableEurekaClient
//开启zuul网关代理
@EnableZuulProxy
public class ServiceB2Application {
    public static void main(String[] args) {
        SpringApplication.run(ServiceB2Application.class, args);
    }
}
```

我们在application.yml配置中设置zuul和其他服务的映射关系：

```yml
# 应用名称
spring:
  application:
    name: service-zuul-a
# 应用服务 WEB 访问端口
server:
  port: 8885

eureka:
  client:
    register-with-eureka: true
    fetch-registry: true
    service-url:
      defaultZone: http://127.0.0.1:8881/eureka
  instance:
    #使用ip注册服务
    prefer-ip-address: true
    instance-id: ${spring.cloud.client.ip-address}${server.port}

zuul:
  prefix: /service
  routes:
    api-a:
      path: /api-a/**
      serviceId: SERVICE-A
    api-b:
      path: /api-b/**
      serviceId: SERVICE-B

#处理通过zuul路由访问504，不触发熔断降级问题
ribbon:
  # 请求处理超时时间
  ReadTimeout: 5000
  # 请求连接超时时间
  ConnectTimeout: 1000
```

分析在上述配置，可以通过本服务的/service/api-a/** 访问到service-a的接口，通过/service/api-b/** 访问到service-b的接口。(注意serviceId需要大写)

##### 2.测试网关路由功能

启动当前服务访问8885端口下的接口：

发现/service/api-a/访问到了sevice-a的接口，而且实现了负载均衡

![1](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201125175017.gif)

```
注意：zuul的负载均衡是对整个系统集群外的用户提供的负载均衡，而ribbon的负载均衡是在系统集群内服务节点之间使用的
```

/service/api-b/访问到了sevice-b的接口

![image-20201125175431205](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201125175431.png)

之后关闭service-a的两个服务，测试节点熔断功能：

![image-20201125175810724](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201125175810.png)

```
注意：若熔断后出现504错误，这是由于zuul内置的ribbon请求超时时间过短，没有大过映射服务节点的hystrix熔断限制时间导致的
可设置加大zuul超时时间即可
#处理通过zuul路由访问504，不触发熔断降级问题
ribbon:
  # 请求处理超时时间
  ReadTimeout: 5000
  # 请求连接超时时间
  ConnectTimeout: 1000
```

##### 3.测试请求过滤

创建一个过滤类继承ZuulFilter，实现其抽象方法

```java
@Component
public class CustomFiler extends ZuulFilter {
    @Override
    public String filterType() {
        return "pre";
    }

    @Override
    public int filterOrder() {
        return 0;
    }

    @Override
    public boolean shouldFilter() {
        return true;
    }

    @Override
    public Object run() throws ZuulException {
        RequestContext requestContext = RequestContext.getCurrentContext();
        HttpServletRequest request = requestContext.getRequest();
        String token = request.getParameter("token");
        //当请求不带token时，中断请求
        if(StringUtils.isBlank(token)){
            requestContext.setSendZuulResponse(false);
            requestContext.setResponseStatusCode(401);
            try {
                HttpServletResponse response = requestContext.getResponse();
                response.setCharacterEncoding("UTF-8");
                response.setHeader("Content-Type", "text/html;charset=utf-8");
                response.getWriter().write("权限不足！");
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return null;
    }
}
```

重启项目，当访问请求不带token时，返回权限不足

![image-20201125182002222](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201125182002.png)

当访问请求带token时才可以正常访问

![image-20201125182038384](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201125182038.png)