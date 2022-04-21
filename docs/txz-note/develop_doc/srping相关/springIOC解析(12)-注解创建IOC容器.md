springIOC解析(12)-注解创建IOC容器

### 一、AnnotationConfigApplicationContext解析

之前我们使用ClassPathXmlApplicationContext对象，解析xml配置来完成了IOC容器的创建；下面我们来看看注解的解析方式是什么样大的。这里我们使用AnnotationConfigApplicationContext来作为注解形式的spring管理对象。

创建一个包`net.anno`，将需要用实例化的bean放入其中：

```java
//package net.anno;
@Component
public class FooBean {

   @Autowired
   private SimpleBean simpleBean;

   @PostConstruct
   public void init(){
      System.out.println("执行FooBean的PostConstruct");
      simpleBean.setFooBean(this);
   }

   public void setSimpleBean(SimpleBean simpleBean) {
      this.simpleBean = simpleBean;
   }

   public SimpleBean getSimpleBean() {
      return simpleBean;
   }

}

@Component
public class SimpleBean {

	@Autowired
	private FooBean fooBean;

	@PostConstruct
	public void init(){
		System.out.println("执行SimpleBean的PostConstruct");
		this.fooBean.setSimpleBean(this);
	}

	public FooBean getFooBean() {
		return fooBean;
	}

	public void setFooBean(FooBean fooBean) {
		this.fooBean = fooBean;
	}
}
```

下面使用AnnotationConfigApplicationContext创建IOC容器并调用bean：

```java
public class AnnoHandler {

   public static void main(String[] args) {
      AnnotationConfigApplicationContext applicationContext = new AnnotationConfigApplicationContext("net.anno");
      FooBean foo = (FooBean)applicationContext.getBean("fooBean");
      System.out.println(foo.getSimpleBean());
   }
}
//运行打印net.anno.FooBean@56c4278e||net.anno.SimpleBean@20f5281c
```

在执行mian方法后成功打印了FooBean和SimpleBean对象信息，也就是AnnotationConfigApplicationContext同样完成了bean的装配流程，成功将bean写入到了IOC容器中，那么下面我们就来分析源码，看看AnnotationConfigApplicationContext都做了什么工作：

打上断点，debug走起ο(=•ω＜=)ρ⌒☆：

```java
//AnnotationConfigApplicationContext#AnnotationConfigApplicationContext(java.lang.String...)
public AnnotationConfigApplicationContext() {
    //注解bean定义读取对象
	this.reader = new AnnotatedBeanDefinitionReader(this);
    //类信息扫描对象
	this.scanner = new ClassPathBeanDefinitionScanner(this);
}

public AnnotationConfigApplicationContext(String... basePackages) {
   this();
   //扫描beanDefinition列表，注册到beanDefinition到容器
   scan(basePackages);
   //刷新IOC全部容器信息，重新注册缓存bean实例对象
   refresh();
}
```

这是AnnotationConfigApplicationContext的构造方法之一，只有三步操作：1.初始化；2.扫描包路径；3.刷新IOC容器。当我们看到`refresh()`时就知道了AnnotationConfigApplicationContext的肯定也处理IOC容器继承链中，他和ClassPathXmlApplicationContext调用的是同一个父类方法，下命来看下AnnotationConfigApplicationContext的继承链关系：

![image-20200613162330723](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103601.png)

对比之前的ClassPathXmlApplicationContext继承链，我们发现他们是在AbstractApplictionContext类之下才开始有了区别的。

到这里我们大概就能清楚XML和注解初始化IOC容器的区别了：

1.ClassPathXmlApplicationContext需要将xml配置读取成dom对象，将dom对象近一步解析成beanDefinition后完成IOC初始化

2.AnnotationConfigApplicationContext通过扫描类中的注解得到bean信息，并将bean信息近一步解析成beanDefinition后完成IOC初始化

两这的主要区别就是创建beanDefinition的方式不同而已。

下面我们来详细了解下AnnotationConfigApplicationContext是如何扫描注解得到beanDefinition的。