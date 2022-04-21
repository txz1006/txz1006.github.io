spring中BeanProcessor接口解析

### 一、BeanProcessor接口解析

#### 1. 简单认识BeanProcessor

- **BeanProcessor的理解**

  BeanProcessor是spring中的一个重要接口，他有两个接口方法一个是`postProcessBeforeInitialization`前置初始化，另一个是`postProcessAfterInitialization`后置初始化。从名称上就可以大概清楚这个接口的作用：在一个业务流程的前后加入两个接口方法，当执行这个业务流程时，就会触发这两个接口方法的执行。简单的总结一下有两个要点：

  1. 在业务流程中，根据BeanProcessor接口方法加在不同的位置(一般是前后)，可以实现对业务逻辑的扩展。
  2. 在业务逻辑执行前，BeanProcessor的实现类必须已经被创建完成(BeanProcessor接口类必须要优先实例化)。

  而在spring中，就有很多实现了BeanProcessor的bean，通过在重要的业务流程(如bean的生命周期流程)的前后加上BeanProcessor接口方法，就可以对业务逻辑进行修改或补充。

- **一个BeanProcessor的使用实例**

  在spring的bean生命周期中，BeanProcessor接口方法会在bean创建后的初始化方法(init-method或@PostConstruct指向的方法)前后执行`before`和`after`方法；那有没有在bean创建前后执行的接口方法呢？答案是肯定有的，这个功能是由BeanProcessor的子接口`InstantiationAwareBeanPostProcessor`来实现的，他也是有`before`和`after`方法，会在bean实例化前后执行。

  ![image-20200618202758534](https://img-blog.csdnimg.cn/2020062023052543.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2JhaWR1XzM4MzA0MTA0,size_16,color_FFFFFF,t_70#pic_center)

  我们先定义一个`BeanProcessor`接口实现类和一个`InstantiationAwareBeanPostProcessor`接口实现类。

  `BeanPostProcessor`实现类:

  ```java
  //net.postProcessor.CustomerPostProcessor
  @Component
  public class CustomerPostProcessor implements BeanPostProcessor {
  
     @PostConstruct
     public void init(){
        System.out.println("执行CustomerPostProcessor的PostConstruct");
     }
  
     public CustomerPostProcessor(){
        System.out.println("执行CustomerPostProcessor的构造方法");
     }
  
     @Override
     public Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
        System.out.println(bean+"======BeforeInitialization======"+ beanName);
        return bean;
     }
  
     @Override
     public Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
        System.out.println(bean+"======AfterInitialization======"+ beanName);
        return bean;
     }
  
  }
  ```

  `InstantiationAwareBeanPostProcessor`实现类:

  ```java
  //net.postProcessor.CustomerInitialPostProcessor
  @Component
  public class CustomerInitialPostProcessor implements InstantiationAwareBeanPostProcessor {
  
     @PostConstruct
     public void init(){
        System.out.println("执行CustomerInitialPostProcessor的PostConstruct");
     }
  
     public CustomerInitialPostProcessor(){
        System.out.println("执行CustomerInitialPostProcessor的构造方法");
     }
  
     @Override
     public Object postProcessBeforeInstantiation(Class<?> beanClass, String beanName) throws BeansException {
        System.out.println("bean初始化前执行：class为"+beanClass.getName()+"|beanName为"+beanName);
        return null;
     }
  
     @Override
     public boolean postProcessAfterInstantiation(Object bean, String beanName) throws BeansException {
        System.out.println("bean初始化后执行：Object为"+bean+"|beanName为"+beanName);
        return false;
     }
  }
  ```

  再创建一个普通的bean对象：

  ```java
  //net.postProcessor.FirstBean
  @Component
  public class FirstBean implements InitializingBean {
  
     private String msg = "hello";
  
     @PostConstruct
     public void init(){
        System.out.println("执行FirstBean的PostConstruct");
     }
  
     public FirstBean(){
        System.out.println("FirstBean构造方法！"+msg);
     }
  
     public String getMsg() {
        return msg;
     }
  
     public void setMsg(String msg) {
        this.msg = msg;
     }
  
     @Override
     public void afterPropertiesSet() throws Exception {
        System.out.println("执行FirstBean的afterPropertiesSet");
     }
  }
  ```

  我们创建一个spring工厂对象将上述bean加载进去：

  ```java
  @Test
  public void test(){
     AnnotationConfigApplicationContext applicationContext = new AnnotationConfigApplicationContext("net.postProcessor");
  }
  //执行得到以下结果：
  执行CustomerInitialPostProcessor的构造方法
  执行CustomerInitialPostProcessor的PostConstruct
  执行CustomerPostProcessor的构造方法
  执行CustomerPostProcessor的PostConstruct
      
  bean初始化前执行：class为net.postProcessor.FirstBean|beanName为firstBean
  FirstBean构造方法！hello
  bean初始化后执行：Object为net.postProcessor.FirstBean@79179359|beanName为firstBean
      
  net.postProcessor.FirstBean@79179359======BeforeInitialization======firstBean
  执行FirstBean的PostConstruct
  执行FirstBean的afterPropertiesSet
  net.postProcessor.FirstBean@79179359======AfterInitialization======firstBean    
      
  ```
  
  通过上述结果证明了我们之前的说法是正确的：
  
  1.BeanPostProcessor接口类会优先实例化，且在实例化中无法不会调用BeanPostProcessor接口方法的
  
  2.InstantiationAwareBeanPostProcessor接口方法会在FirstBean构造方法构造方法前后执行
  
  3.BeanPostProcessor接口方法会在FirstBean实例化后进行初始化的前后执行
  
  ------
  
  注解方法执行顺序：
  
  构造方法  --->  @postConstruct注解方法  ----> InitializingBean接口的afterPropertiesSet方法   --->xml的init-method方法
  
  注意：若@PostConstruct注解方法方法未执行，请加入`javax.annotation:javax.annotation-api:1.3.2`jar包依赖，原因是@PostConstruct是J2EE标准的注解，不是spring自己的接口，而在JDK8往上的版本中设计者打算弃用这些注解，所以做了处理，我们是没有办法直接使用J2EE标准注解的(@Resource、@PostConstruct、@PreDestroy等几个注解)，为了兼容这种情况，所以有了`javax.annotation-api`jar包的产生(或者降低JDK版本)。
  
  ![image-20200618210613065](https://img-blog.csdnimg.cn/20200620230547625.png#pic_center)

#### 2. BeanProcessor的实现思路和简化实例

- **BeanProcessor大概的实现思路**

  通过之前的了解BeanProcessor的使用，我们可以知道BeanProcessor并不复杂，但是却十分的重要，下面来分析下BeanProcessor的实现思路：

  1. 创建个接口A，接口包含一些切点方法(Before、After、Around之类的)，实现这个接口A的类要在使用前就创建好

  2. 我们需要有个业务流程，这个业务流程由若干步组成；将接口A的接口方法插入到这些业务步骤之间(需要扩展的地方)

  3. 要执行这个业务流程时，把接口A的实现类对象赋值到业务流程中，在执行业务流程中，就会触发接口方法的执行完成功能扩展

  当我们更换赋值到业务流程中的接口A的实现类时，对应的扩展逻辑也会随之变化，这样就实现了可插拔式的扩展逻辑(策略模式)。

- **一个BeanProcessor的简化逻辑实例**

  在spring中我们可以创建任意数量的bean实现BeanProcessor接口，所以实际上我们是要一个全局的`beanProcessorList`对象用来存储这些BeanProcessor对象；在执行业务代码时，要循环这个`beanProcessorList`对象，获取你需要的BeanProcessor对象来执行接口方法。下面是一个模拟spring bean生命周期的简化版，来帮助你理解spring中BeanProcessor的工作原理。

  net.postProcessor.SecondBean.java

  ```java
  @Component
  public class SecondBean {
  
     private String msg = "world";
  
     public SecondBean(){
        System.out.println("SecondBean构造方法！"+msg);
     }
  
     public String getMsg() {
        return msg;
     }
  
     public void setMsg(String msg) {
        this.msg = msg;
     }
  }
  ```
  
  net.postProcessor.CustomerPostProcessor.java
  
  ```java
  @Component
  public class CustomerPostProcessor implements BeanPostProcessor {
  
     @PostConstruct
     public void init(){
        System.out.println("执行CustomerPostProcessor的PostConstruct");
     }
  
     public CustomerPostProcessor(){
        System.out.println("执行CustomerPostProcessor的构造方法");
     }
  
     @Override
     public Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
        System.out.println(bean+"======BeforeInitialization======"+ beanName);
        return bean;
     }
  
     @Override
     public Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
        System.out.println(bean+"======AfterInitialization======"+ beanName);
        return bean;
     }
  
  }
  ```
  
- net.postProcessor.PostProcessor.java

  ```java
  public class PostProcessor {
  
     //模拟扫描到的bean信息<"SecondBean", "net.postProcessor.SecondBean">
     Map<String, String> scanBeanMap = new HashMap<>();
  
     //模拟spring的beanPostProcessors列表
     List<BeanPostProcessor> processorBeanList = new ArrayList<>();
  
     //模拟bean对象缓存
     Map<String, Object> beanCache = new HashMap<>();
  
     //添加扫描的bean信息
     public PostProcessor addBeanInfo(String beanName, String classPath){
        this.scanBeanMap.put(beanName, classPath);
        return this;
     }
  
     //模拟bean创建流程
     public Object execute(){
        try {
           //先临时存储实现了postProcessor接口的bean对象
           List<BeanPostProcessor> postProcessorStrList = new ArrayList<>();
           //循环scanBeanMap，获取bean列表中实现了postProcessor接口的类，加入processorBeanList中
           for(String temp: scanBeanMap.keySet()){
              Class<?> clazz = Class.forName(scanBeanMap.get(temp));
              //判断是否实现了BeanPostProcessor接口
              if(BeanPostProcessor.class.isAssignableFrom(clazz)){
                 //实例化让如临时容器
                 postProcessorStrList.add((BeanPostProcessor)createBean(temp));
              }
           }
           //将实现了postProcessor接口的bean加入processorBeanList中
           for(BeanPostProcessor obj: postProcessorStrList){
              processorBeanList.add(obj);
           }
  
           //再次循环scanBeanMap初始化所用bean
           for(String temp: scanBeanMap.keySet()){
              createBean(temp);
           }
  
        } catch (ClassNotFoundException e) {
           e.printStackTrace();
        }
        return null;
     }
  
     //bean实例化
     public Object createBean(String beanName){
        //从缓存中获取
        if(beanCache.containsKey(beanName)){
           return beanCache.get(beanName);
        }else{
           //缓存中取不到，则进行创建后加入缓存
           try {
              Class<?> clazz = Class.forName(scanBeanMap.get(beanName));
              //processor前置方法执行
              for(BeanPostProcessor processor : processorBeanList){
                 processor.postProcessBeforeInitialization(clazz, beanName);
              }
  
              //bean实例化
              Object result = clazz.getConstructor().newInstance();
  
              //processor后置方法执行
              for(BeanPostProcessor processor : processorBeanList){
                 processor.postProcessAfterInitialization(result, beanName);
              }
  
              //将bean加入缓存
              beanCache.put(beanName, result);
              return result;
           } catch (ClassNotFoundException e) {
              e.printStackTrace();
           } catch (IllegalAccessException e) {
              e.printStackTrace();
           } catch (InstantiationException e) {
              e.printStackTrace();
           } catch (NoSuchMethodException e) {
              e.printStackTrace();
           } catch (InvocationTargetException e){
              e.printStackTrace();
           }
        }
        return null;
     }
  
  }
  ```

  代码调用

  ```java
  public static void main(String[] args) {
     PostProcessor postProcessor = new PostProcessor();
     //添加扫描到的bean
     postProcessor
     .addBeanInfo("SecondBean", "net.postProcessor.SecondBean")
     .addBeanInfo("CustomerPostProcessor", "net.postProcessor.CustomerPostProcessor");
     postProcessor.execute();
  }
  
  //执行结果
  执行CustomerPostProcessor的构造方法
  class net.postProcessor.SecondBean======BeforeInitialization======SecondBean
  SecondBean构造方法！world
  net.postProcessor.SecondBean@1b40d5f0======AfterInitialization======SecondBean
  ```

  代码逻辑如下：

  1. 循环bean信息列表，将BeanPostProcessor接口bean分离出来优先实例化(实例化中缓存bean对象)，并将之放入临时容器。

  2. 循环完成，将临时容器中的BeanPostProcessor接口bean赋值到全局BeanPostProcessor接口列表中
  3. 再次循环bean信息列表，缓存存在则直接返回缓存对象，不存在则进行bean实例化，期间循环调用全局BeanPostProcessor接口对象方法

#### 3. spring中BeanProcessor的源码解析

我们要从spring中的refresh()开始看起：

```java
public void refresh() throws BeansException, IllegalStateException {
   synchronized (this.startupShutdownMonitor) {
      // Prepare this context for refreshing.
      //刷新准备
      prepareRefresh();

      // Tell the subclass to refresh the internal bean factory.
      //告诉子类刷新内部bean工厂。
      ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

      // Prepare the bean factory for use in this context.
      //为容器准备bean工程
      prepareBeanFactory(beanFactory);

      try {
         // Allows post-processing of the bean factory in context subclasses.
         //允许在上下文bean的后处理工厂子类。
         postProcessBeanFactory(beanFactory);

         // Invoke factory processors registered as beans in the context.
         //优先将BeanDefinitionRegistryPostProcessor\BeanFactoryPostProcessor接口的bean对象实例化
         //属于spring内部组件调用
         invokeBeanFactoryPostProcessors(beanFactory);

         // Register bean processors that intercept bean creation.
         //处理用户自定义PostProcessor接口对象，之后加入spring的beanPostProcessors列表，
         // 供之后预实例化其他bean时触发这些PostProcessor方法
         registerBeanPostProcessors(beanFactory);

		//...省略代码
        //实例化所有(non-lazy-init)单件。
		finishBeanFactoryInitialization(beanFactory);
      }

      catch (BeansException ex) {
         if (logger.isWarnEnabled()) {
            logger.warn("Exception encountered during context initialization - " +
                  "cancelling refresh attempt: " + ex);
         }

         // Destroy already created singletons to avoid dangling resources.
         //bean销毁
         destroyBeans();

         // Reset 'active' flag.
         //取消刷新
         cancelRefresh(ex);

         // Propagate exception to caller.
         throw ex;
      }

      finally {
         // Reset common introspection caches in Spring's core, since we
         // might not ever need metadata for singleton beans anymore...
         //重置公共缓存
         resetCommonCaches();
      }
   }
}
```

其中包含有postProcess字段都有可能和BeanProcessor相关，这里有三个相关方法：

1. postProcessBeanFactory(beanFactory)，这个是一共空的扩展方法，显然无关
2. invokeBeanFactoryPostProcessors(beanFactory)，处理spring中实现了BeanProcessor接口的内部组件直接调用接口方法
3. registerBeanPostProcessors(beanFactory)，实例化用户自定义BeanProcessor接口bean组件，之后循环赋值到全局BeanProcessor列表中

所以registerBeanPostProcessors()就是我们要找的对象，来跟进看下registerBeanPostProcessors()：

```java
//AbstractApplicationContext#registerBeanPostProcessors
protected void registerBeanPostProcessors(ConfigurableListableBeanFactory beanFactory) {
    //委托给PostProcessorRegistrationDelegate.registerBeanPostProcessors进行处理
	PostProcessorRegistrationDelegate.registerBeanPostProcessors进行处理(beanFactory, this);
}
```

继续跟进PostProcessorRegistrationDelegate.registerBeanPostProcessors()：

```java
public static void registerBeanPostProcessors(
      ConfigurableListableBeanFactory beanFactory, AbstractApplicationContext applicationContext) {

    //查询实现了BeanPostProcessor接口的beanName
   String[] postProcessorNames = beanFactory.getBeanNamesForType(BeanPostProcessor.class, true, false);

   // Register BeanPostProcessorChecker that logs an info message when
   // a bean is created during BeanPostProcessor instantiation, i.e. when
   // a bean is not eligible for getting processed by all BeanPostProcessors.
   int beanProcessorTargetCount = beanFactory.getBeanPostProcessorCount() + 1 + postProcessorNames.length;
   beanFactory.addBeanPostProcessor(new BeanPostProcessorChecker(beanFactory, beanProcessorTargetCount));

   // Separate between BeanPostProcessors that implement PriorityOrdered,
   // Ordered, and the rest.
   List<BeanPostProcessor> priorityOrderedPostProcessors = new ArrayList<>();
   List<BeanPostProcessor> internalPostProcessors = new ArrayList<>();
   List<String> orderedPostProcessorNames = new ArrayList<>();
   List<String> nonOrderedPostProcessorNames = new ArrayList<>();
    //根据beanName循环调用getBean进行实例化
   for (String ppName : postProcessorNames) {
      if (beanFactory.isTypeMatch(ppName, PriorityOrdered.class)) {
         BeanPostProcessor pp = beanFactory.getBean(ppName, BeanPostProcessor.class);
         priorityOrderedPostProcessors.add(pp);
         if (pp instanceof MergedBeanDefinitionPostProcessor) {
            internalPostProcessors.add(pp);
         }
      }
      else if (beanFactory.isTypeMatch(ppName, Ordered.class)) {
         orderedPostProcessorNames.add(ppName);
      }
      else {
         nonOrderedPostProcessorNames.add(ppName);
      }
   }

   // First, register the BeanPostProcessors that implement PriorityOrdered.
    //对BeanPostProcessor接口对象进行排序
   sortPostProcessors(priorityOrderedPostProcessors, beanFactory);
   //将获取到的PostProcessors接口对象加入到spring的beanPostProcessors列表
   registerBeanPostProcessors(beanFactory, priorityOrderedPostProcessors);

   // Next, register the BeanPostProcessors that implement Ordered.
   List<BeanPostProcessor> orderedPostProcessors = new ArrayList<>();
   for (String ppName : orderedPostProcessorNames) {
      BeanPostProcessor pp = beanFactory.getBean(ppName, BeanPostProcessor.class);
      orderedPostProcessors.add(pp);
      if (pp instanceof MergedBeanDefinitionPostProcessor) {
         internalPostProcessors.add(pp);
      }
   }
   sortPostProcessors(orderedPostProcessors, beanFactory);
   registerBeanPostProcessors(beanFactory, orderedPostProcessors);

   // Now, register all regular BeanPostProcessors.
   List<BeanPostProcessor> nonOrderedPostProcessors = new ArrayList<>();
   for (String ppName : nonOrderedPostProcessorNames) {
      BeanPostProcessor pp = beanFactory.getBean(ppName, BeanPostProcessor.class);
      nonOrderedPostProcessors.add(pp);
      if (pp instanceof MergedBeanDefinitionPostProcessor) {
         internalPostProcessors.add(pp);
      }
   }
   registerBeanPostProcessors(beanFactory, nonOrderedPostProcessors);

   // Finally, re-register all internal BeanPostProcessors.
   sortPostProcessors(internalPostProcessors, beanFactory);
   registerBeanPostProcessors(beanFactory, internalPostProcessors);

   // Re-register post-processor for detecting inner beans as ApplicationListeners,
   // moving it to the end of the processor chain (for picking up proxies etc).
   beanFactory.addBeanPostProcessor(new ApplicationListenerDetector(applicationContext));
}
```

果然这里就是处理BeanPostProcessor接口的地方，逻辑和之前的思路类似：

1. 循环扫描到的bean列表，获取实现了BeanPostProcessor接口的beanName数组
2. 循环beanName数组数组，调用beanFactory.getBean()将bean实例化，并放入priorityOrderedPostProcessors列表中
3. 调用sortPostProcessors对priorityOrderedPostProcessors列表进行排序(处理BeanPostProcessor调用的顺序)
4. 调用registerBeanPostProcessors将priorityOrderedPostProcessors列表中的bean对象赋值到全局列表beanPostProcessors中
5. 回到refresh()中，当调用finishBeanFactoryInitialization()对所用bean进行预实例化时就会调用这些BeanPostProcessor接口方法

#### 总结

总结一下spring处理BeanPostProcessor接口的逻辑：

1.有一个全局的BeanProcessor接口列表对象，用来存储所有的BeanProcessor接口对象

2.BeanProcessor接口对象会优先实例化，用于之后其他bean实例化时能获取到BeanProcessor接口对象

3.将实例化的接口对象加到全局BeanProcessor接口列表中，同时将BeanProcessor接口方法写到(织入)bean实例化的流程中(AbstractAutowireCapableBeanFactory#createBean())，BeanProcessor接口方法会在bean首次创建时读取全局BeanProcessor接口列表执行对应的接口方法会

4.在bean实例化流程(AbstractBeanFactory#getBean())中先获取缓存对象，缓存不存在则进行创建bean过程，其中会全局的BeanProcessor接口列表执行接口方法

