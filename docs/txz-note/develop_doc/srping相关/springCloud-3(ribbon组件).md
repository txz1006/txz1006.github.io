springCloud-3(ribbon组件)

### Ribbon组件的使用

接上文eureka组件的部署完成后，我们已经有一个服务注册中心，地址是http://127.0.0.1:8881；还有一个注册服务service-a，地址是http://127.0.0.1:8882

##### 1.创建一个web接口

我们在service-a中创建一个web接口

```java
//注意该类不要和springboot启动类同级，要在其同级子目录下
@RestController
public class FeignController {

    @Value("${server.port}")
    private String port;

    @RequestMapping("msg")
    public String getMsg(String id){
        return port+":查询服务A的msg接口：id为"+id;
    }
}
```

测试下接口的访问

![image-20201119154010682](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201119154017.png)

##### 2.创建另一个服务

我们在项目中中新增一个module，在选择依赖时需要选择eureka client、web和ribbon三个starter，对应的pom文件依赖如下：

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
    <artifactId>spring-cloud-starter-netflix-ribbon</artifactId>
</dependency>
```

在项目启动类中注册服务@EnableEurekaClient，以及注册一个开启了负载的RestTemplate

```java
@SpringBootApplication
@EnableEurekaClient
public class ServiceBApplication {

    public static void main(String[] args) {
        SpringApplication.run(ServiceBApplication.class, args);
    }

    @Bean
    //开启ribbon的负载均衡，默认使用轮询方式
    @LoadBalanced
    public RestTemplate getRestTemplate(){
        return new RestTemplate();
    }

}
```

创建application.yml，将服务命名为service-b，端口是8884

```yml
# 应用名称
spring:
  application:
    name: service-b
# 应用服务 WEB 访问端口
server:
  port: 8884

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
```

之后创建一个web接口，这个接口需要通过RestTemplate对象访问service-a的msg接口

```java
@RestController
public class TestController {
    @Autowired
    private RestTemplate restTemplate;

    @RequestMapping("testHystrix")
    public String open(String id){
        return restTemplate.getForObject("http://service-a/msg?id="+id, String.class);
    }

}
```

启动项目，访问/testHystrix接口

![image-20201119160124891](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201119160124.png)

通过实践，发现在8884端口，通过restTemplate访问/service-a/msg，成功的访问到了service-a的接口

##### 3.负载均衡

我们修改下service-a服务的端口为8883，再启一个service-a服务，此时的8881的eureka监控的注册服务信息如下

![image-20201119160839447](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201119160839.png)

可以发现，service-a的服务数量是2，此时service-a可以看成一个集群。

我们多次访问http://127.0.0.1:8884/testHystrix?id=1可以轮换访问8882端口和8883端口的msg接口，这就完成了service-a的负载均衡，

![1](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201119162703.gif)

