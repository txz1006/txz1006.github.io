## V3框架使用spring注解的注意事项



#### **一、现有V3bean加载逻辑**

- 项目启动时会创建一个父spring容器对象，这个容器内会创建一批最开始的bean，用来启动整个V3项目。
- 其中的核心启动对象是V3ApplicationContextLoader，这个对象会在初始化方法afterPropertiesSet()中完成整个V3项目的构建，主要的逻辑是在父spring容器的基础上，扫描所有的/META-INF/v3/applicationContext-配置文件，并按照来源进行分类，每个来源的就是一个模块，每个模块都会创建一个子spring容器(并指向同一个父spring容器)，之后会分别解析各自模块XML中的bean到各自的子容器中。
- 模块和模块之间可以通过<v:v3-bean-proxy/>标签配置进行bean跨模块注入，参考V3框架文档

![image-20211110115305510](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111101153708.png)

![image-20211110115413423](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111101154496.png)

#### **二、配置注解使用与限制**

##### 1.注解注册bean

 首先在当前项目中增加一个applicationContext应用配置xml，开启spring注解支持：

```xml
    <!-- 开启注解配置 -->
    <context:annotation-config/>

    <!-- 开启组件扫描 -->
    <context:component-scan base-package="net.newcapec.campus"/>

    <!--开启SPRING事务注解解释器 -->
    <!--默认使用transactionManager作为事务管理器，或者自行指定如@Transactional("logDB_transactionManager") -->
    <tx:annotation-driven />

    <!-- 开启SPRING CACHE注解解释器 -->
<!--    <cache:annotation-driven cache-manager="springCacheManager"/>-->
```

 配置已上三个标签后就可以使用注解了。下面是使用注解的方式将一个java类注册成bean：

```java
@Component //适用于所有层
@Configuration + @Bean //适用于所有层
@Service //适用于Service层
@Controller //适用于Controller层
@Repository //适用于持久层
```

上面几种方式的注解都可以让spring扫描到项目包下的java类，并将之实例化到IOC容器中，选择一个标注在类上就行。

 注意点：一个类不要既有xml bean标签配置，又设置注解创建方式

##### 2.依赖注入

对于一个bean中的成员变量而言，我们可以使用下面的注解来进行依赖注入

```java
@Autowired + @Qualifier
@Resource
```

 注意点：

- 被注入的bean必须是当前模块的IOC容器存在的bean，或者是父IOC容器存在的bean
- 存在父类的的bean必须使用xml指定具体的父类的注入对象，但是可以不写property标签，使用注解注入成员变量(注意，跨模块的bean注入必须写property标签)
- 如果想跨模块注入bean，被注入的bean需要使用xml定义，而且必须要写入/META-INF/v3-spring-plugin-*.xml的bean配置文件中

##### 3.配置常量注入

如有bean需要注入配置文件中的常量，需要创建对应的bean标签让spring创建PropertyPlaceholderConfigurer配置对象，如下所示：

```xml
<bean id="jpushProperty" class="org.springframework.beans.factory.config.PropertyPlaceholderConfigurer">
    <property name="location" value="classpath:jpush.properties"/>
    <property name="ignoreUnresolvablePlaceholders" value="true"/>
</bean>
```

然后通过@Value注解指定属性名称即可注入 

注意点：该配置需要在当前模块下的applicationContext-*的配置文件中才有效

##### 4.事务注解的使用

在业务方法中，如果想让整个方法作为一个完整的事务的话，可以使用@Transactional注解标注业务方法即可。

 注意点：由于V3目前存在业务库和日志库等多个数据源，所以也存在多个事务管理对象，在使用@Transactional时，只会对某一中数据源的DAO对象生效，默认是对业务库的DAO对象生效，也可以指定具体的事务管理对象如：@Transactional("logDB_transactionManager")

##### 5.AOP注解

如果需要使用制作切面，可以使用@Aspect、@Pointcut、@Around等注解来实现。首先先要开启AOP功能：

可以选择在XML中写入<aop:aspectj-autoproxy/>，或者在某个bean上使用开启AOP代理的注解：@EnableAspectJAutoProxy

之后就可以使用相关注解编写切面代码了，下面是一个切面例子：

```java
@Component
@Aspect
public class AopTest {

    @Pointcut("@annotation(net.newcapec.campus.Aop)")
    public void pointCut(){};

    @Before("pointCut()")
    public void before(){
        System.out.println("执行前");
    }
    
    @Around("pointCut()")
    public Object around(ProceedingJoinPoint joinPoint) throws Throwable {
        System.out.println("围绕前");
        Object obj  = joinPoint.proceed();
        System.out.println("围绕后");
        return obj;
    }
}
```

#### **三、总结**

- 注解的使用的确可以减少一部分XML配置，但是没法完全不写XML：遇到存在注入指定父类变量、跨模块的注入bean不需要写XML，

  ```xml
  <!--parent="transactionProxy"不能省略-->   
  <bean id="customerManager" parent="transactionProxy">
          <property name="target">
              <!--p:dao-ref="customerDao"不能省略-->   
              <bean class="net.newcapec.campus.server.manager.impl.CustomerManagerImpl"
                    p:dao-ref="customerDao">
                  	<!--userService是其他子模块的bean，不能省略-->   
                      <property name="userService" ref="userService"/>
  <!--下面的属性可以省略，使用注解注入-->
  <!--                <property name="campusOrgManager" ref="campusOrgManager"/>-->
  <!--                <property name="campusPreferenceUtils" ref="preferenceUtils"/>-->
  <!--                <property name="cpUserManager" ref="cpUserManager"/>-->
  <!--                <property name="redisCustomerManager" ref="redisCustomerManager"/>-->
  <!--                <property name="ossService" ref="ossService"/>-->
  <!--                <property name="cpBlackListSubManager" ref="cpBlackListSubManager"/>-->
              </bean>
          </property>
      </bean>
  <!--说明从哪个子模块中注入userService到当前模块-->
      <v:v3-bean-proxy alias="userService" bean-id="userService"
                       module-id="v3-security-app"/>
  ```

- 没有父类，跨模块bean注入的类，完全可以不写xml，全使用注解工作

- 测试类中如果使用了spring环境来注入bean，只可以注入父spring容器的的bean，不可以直接注入子模块的bean

  

#### **四、示例**

下面以一个无XML配置的process处理类作为示例展示：

StandardCardStyleProcess类：

```java
@Service
public class StandardCardStyleProcess extends BaseMessageProcess {

    protected transient Logger logger = LoggerFactory.getLogger(this.getClass());
    @Resource
    private CpUserManager cpUserManager;
    @Autowired
    private CustomerManager customerManager;
    @Autowired
    private AdConfigManager adConfigManager;
    @Autowired
    private FuncClickLogManager funcClickLogManager;
    @Autowired
    private V3ApplicationContextLoader applicationContextLoader;
    @Autowired
    private StandardCardStyleProcess1 s1;
    @Autowired
    private StandardCardStyleProcess2 s2;

    @Override
    public String getCommand() {
        return StandardCardStyleCommand.COMMAND;
    }

    public StandardCardStyleProcess(){
        System.out.println("StandardCardStyleProcess构造方法");
    }

    @Override
    public BaseRequestCommand createRequestCommand(JSONObject jsonData) {
        return this.createRequestCommand(jsonData, StandardCardStyleCommand.class);
    }

    @Override
    public String process(SessionInfo sessionInfo, BaseRequestCommand baseRequestCommand) {
        	//...
    }
}
```

StandardCardStyleProcess1类：

```java
@Component
public class StandardCardStyleProcess1 {

    protected transient Logger logger = LoggerFactory.getLogger(this.getClass());
    @Autowired
    private CampusPreferenceUtils preferenceUtils;
    @Value("${jpush.appKey}")
    private String test1;

    public StandardCardStyleProcess1(){
        System.out.println("StandardCardStyleProcess1构造方法");
    }

    @PostConstruct
    public void setTest1(){
        System.out.println("StandardCardStyleProcess1初始化开始");
    }

}
```

StandardCardStyleProcess2类：

```java
@PropertySource("classpath:jpush.properties")
public class StandardCardStyleProcess2 implements InitializingBean {

    private String msg = "666";

    private Integer a = 7;

    @Value("${jpush.appKey}")
    private String appKey;

    @Autowired
    private CampusPreferenceUtils preferenceUtils;

    public StandardCardStyleProcess2(){
        System.out.println("StandardCardStyleProcess2构造方法");
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        System.out.println("StandardCardStyleProcess2初始化");
    }
}
```

StandardCardStyleProcess3类：

```java
@Configuration
public class StandardCardStyleProcess3 {
    @Bean
    public StandardCardStyleProcess2 getStandardCardStyleProcess2(){
        return new StandardCardStyleProcess2();
    }
}
```

打上断点，启动项目：

观察到StandardCardStyleProcess1在初始化时类中的preferenceUtils和常量均已注入：

![image-20211110142957924](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111101429982.png)

继续执行，观察到StandardCardStyleProcess2在初始化时类中的preferenceUtils和常量也已经注入了：

![image-20211110143123477](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111101431511.png)

![image-20211110143150084](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111101431144.png)

最后我们看到StandardCardStyleProcess类中的成员变量已经全部被注入成功：

![image-20211110143517967](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202111101435059.png)

