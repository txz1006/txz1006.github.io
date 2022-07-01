springIOC解析(9)-初始化IOC容器

### 一、finishBeanFactoryInitialization初始化单例bean

回到我们的起点AbstractApplicationContext#refresh中，完成 obtainFreshBeanFactory()后我们得到了一个IOC容器(主要是创建了bean定义信息的Map），中间经过一系列处理后在`finishBeanFactoryInitialization(beanFactory);`中进行单例bean信息的初始化工作(使用beanDefinition创建bean实例)：

```java
//AbstractApplicationContext#finishBeanFactoryInitialization
//==========================
protected void finishBeanFactoryInitialization(ConfigurableListableBeanFactory beanFactory) {
   // Initialize conversion service for this context.
   //是否有转换服务的bean(例如时间格式转换)
   if (beanFactory.containsBean(CONVERSION_SERVICE_BEAN_NAME) &&
         beanFactory.isTypeMatch(CONVERSION_SERVICE_BEAN_NAME, ConversionService.class)) {
      beanFactory.setConversionService(
            beanFactory.getBean(CONVERSION_SERVICE_BEAN_NAME, ConversionService.class));
   }

   // Register a default embedded value resolver if no bean post-processor
   // (such as a PropertyPlaceholderConfigurer bean) registered any before:
   // at this point, primarily for resolution in annotation attribute values.
   //是否加入属性解析器(若之前没有解析器的话) 
   if (!beanFactory.hasEmbeddedValueResolver()) {
      beanFactory.addEmbeddedValueResolver(strVal -> getEnvironment().resolvePlaceholders(strVal));
   }

   // Initialize LoadTimeWeaverAware beans early to allow for registering their transformers early.
   //提前加载LoadTimeWeaverAware，用于加载Spring Bean时织入第三方模块, 如AspectJ
   String[] weaverAwareNames = beanFactory.getBeanNamesForType(LoadTimeWeaverAware.class, false, false);
   for (String weaverAwareName : weaverAwareNames) {
      getBean(weaverAwareName);
   }

   // Stop using the temporary ClassLoader for type matching.
   //停止使用临时的类型匹配类加载器
   beanFactory.setTempClassLoader(null);

   // Allow for caching all bean definition metadata, not expecting further changes.
   //禁止修改工厂配置
   beanFactory.freezeConfiguration();

   // Instantiate all remaining (non-lazy-init) singletons.
   //初始化非懒加载单例bean
   beanFactory.preInstantiateSingletons();
}
```

finishBeanFactoryInitialization主要是对beanFactory在bean初始化前进行了一系列特殊、前置bean的提前设置加载：提前设置类型转化接口、提前设置后置属性转化接口、提前织入一些前置功能。之后冻结beanFactory的配置开始初始化非懒加载bean。下面我们看下

beanFactory.preInstantiateSingletons();的逻辑：

```java
//DefaultListableBeanFactory#preInstantiateSingletons
//==============================================
public void preInstantiateSingletons() throws BeansException {
   if (logger.isTraceEnabled()) {
      logger.trace("Pre-instantiating singletons in " + this);
   }

   // Iterate over a copy to allow for init methods which in turn register new bean definitions.
   // While this may not be part of the regular factory bootstrap, it does otherwise work fine.
   //获取之间注册beanDefinition时注册的beanNames列表
   List<String> beanNames = new ArrayList<>(this.beanDefinitionNames);

   // Trigger initialization of all non-lazy singleton beans...
   //循环beanNames列表
   for (String beanName : beanNames) {
      //获取beanDefinition对象
      RootBeanDefinition bd = getMergedLocalBeanDefinition(beanName);
      //处理单例、非抽象、非懒加载的bean情况
      if (!bd.isAbstract() && bd.isSingleton() && !bd.isLazyInit()) {
         //该bean是否是通过FactoryBean创建的
         if (isFactoryBean(beanName)) {
            //处理FactoryBean创建bean的情况
            Object bean = getBean(FACTORY_BEAN_PREFIX + beanName);
            if (bean instanceof FactoryBean) {
               final FactoryBean<?> factory = (FactoryBean<?>) bean;
               boolean isEagerInit;
               if (System.getSecurityManager() != null && factory instanceof SmartFactoryBean) {
                  isEagerInit = AccessController.doPrivileged((PrivilegedAction<Boolean>)
                              ((SmartFactoryBean<?>) factory)::isEagerInit,
                        getAccessControlContext());
               }
               else {
                  isEagerInit = (factory instanceof SmartFactoryBean &&
                        ((SmartFactoryBean<?>) factory).isEagerInit());
               }
               if (isEagerInit) {
                  getBean(beanName);
               }
            }
         }
         else {
            //处理一般情况的bean加载
            getBean(beanName);
         }
      }
   }

   // Trigger post-initialization callback for all applicable beans...
   //触发加载完bean后的回调接口
   for (String beanName : beanNames) {
      Object singletonInstance = getSingleton(beanName);
      if (singletonInstance instanceof SmartInitializingSingleton) {
         final SmartInitializingSingleton smartSingleton = (SmartInitializingSingleton) singletonInstance;
         if (System.getSecurityManager() != null) {
            AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
               smartSingleton.afterSingletonsInstantiated();
               return null;
            }, getAccessControlContext());
         }
         else {
            smartSingleton.afterSingletonsInstantiated();
         }
      }
   }
}
```

preInstantiateSingletons()完成了对之前注册的beanDefinition列表对象的实例化过程：循环beanName列表，获取beanDefinition对象bd，根据bd判断对象是否是单例模式、非抽象、非懒加载bean，'否'则直接循环下一个bean；‘是’，则作进一步判断，判断bean是否属于FactoryBean，'否'则调用getBean(...)后循环下一个对象；‘是’则作进一步判断，判断是否属于SmartFactoryBean并设置isEagerInit属性，‘否’则循环下一个对象，‘是’则调用getBean(...)后进行下一次循环。由上述逻辑可以判断getBean(beanName)是根据beanName创建的对象，也是进一步分析的目标。循环流程图如下：

![image-20200603175922398](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103531.png)