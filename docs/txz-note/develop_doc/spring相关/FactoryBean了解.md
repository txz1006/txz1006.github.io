FactoryBean了解

### 一、什么是FactoryBean

我们都知道BeanFactory是springIOC容器的核心工厂，可以使用BeanFactory接口衍生出来的对象(如ApplictionContext)来获取实例化对象。那这个FactoryBean是个什么东西？从名称上看他是一个'工厂Bean',一个特殊的bean。

从逻辑上看FactoryBean是一个接口，可以被实现。而在springDI源码中，需要对bean是否实现了FactoryBean进行判断，所以可以简单的认为FactoryBean是一种能创建Bean的特殊对象。

```java
//AbstractBeanFactory#getObjectForBeanInstance
if (!(beanInstance instanceof FactoryBean) || BeanFactoryUtils.isFactoryDereference(name)) {
   return beanInstance;
}
```

### 二、FactoryBean如何使用

1. 创建一个需要实例化的bean

   ```java
   public class SimpleBean {
   
   	private String msg = "Hello World！";
   
   	public void sendMsg(String msg){
   		System.out.println("===================");
   		System.out.println("+++++++++++++msg:"+msg+"+++++++++++++");
   		System.out.println("===================");
   	}
   }
   
   ```

2. 创建一个对应的FactoryBean对象，实现FactoryBean接口，包装上文的SimpleBean

   ```java
   public class SimpleFactoryBean implements FactoryBean<SimpleBean> {
   	
   	@Override
   	public SimpleBean getObject() throws Exception {
   		SimpleBean simpleBean = new SimpleBean();
   		simpleBean.sendMsg("SimpleFactoryBean创建");
   		return simpleBean;
   	}
   
   	@Override
   	public Class<?> getObjectType() {
   		return SimpleBean.class;
   	}
   
   }
   ```

3. 在配置文件中配置SimpleFactoryBean信息，使spring能扫描到bean信息

   ```java
   <bean id="simpleFactoryBean" class="net.plaz.bean.SimpleFactoryBean"></bean>
   ```

4. 创建容器对象调用simpleFactoryBean对象

   ```java
   	public static void main(String[] args) {
   		//加载容器
   		ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("config.xml");
   		//获取Bean
   		Object bean1 = context.getBean("simpleFactoryBean");
   		System.out.println(bean1);
   		Object bean2 = context.getBean("&simpleFactoryBean");
   		System.out.println(bean2);
   		//关闭容器
   		context.close();
   	}
   ```

5. 查看打印结果

   ```java
   20:31:29.693 [main] DEBUG o.s.c.s.ClassPathXmlApplicationContext - Refreshing org.springframework.context.support.ClassPathXmlApplicationContext@13526e59
   20:31:29.985 [main] DEBUG o.s.b.f.x.XmlBeanDefinitionReader - Loaded 1 bean definitions from class path resource [config.xml]
   20:31:30.101 [main] DEBUG o.s.b.f.s.DefaultListableBeanFactory - Creating shared instance of singleton bean 'simpleFactoryBean'
   ===================
   +++++++++++++msg:SimpleFactoryBean创建+++++++++++++
   ===================
   net.plaz.bean.SimpleBean@6c2ed0cd
   net.plaz.bean.SimpleFactoryBean@7d9e8ef7
   ```

   通过打印结果我们可以知道关于FactoryBean的几点信息：

   - 在spring实例化bean时，simpleFactoryBean会执行getObject()方法，返回一个SimpleBean对象
   - FactoryBean在注册时，会实例化两个对象到IOC容器中，一个是FactoryBean本身，一个是FactoryBean包装的getObject()对象
   - 通过获取‘simpleFactoryBean’到IOC容器中获取到的是其包装的getObject()对象
   - 通过在simpleFactoryBean前加&符号可以获取到FactoryBean对象本身

### 三、FactoryBean实现原理

待补充

### 三、FactoryBean的应用场景

通过上文的了解，我们可以认识到FactoryBean是一种比较简单、安全隔离的bean注册方式。所以我们可以将一些第三方的功能对象通过实现FactoryBean接口，将其交给spring来进行统一管理。

常见实例spring整合mybatis：

```java
//将mybatis的sqlSessionFactory对象注册到spring
<bean id="sqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean">
  <property name="dataSource" ref="dataSource" />
</bean>

//SqlSessionFactoryBean实质上实现了FactoryBean接口，在getObject()中返回一个实例对象
public class SqlSessionFactoryBean implements FactoryBean<SqlSessionFactory>, InitializingBean, ApplicationListener<ApplicationEvent> {
	// ...省略其他代码
	
	public SqlSessionFactory getObject() throws Exception {
	if (this.sqlSessionFactory == null) {
	  afterPropertiesSet();
	}

	return this.sqlSessionFactory;
	}
}

public void afterPropertiesSet() throws Exception {
    // buildSqlSessionFactory()方法会根据mybatis的配置进行初始化。
	this.sqlSessionFactory = buildSqlSessionFactory();
}

```

通过如此配置后，我们就可以直接在IOC容器中获取sqlSessionFactory对象了。

