springCloud-4(Hystrix组件)

### Hystrix组件的使用

接上文service-a有两个服务节点：8882和8883，service-b节点：8884，且调用service-a的msg接口

##### 1.引入Hystrix

在service-b的pom文件中引入Hystrix依赖

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-hystrix</artifactId>
</dependency>
```

在service-b服务的/testHystrix接口上加上@HystrixCommand注解，设置fallbackMethod参数返回一个确定的方法结果

```java
@RequestMapping("testHystrix")
@HystrixCommand(fallbackMethod = "customBack")
public String open(String id){
    return restTemplate.getForObject("http://service-a/msg?id="+id, String.class);
}


public String customBack(String id){
    return "请求失败了，请稍后重试！"+id;
}
```

此时关闭8883端口的service-a服务，再次访问http://127.0.0.1:8884/testHystrix?id=1，由于刚刚关闭8883端口，由于注册中心没有将其去除，还会访问到8883端口上，不过8883端口不通，触发断路器，执行fallbackMethod的方法；在多次访问后就完全访问不到8883端口了。

![1](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201119180347.gif)

若是8882端口服务也关闭，则此时service-b一定会执行断路器方法，执行fallbackMethod。