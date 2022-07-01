springIOC解析(10)-根据bean定义对象实例化bean

### 一、getBean(...)解析

对于`getBean(...)`我们就比较熟悉了，是的！这就是我们从IOC容器中获取bean的常用方法。代码如下：

```java
//org.springframework.beans.factory.support.AbstractBeanFactory#doGetBean
@Override
public Object getBean(String name) throws BeansException {
   return doGetBean(name, null, null, false);
}

@Override
public <T> T getBean(String name, Class<T> requiredType) throws BeansException {
   return doGetBean(name, requiredType, null, false);
}

@Override
public Object getBean(String name, Object... args) throws BeansException {
   return doGetBean(name, null, args, false);
}
//.....
```

这些`getBean(...)`的重载方法都调用了`doGetBean(...)`，这就是创建bean实例的主要逻辑方法了。

#### 1. doGetBean(...)逻辑简析

```java
//org.springframework.beans.factory.support.AbstractBeanFactory#doGetBean
protected <T> T doGetBean(final String name, @Nullable final Class<T> requiredType,
      @Nullable final Object[] args, boolean typeCheckOnly) throws BeansException {
   //处理bean名称的规范问题
   final String beanName = transformedBeanName(name);
   Object bean;

   // Eagerly check singleton cache for manually registered singletons.
   //从缓存中获取bean实例
   Object sharedInstance = getSingleton(beanName);
   if (sharedInstance != null && args == null) {
      if (logger.isTraceEnabled()) {
         if (isSingletonCurrentlyInCreation(beanName)) {
            logger.trace("Returning eagerly cached instance of singleton bean '" + beanName +
                  "' that is not fully initialized yet - a consequence of a circular reference");
         }
         else {
            logger.trace("Returning cached instance of singleton bean '" + beanName + "'");
         }
      }
      bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
   }else {
      // Fail if we're already creating this bean instance:
      // We're assumably within a circular reference.
      //判断是否循环引用
      if (isPrototypeCurrentlyInCreation(beanName)) {
         throw new BeanCurrentlyInCreationException(beanName);
      }

      // Check if bean definition exists in this factory.
      //先判断beanName是否在父容器中
      BeanFactory parentBeanFactory = getParentBeanFactory();
      if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
         // Not found -> check parent.
          //在父容器中进行bean实例化
         String nameToLookup = originalBeanName(name);
         if (parentBeanFactory instanceof AbstractBeanFactory) {
            return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
                  nameToLookup, requiredType, args, typeCheckOnly);
         }
         else if (args != null) {
            // Delegation to parent with explicit args.
            return (T) parentBeanFactory.getBean(nameToLookup, args);
         }
         else if (requiredType != null) {
            // No args -> delegate to standard getBean method.
            return parentBeanFactory.getBean(nameToLookup, requiredType);
         }
         else {
            return (T) parentBeanFactory.getBean(nameToLookup);
         }
      }
      //是否进行类型检查
      if (!typeCheckOnly) {
         //将beanName标记为已创建bean
         markBeanAsCreated(beanName);
      }

      try {
         //获取beanName对应的BeanDefinition
         final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
         checkMergedBeanDefinition(mbd, beanName, args);

         // Guarantee initialization of beans that the current bean depends on.
         //根据BeanDefinition的depend-on属性判断是否依赖于其他bean
         String[] dependsOn = mbd.getDependsOn();
         if (dependsOn != null) {
            //存在bean依赖则先对依赖bean进行处理
            for (String dep : dependsOn) {
               //判断是否是引用的自身对象
               if (isDependent(beanName, dep)) {
                  throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                        "Circular depends-on relationship between '" + beanName + "' and '" + dep + "'");
               }
               //对依赖的bean进行注册
               registerDependentBean(dep, beanName);
               try {
                  //创建依赖bean实例
                  getBean(dep);
               }
               catch (NoSuchBeanDefinitionException ex) {
                  throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                        "'" + beanName + "' depends on missing bean '" + dep + "'", ex);
               }
            }
         }

         // Create bean instance.
         //根据bean的作用域来创建bean实例
         if (mbd.isSingleton()) {
            //创建单例模式的bean
            sharedInstance = getSingleton(beanName, () -> {
               try {
                  return createBean(beanName, mbd, args);
               }
               catch (BeansException ex) {
                  // Explicitly remove instance from singleton cache: It might have been put there
                  // eagerly by the creation process, to allow for circular reference resolution.
                  // Also remove any beans that received a temporary reference to the bean.
                  destroySingleton(beanName);
                  throw ex;
               }
            });
            bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
         }

         else if (mbd.isPrototype()) {
            // It's a prototype -> create a new instance.
            Object prototypeInstance = null;
            try {
               beforePrototypeCreation(beanName);
               prototypeInstance = createBean(beanName, mbd, args);
            }
            finally {
               afterPrototypeCreation(beanName);
            }
            bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
         }else {
            String scopeName = mbd.getScope();
            final Scope scope = this.scopes.get(scopeName);
            if (scope == null) {
               throw new IllegalStateException("No Scope registered for scope name '" + scopeName + "'");
            }
            try {
               Object scopedInstance = scope.get(beanName, () -> {
                  beforePrototypeCreation(beanName);
                  try {
                     return createBean(beanName, mbd, args);
                  }
                  finally {
                     afterPrototypeCreation(beanName);
                  }
               });
               bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
            }
            catch (IllegalStateException ex) {
               throw new BeanCreationException(beanName,
                     "Scope '" + scopeName + "' is not active for the current thread; consider " +
                     "defining a scoped proxy for this bean if you intend to refer to it from a singleton",
                     ex);
            }
         }
      }
      catch (BeansException ex) {
         cleanupAfterBeanCreationFailure(beanName);
         throw ex;
      }
   }

   // Check if required type matches the type of the actual bean instance.
   //是否需要进行类型转换
   if (requiredType != null && !requiredType.isInstance(bean)) {
      try {
         T convertedBean = getTypeConverter().convertIfNecessary(bean, requiredType);
         if (convertedBean == null) {
            throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
         }
         return convertedBean;
      }
      catch (TypeMismatchException ex) {
         if (logger.isTraceEnabled()) {
            logger.trace("Failed to convert bean '" + name + "' to required type '" +
                  ClassUtils.getQualifiedName(requiredType) + "'", ex);
         }
         throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
      }
   }
   return (T) bean;
}
```

`doGetBean(...)`的逻辑主要有以下几步：

1. 尝试从缓存(`getSingleton`)中获取bean对象，若获取到对象，则执行`getObjectForBeanInstance`后返回bean对象
2. 若没有缓存对象，则进行首次实例化过程，根据bean的作用域类型来区分创建的方式
3. 若bean为单例模式(singleton)或原型模式(prototype),则通过`createBean(beanName, mbd, args)`创建bean对象，然后执行`getObjectForBeanInstance`后返回bean对象
4. 若bean为为其他作用域模式，则通过不同的Scope对象调用`createBean(beanName, mbd, args)`来创建对象，之后执行`getObjectForBeanInstance`后返回bean对象

不难看出，`doGetBean(...)`的两个关键方法：`getObjectForBeanInstance`和`createBean(beanName, mbd, args)`。其中`createBean`是bean实例化的方法，`getObjectForBeanInstance`是根据bean类型返回不同的bean对象方法(返回FactoryBean对象或者原对象返回)。

#### 2.getObjectForBeanInstance(...)逻辑简析

```java
//AbstractBeanFactory#getObjectForBeanInstance
protected Object getObjectForBeanInstance(
      Object beanInstance, String name, String beanName, @Nullable RootBeanDefinition mbd) {

   // Don't let calling code try to dereference the factory if the bean isn't a factory.
   //根据bean名称判断是否是以&开头
   if (BeanFactoryUtils.isFactoryDereference(name)) {
      if (beanInstance instanceof NullBean) {
         return beanInstance;
      }
      if (!(beanInstance instanceof FactoryBean)) {
         throw new BeanIsNotAFactoryException(beanName, beanInstance.getClass());
      }
   }

   // Now we have the bean instance, which may be a normal bean or a FactoryBean.
   // If it's a FactoryBean, we use it to create a bean instance, unless the
   // caller actually wants a reference to the factory.
   //如果bean实例不属于FactoryBean，或者bean名称以&开头就直接返回
   //一般是两种返回情况：1.bean实例没实现FactoryBean接口 2.bean实例实现了FactoryBean接口，但是以&开头
   if (!(beanInstance instanceof FactoryBean) || BeanFactoryUtils.isFactoryDereference(name)) {
      return beanInstance;
   }
   //处理bean实例实现了FactoryBean接口，name不为&开头的情况
   Object object = null;
   if (mbd == null) {
      //bean定义对象为空时，从缓存中获取实例
      object = getCachedObjectForFactoryBean(beanName);
   }
   if (object == null) {
      //将beanInstance转为工厂bean，并通过这个工厂bean创建返回对象
      // Return bean instance from factory.
      FactoryBean<?> factory = (FactoryBean<?>) beanInstance;
      // Caches object obtained from FactoryBean if it is a singleton.
      if (mbd == null && containsBeanDefinition(beanName)) {
         mbd = getMergedLocalBeanDefinition(beanName);
      }
      boolean synthetic = (mbd != null && mbd.isSynthetic());
      object = getObjectFromFactoryBean(factory, beanName, !synthetic);
   }
   return object;
}
```

getObjectForBeanInstance(...)主要逻辑是区分普通bean和FactoryBean：

1. 非FactoryBean的bean不做处理，直接返回

2. 是FactoryBean且beanName以&开头的bean不做处理，直接返回

（所以对于FactoryBean可以通过加&获取FactoryBean本身的对象）

3. 是FactoryBean且beanName不以&开头的bean进行FactoryBean处理返回一个FactoryBean.getObject()对象

   

#### 3. createBean(...)逻辑简析

```JAVA
//AbstractAutowireCapableBeanFactory#createBean(...)
@Override
protected Object createBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args)
      throws BeanCreationException {

   if (logger.isTraceEnabled()) {
      logger.trace("Creating instance of bean '" + beanName + "'");
   }
   RootBeanDefinition mbdToUse = mbd;

   // Make sure bean class is actually resolved at this point, and
   // clone the bean definition in case of a dynamically resolved Class
   // which cannot be stored in the shared merged bean definition.
   //通过class类路径获取bean的class对象(Class.forName(...))
   Class<?> resolvedClass = resolveBeanClass(mbd, beanName);
   if (resolvedClass != null && !mbd.hasBeanClass() && mbd.getBeanClassName() != null) {
      mbdToUse = new RootBeanDefinition(mbd);
      mbdToUse.setBeanClass(resolvedClass);
   }

   // Prepare method overrides.
   //处理方法的重写
   try {
      mbdToUse.prepareMethodOverrides();
   }
   catch (BeanDefinitionValidationException ex) {
      throw new BeanDefinitionStoreException(mbdToUse.getResourceDescription(),
            beanName, "Validation of method overrides failed", ex);
   }

   try {
      // Give BeanPostProcessors a chance to return a proxy instead of the target bean instance.
      //是否有前后处理器需要返回一个代理对象
      Object bean = resolveBeforeInstantiation(beanName, mbdToUse);
      if (bean != null) {
         return bean;
      }
   }
   catch (Throwable ex) {
      throw new BeanCreationException(mbdToUse.getResourceDescription(), beanName,
            "BeanPostProcessor before instantiation of bean failed", ex);
   }

   try {
      //创建bean实例
      Object beanInstance = doCreateBean(beanName, mbdToUse, args);
      if (logger.isTraceEnabled()) {
         logger.trace("Finished creating instance of bean '" + beanName + "'");
      }
      return beanInstance;
   }
   catch (BeanCreationException | ImplicitlyAppearedSingletonException ex) {
      // A previously detected exception with proper bean creation context already,
      // or illegal singleton state to be communicated up to DefaultSingletonBeanRegistry.
      throw ex;
   }
   catch (Throwable ex) {
      throw new BeanCreationException(
            mbdToUse.getResourceDescription(), beanName, "Unexpected exception during bean creation", ex);
   }
}
```

1. 获取bean的class对象，赋值到dean定义对象中
2. 预处理bean的重写方法
3. 是否有像后置接口，需要返回一个代理对象
4. 执行`doCreateBean`获取bean实例化对象

![image-20200609114105324](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103542.png)