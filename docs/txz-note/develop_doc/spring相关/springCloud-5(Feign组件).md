springCloud-5(Feign组件)

### Feign组件的使用

接上文service-a有两个服务节点：8882和8883，service-b一个节点8884，并且调用service-a的msg接口，已经使用了ribbon和hystrix完成了负载均衡和节点熔断

##### 1.引入feign组件

新建一个module，名称为service-b2，在创建时引入web、eureka client和feign starter，对应pom节点如下：

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
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>
```

在启动类中添加注册eureka服务注解@EnableEurekaClient和feign开启注解@EnableFeignClients

```java
@SpringBootApplication
@EnableEurekaClient
//实现接口RPC调用
@EnableFeignClients
public class ServiceB2Application {
    public static void main(String[] args) {
        SpringApplication.run(ServiceB2Application.class, args);
    }
}
```

创建一个接口在类名上使用@FeignClient表示当前接口所属的服务名称，使用@RequestMapping标注在接口方法上表示要调用服务的具体接口名称

```java
//表示调用service-a服务下接口
@FeignClient(value="service-a")
public interface ITestService {
    //注意接口参数需要使用@RequestParam标注，否则无法传递
    @RequestMapping("/msg")
    public String getObjectStr(@RequestParam("id") String id);

}
```

在一个controller中注入这个接口，并调用getObjectStr方法

```java
@RestController
public class TestController {
    @Autowired
    private ITestService iTestService;
    
    @RequestMapping("test")
    public String getMsg(String id){
        return iTestService.getObjectStr(id);
    }
}
```

开启项目，访问test接口：

![1](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201121174252.gif)

发现同样可以实现负载的效果，而且负载的策略是ribbon是一样轮询策略，若要修改，可以在appliction.yml中进行配置

##### 2.使用feign配置熔断逻辑

feign同样集成了Hystrix实现了熔断功能，

我们在application.yml配置中开启熔断：

```yml
#开启feign熔断
feign:
  hystrix:
    enabled: true
```

然后，回到ITestService接口中，在@FeignClient注解中增加一个参数fallbackFactory

```java
@FeignClient(value="service-a", fallbackFactory = TestFallBackService.class)
```

之后设置一个接口实现类对象，这个对象需要实现FallbackFactory<>接口，泛型指定为ITestService。

```java
//注意需要将该类注册成bean
@Component
public class TestFallBackService implements FallbackFactory<ITestService> {
    @Override
    public ITestService create(Throwable throwable) {
        return new ITestService(){
            @Override
            public String getObjectStr(String id) {
                return "获取到空数据！";
            }
        };
    }
}
```

这样就设置好了，我们把8882和8883端口项目都停掉，再次访问test接口就会得到熔断结果了：

![image-20201121175052698](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201121175052.png)