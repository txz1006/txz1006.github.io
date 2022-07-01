spring中AOP解析

### 一、spring中AOP解析(注解式)

- #### **AOP介绍与使用**

  AOP直译为面向切面编程，解释为在不改变代码顺序的前提下，实现在一个顺序执行的逻辑代码之间插入扩展逻辑的的目的；举个例子：一个逻辑A执行顺序是X->Y,现在有另外一个逻辑C，想要在不改变逻辑A代码的前提下将逻辑C插入到X和Y之间，将逻辑A执行顺序改为X->C->Y，这就是切面编程的应用(方法增强)。

  ------

  spring中已经默认实现了AOP功能，我们可以通过简单的配置就能使用AOP实现对指定方法的业务扩展。下面我们来写一个简单的AOP实例：

  net.aop.AopTest.java(切面类)

  ```java
  @EnableAspectJAutoProxy
  @Aspect
  @Component
  public class AopTest {
     //切点方法(代指被代替的方法)
     //这里使用了execution表达式(任意返回值 net.aop包及子包的所有类的所有方法 参数数量不限)
     //@Pointcut("@annotation(net.newcapec.campus.Aop)") 标识注解
     @Pointcut("execution(* net.aop..*(..))")
     public void aspect() { }
  
     //切点方法前执行
     @Before("aspect()")
     public void before(JoinPoint joinPoint){
        System.out.println("===========Before切点前======="+joinPoint);
     }
  
     //环绕切点方法执行
     @Around("aspect()")
     public void Around(JoinPoint joinPoint) throws Throwable {
        System.out.println("===========Around环绕前======="+joinPoint);
        ((ProceedingJoinPoint)joinPoint).proceed();
        System.out.println("===========Around环绕后======="+joinPoint);
     }
  
     //切点方法后执行
     @After("aspect()")
     public void after(JoinPoint joinPoint){
        System.out.println("===========After切点后======="+joinPoint);
     }
  
     //切点方法返回后执行
     @AfterReturning("aspect()")
     public void afterReturning(JoinPoint joinPoint){
        System.out.println("===========afterReturning返回后======="+joinPoint);
     }
  
     //切点方法抛出异常后执行
     @AfterThrowing("aspect()")
     public void afterThrowing(JoinPoint joinPoint){
        System.out.println("===========AfterThrowing异常抛出后======="+joinPoint);
     }
  }
  ```
  
  net.aop.ExecutorBean.java(被扩展的bean)
  
  ```java
  @Component
  public class ExecutorBean {
  
     private String msg = "msg";
  
     public void test(){
        System.out.println("========="+msg);
     }
  }
  ```
  
  通过spring调用：
  
  ```java
  @Test
  public void test() {
     ApplicationContext configApplicationContext = new AnnotationConfigApplicationContext("net.aop");
     ExecutorBean bean = configApplicationContext.getBean(ExecutorBean.class);
      bean.test();
  }
  
  //执行结果：
  ===========Around环绕前=======execution(void net.aop.ExecutorBean.test())
  ===========Before切点前=======execution(void net.aop.ExecutorBean.test())
  =========msg
  ===========Around环绕后=======execution(void net.aop.ExecutorBean.test())
  ===========After切点后=======execution(void net.aop.ExecutorBean.test())
  ===========afterReturning返回后=======execution(void net.aop.ExecutorBean.test())
  ```
  
  ​		上述实例在没有改变ExecutorBean的前提下，实现了对于test()方法的扩展。主要逻辑是创建了一个切面bean，将切面bean的切点指向了net.aop包下的所有类的所有方法，也就是执行net.aop包下的所有方法都会触发执行切面定义的扩展方法。

------

注意：spring中使用AOP，需要开启AOP解析器，上述实例全部使用注解，注解开启AOP的是**@EnableAspectJAutoProxy**，而XML式的配置是**&#60;aop:aspectj-autoproxy/&#62;**，都只需要配置一次就可以启用AOP功能。

- #### **spring中AOP的解析**

  (注意：下文内容需要知道到springIOC创建流程、spring对beanProsessor接口类的应用和JDK、Cglib动态代理相关知识，请提前了解相关知识要点)

  ------
  
  spring创建IOC容器时，会先根据获取到bean信息创建一个BeanDefinition对象列表，之后根据BeanDefinition列表对bean进行一一实例化。而AOP的逻辑就是使用beanProsessor接口类拦截了AOP被代理类的创建，动态创建了一个织入切面方法的被代理类bean，之后将这个bean加入IOC容器提供使用。下面会通过spring源码了解这个过程：
  
  1. 上文我们通过一个切面类AopTest和**@EnableAspectJAutoProxy**就完成了AOP的配置，这里我们从AOP开关**@EnableAspectJAutoProxy**开始看起：
  
     ```java
     @Target(ElementType.TYPE)
     @Retention(RetentionPolicy.RUNTIME)
     @Documented
     @Import(AspectJAutoProxyRegistrar.class)
     public @interface EnableAspectJAutoProxy {
     
        boolean proxyTargetClass() default false;
     
        boolean exposeProxy() default false;
     
     }
     ```
  
     ```java
     class AspectJAutoProxyRegistrar implements ImportBeanDefinitionRegistrar {
     
        @Override
        public void registerBeanDefinitions(
              AnnotationMetadata importingClassMetadata, BeanDefinitionRegistry registry) {
     		//注册AnnotationAwareAspectJAutoProxyCreator.class到spring中
           AopConfigUtils.registerAspectJAnnotationAutoProxyCreatorIfNecessary(registry);
     
     		//代码省略...	
        }
     
     }
     ```
  
     其中**@EnableAspectJAutoProxy**中的关键是**@Import(AspectJAutoProxyRegistrar.class)** @Import注解的作用是将参数class封装成BeanDefinition注册到spring中；但是**AspectJAutoProxyRegistrar.class**是一个注册器对象(**ImportBeanDefinitionRegistrar**接口对象)，spring不会直接将注册器对象直接注册到spring中，而是在之后会执行**ImportBeanDefinitionRegistrar**接口对象的**registerBeanDefinitions**方法，将注册器中指定的对象注册到spring中。**AspectJAutoProxyRegistrar.class**的接口方法注册的是**AnnotationAwareAspectJAutoProxyCreator.class**对象，这个对象是一个**BeanPostProcessor**接口对象，也是AOP的功能实现核心对象。继承链如下图所示：
  
     ![image-20200625111655142](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103231.png)
  
     **AnnotationAwareAspectJAutoProxyCreator**对象会和其他**BeanPostProcessor**接口对象一样，会提前实例化并加入spring的BeanPostProcessors列表中，在之后的spring bean预实例化中会循环这个BeanPostProcessors列表执行拦截方法作为创建其他bean时的扩展拦截器；主要拦截方法有两个，都在父类**AbstractAutoProxyCreator**中，
  
     一个是**postProcessBeforeInstantiation()**在bean实例化前执行，另一个是**postProcessAfterInitialization**在bean初始化完成后执行，代码逻辑如下：
  
     ```java
     //org.springframework.aop.framework.autoproxy.AbstractAutoProxyCreator
     @Override
     public Object postProcessBeforeInstantiation(Class<?> beanClass, String beanName) {
     	Object cacheKey = getCacheKey(beanClass, beanName);
     
     	if (!StringUtils.hasLength(beanName) || !this.targetSourcedBeans.contains(beanName)) {
     		if (this.advisedBeans.containsKey(cacheKey)) {
     			return null;
     		}
     		if (isInfrastructureClass(beanClass) || shouldSkip(beanClass, beanName)) {
     			this.advisedBeans.put(cacheKey, Boolean.FALSE);
     			return null;
     		}
     	}
     
     	//省略...
     
     	return null;
     }
     
     //AspectJAwareAdvisorAutoProxyCreator#shouldSkip
     @Override
     protected boolean shouldSkip(Class<?> beanClass, String beanName) {
     	// TODO: Consider optimization by caching the list of the aspect names
     	List<Advisor> candidateAdvisors = findCandidateAdvisors(); //查询切面bean列表
     	for (Advisor advisor : candidateAdvisors) {
     		if (advisor instanceof AspectJPointcutAdvisor &&
     				((AspectJPointcutAdvisor) advisor).getAspectName().equals(beanName)) {
     			return true;
     		}
     	}
     	return super.shouldSkip(beanClass, beanName);
     }
     
     //AnnotationAwareAspectJAutoProxyCreator#findCandidateAdvisors
     @Override
     protected List<Advisor> findCandidateAdvisors() {
     	// Add all the Spring advisors found according to superclass rules.
     	List<Advisor> advisors = super.findCandidateAdvisors();
     	// Build Advisors for all AspectJ aspects in the bean factory.
     	if (this.aspectJAdvisorsBuilder != null) {
             //构建有@Aspect注解的切面bean信息及对应的通知方法列表
     		advisors.addAll(this.aspectJAdvisorsBuilder.buildAspectJAdvisors());
     	}
     	return advisors;
     }
     ```
     
     我们以上文的ExecutorBean为例，在spring预实例化时，要通过ExecutorBean的BeanDefinition对象去实例化ExecutorBean，
     
     在实例化前会执行**postProcessBeforeInstantiation()**方法，此方法的主要逻辑是循环spring中bean列表，找到有**@Aspect**注解的切面bean即AopTest，将有AOP中通知注解(@Before、@After等)的方法封装成一个个Advisor接口对象(实际是InstantiationModelAwarePointcutAdvisorImpl对象)，这个对象中创建了和通知注解对应的回调对象(MethodInterceptor接口对象，如：AspectJMethodBeforeAdvice)，在循环完AopTest的方法后将封装的Advisor接口对象组织成list，放入advisorsCache<beanName, advisorList> Map缓存中。以上逻辑存在于**postProcessBeforeInstantiation()**中的shouldSkip方法中(shouldSkip主要判断是否要跳过当前bean)，只有在实例化用户自定义的第一个bean时才会执行完成，在之后实例化其他bean时会直接返回advisorsCache缓存数据。
     
     ------
     
     **postProcessBeforeInstantiation()**执行完后开始bean的创建和初始化，初始化完后执行**postProcessAfterInitialization()**方法，代码逻辑如下：
     
     ```java
     //org.springframework.aop.framework.autoproxy.AbstractAutoProxyCreator
     @Override
     public Object postProcessAfterInitialization(@Nullable Object bean, String beanName) {
     	if (bean != null) {
     		Object cacheKey = getCacheKey(bean.getClass(), beanName);
     		if (this.earlyProxyReferences.remove(cacheKey) != bean) {
     			return wrapIfNecessary(bean, beanName, cacheKey);
     		}
     	}
     	return bean;
     }
     
     //AbstractAutoProxyCreator#wrapIfNecessary
     protected Object wrapIfNecessary(Object bean, String beanName, Object cacheKey) {
     	if (StringUtils.hasLength(beanName) && this.targetSourcedBeans.contains(beanName)) {
     		return bean;
     	}
     	if (Boolean.FALSE.equals(this.advisedBeans.get(cacheKey))) {
     		return bean;
     	}
     	if (isInfrastructureClass(bean.getClass()) || shouldSkip(bean.getClass(), beanName)) {
     		this.advisedBeans.put(cacheKey, Boolean.FALSE);
     		return bean;
     	}
     
     	// Create proxy if we have advice.(判断当前bean是否匹配到某个切面切点表达式)
     	Object[] specificInterceptors = getAdvicesAndAdvisorsForBean(bean.getClass(), beanName, null);
     	if (specificInterceptors != DO_NOT_PROXY) {
     		this.advisedBeans.put(cacheKey, Boolean.TRUE);
             //（创建代理对象）
     		Object proxy = createProxy(
     				bean.getClass(), beanName, specificInterceptors, new SingletonTargetSource(bean));
     		this.proxyTypes.put(cacheKey, proxy.getClass());
     		return proxy;
     	}
     
     	this.advisedBeans.put(cacheKey, Boolean.FALSE);
     	return bean;
     }
     
     //org.springframework.aop.framework.DefaultAopProxyFactory#createAopProxy
     @Override
     public AopProxy createAopProxy(AdvisedSupport config) throws AopConfigException {
     	if (config.isOptimize() || config.isProxyTargetClass() || hasNoUserSuppliedProxyInterfaces(config)) {
     		Class<?> targetClass = config.getTargetClass();
     		if (targetClass == null) {
     			throw new AopConfigException("TargetSource cannot determine target class: " +
     					"Either an interface or a target is required for proxy creation.");
     		}
             //JDK代理
     		if (targetClass.isInterface() || Proxy.isProxyClass(targetClass)) {
     			return new JdkDynamicAopProxy(config);
     		}
             //Cglib代理
     		return new ObjenesisCglibAopProxy(config);
     	}
     	else {
             //JDK代理
     		return new JdkDynamicAopProxy(config);
     	}
     }
     ```
     **postProcessAfterInitialization()**的主要逻辑主要在方法**wrapIfNecessary()**中，该方法这主要逻辑是获取之前的切面Map缓存advisorsCache，通过切面的切点表达式来匹配当前bean路径，若匹配成功则返回对应切面的Advisor接口对象列表，进而执行**createProxy**方法创建bean的代理对象，创建代理对象会选择是JDK方式创建还是Cglib方式创建，创建时会将Advisor接口对象列表设置到代理对象中。代理对象创建完成后会替换创建的原实例化对象放入IOC容器中，当调用代理对象方法时会将Advisor接口对象列表设置到代理对象的回调方法中，并按顺序一一执行切面的通知方法逻辑，以此完成AOP的代理调用。
     
     ------
     

- #### 总结逻辑


1. 通过**@EnableAspectJAutoProxy**获取**AspectJAutoProxyRegistrar**注册器，**AspectJAutoProxyRegistrar**会执行注册器方法**registerBeanDefinitions**注册**AnnotationAwareAspectJAutoProxyCreator**(继承BeanPostProcessor接口)到spring的 beanDefinition列表中

2. **AnnotationAwareAspectJAutoProxyCreator**在实例化后加入BeanPostProcessors列表中

3. ExecutorBean预实例化时，在**createBean()**方法中循环BeanPostProcessors列表执行**AnnotationAwareAspectJAutoProxyCreator**的**postProcessBeforeInstantiation**获取切面方法列表(MethodInterceptor接口对象)

4. 之后在**doCreateBean()**#initializeBean()方法中循环BeanPostProcessors列表执行**postProcessAfterInitialization**方法--->通过**wrapIfNecessary**方法判断是否需求创建代理对象(若点面方法的execution表达式匹配到了当前bean才会创建代理对象)选择用JDK或Cglib创建bean代理对象(插入切面bean的方法)，将之前的切面方法列表赋值得到代理对象的回调列表中，之后返回代理对象完成实例化

5. 调用ExecutorBean的test方法会调用Cglib代理对象的invoke方法触发切面方法

   ------

   **附录**：BeanPostProcessor接口在spring中创建bean的关键位置图：

   ![image-20200625170346026](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103239.png)

**切点方法织入代理对象中：**
在bean实例化时，如果是切面指定的切点方法，则会创建代理对象，在代理对象方法执行时使用责任链循环执行切面方法和代理目标方法

```java
//调用代理对象的invoke方法
//是JDK或Cglib中invoke方法
@Override
public Object invoke(Object proxy, method method, Object[] args){
    MethodInvocation invocation = new MethodInvocation(proxy, method, args, 切面前后置方法对象列表);
    return invocation
}
//MethodInvocation是责任链中流转的变量对象，实现JoinPoint接口
    public Object proceed() throws Throwable {
        //每次流转后this.currentInterceptorIndex都会加一，所以每次的前后置方法的包装调用对象都不同
        //当前后置方法列表执行完成后，会反射调用切点目标方法
        if (this.currentInterceptorIndex == this.interceptorsAndDynamicMethodMatchers.size() - 1) {
            return this.method.invoke(this.target, this.arguments);
        }
        //interceptorsAndDynamicMethodMatchers是前后置方法的包装调用对象列表
        Object interceptorOrInterceptionAdvice =
           this.interceptorsAndDynamicMethodMatchers.get(++this.currentInterceptorIndex);
            //如果要动态匹配joinPoint
            if (interceptorOrInterceptionAdvice instanceof GPMethodInterceptor) {
                GPMethodInterceptor mi =
                        (GPMethodInterceptor) interceptorOrInterceptionAdvice;
				//将当前对象作为参数，调用interceptorsAndDynamicMethodMatchers列表中对应的切面前后置方法对象
                return mi.invoke(this);
            }
            else {
                //动态匹配失败时,略过当前Intercetpor,调用下一个Interceptor
            return proceed();
        }
    }
//interceptorsAndDynamicMethodMatchers是切面前后置方法对象列表，指对于前后置方法的包装调用对象
//例如：GPMethodBeforeAdviceInterceptor、GPMethodAroundAdviceInterceptor等，这些对象包含有通过反射调用前后置方法的所有信息，实现了一个带有MethodInvocation参数的接口：
public class GPMethodBeforeAdviceInterceptor extends GPAbstractMethodAspectJAdvice {

    private GPJoinPoint gpJoinPoint;

    public GPMethodBeforeAdviceInterceptor(Method aspectMethod, Object aspectTarget) {
        super(aspectMethod, aspectTarget);
    }

    @Override
    public Object invoke(GPMethodInvocation mi) throws Throwable {

        this.gpJoinPoint = mi;
        //反射调用前后置方法
        super.invokeAspectMethod(this.gpJoinPoint, null, null);
        //再次回调责任链流转对象的proceed方法，执行下一个前后置方法的包装调用对象
        //如GPMethodAfterAdviceInterceptor、GPMethodAroundAdviceInterceptor
        return mi.proceed();
    }
}
```

