spring是如何处理循环依赖？

### 一、学习spring对循环依赖的处理方式

#### 1. 什么是循环依赖

简单的说就是Bean之间出现了依赖的闭环问题，例如Bean A依赖于Bean B，而Bean B也依赖于Bean A。如果不进行处理，那么在Bean A和Bean B的创建过程中会出现对象创建死循环而无法正常的继续执行下一步的代码。逻辑示意图如下：

![image-20200606144805420](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102104632.png)

#### 2. 如何处理循环依赖

- ##### 核心思想: 

  使用缓存将Bean的首次创建和二次创建进行逻辑区分

- ##### 大概思路：

1. 创建一个全局缓存Cache，用于在首次实例化Bean时缓存创建的信息。
2. 在一个Bean实例化前先读取缓存Cache信息，若没有对象缓存就进行首次创建，否则就是二次创建直接返回缓存对象。
3. 当出现Bean之间的循环依赖时，一个Bean二次创建时会直接通过缓存Cache返回首次创建的对象，从而跳出循环创建的怪圈。

- ##### 从思路推断大概的代码逻辑：

1. 创建SimpleBean对象(@8897)，之后将其放入缓存中，再进行依赖FooBean对象的创建
2. 创建FooBean对象(@2546)，之后将其放入缓存中，再进行依赖SimpleBean对象的创建
3. 二次创建SimpleBean对象时直接从缓存中获取SimpleBean对象(@8897)，将对象(@8897)赋值到FooBean对象(@2546)中完成FooBean的创建
4. 回到SimpleBean对象依赖FooBean对象的过程中，将创建完成的FooBean对象(@2546)赋值到SimpleBean对象(@8897)中完成循环依赖

- ##### 代码演示

  net.plaz.bean.SimpleBean.java

  ```java
  public class SimpleBean {
  
     private FooBean fooBean;
  
     public SimpleBean(){
        System.out.println("SimpleBean构造");
     }
  
     public FooBean getFooBean() {
        return fooBean;
     }
  
     public void setFooBean(FooBean fooBean) {
        this.fooBean = fooBean;
     }
  }
  ```
  
  net.plaz.bean.FooBean.java
  
  ```java
  public class FooBean {

     private SimpleBean simpleBean;
  
     public FooBean(){
        System.out.println("FooBean构造");
     }
  
     public void setSimpleBean(SimpleBean simpleBean) {
        this.simpleBean = simpleBean;
     }
  
     public SimpleBean getSimpleBean() {
        return simpleBean;
     }
  }
  ```
  
  net.plaz.bean.SpringFactory.java
  
  
  ```java
  public class SpringFactory {
  
     //bean缓存(<'net.plaz.bean.FooBean', new FooBean()>)
     private Map<String, Object> earlySingletonCacheMap = new HashMap<String, Object> ();
  
     //使用needWiredMap模拟实例化对象的需要注入属性
     //<'net.plaz.bean.FooBean', 'net.plaz.bean.SimpleBean'>表示FooBean需要注入一个SimpleBean
     private Map<String, String> needWiredMap = new HashMap<String, String> ();
  
  
     public Object getBeanInstance(String className){
        //先从缓存中获取,若获取到，则直接返回
        Object obj = earlySingletonCacheMap.get(className);
        if(obj == null){
           //缓存中没有对象，则要新创建一个对象，并进行属性赋值
           try {
  
              Class<?> clazz = Class.forName(className);
              obj = clazz.newInstance();
              //将创建的对象加入缓存中
              earlySingletonCacheMap.put(className, obj);
              //之后进行属性赋值
              //获取要注入的val(递归创建对象)
              String propertyStr = needWiredMap.get(className);
              Object propertyObj = getBeanInstance(propertyStr);
              //key
              String propertyKey = getPropertyName(propertyStr);
              //将val通过set方法对po的属性赋值
              PropertyDescriptor propertyDescriptor = new PropertyDescriptor(propertyKey, obj.getClass());
              propertyDescriptor.getWriteMethod().invoke(obj, propertyObj);
  
           } catch (ClassNotFoundException e) {
              e.printStackTrace();
           } catch (IllegalAccessException e) {
              e.printStackTrace();
           } catch (InstantiationException e) {
              e.printStackTrace();
           } catch (IntrospectionException e) {
              e.printStackTrace();
           } catch (InvocationTargetException e) {
              e.printStackTrace();
           }
        }
  
        return obj;
     }
  
     /**
      * 功能描述: 获取属性名称
      * <br>
      * @Param: [className]
      * @Return: java.lang.String
      * @Author: pwb
      * @Date: 2020/6/6
      */
     private String getPropertyName(String className){
        String[] strArr = className.split("\\.");
        String prop = strArr[strArr.length -1];
        char[] chars = prop.toCharArray();
        chars[0] += 32;
        return String.valueOf(chars);
     }
  
     //下面是set/get方法
     public Map<String, Object> getEarlySingletonCacheMap() {
        return earlySingletonCacheMap;
     }
  
     public void setEarlySingletonCacheMap(Map<String, Object> earlysingletonCacheMap) {
        this.earlySingletonCacheMap = earlysingletonCacheMap;
     }
  
  
     public Map<String, String> getNeedWiredMap() {
        return needWiredMap;
     }
  
     public void setNeedWiredMap(Map<String, String> needWiredMap) {
        this.needWiredMap = needWiredMap;
     }
  }
  ```
  
  代码调用
  
  ```java
  public static void main(String[] args) {
     //要注入的属性(模拟bean依赖关系)
     //<'net.plaz.bean.FooBean', 'net.plaz.bean.SimpleBean'>表示FooBean需要注入一个SimpleBean
     Map<String, String> needWiredMap = new HashMap<String, String> ();
     needWiredMap.put("net.plaz.bean.SimpleBean", "net.plaz.bean.FooBean");
     needWiredMap.put("net.plaz.bean.FooBean", "net.plaz.bean.SimpleBean");
  
     //创建bean工厂
     SpringFactory factory = new SpringFactory();
     //设置bean关系
     factory.getNeedWiredMap().putAll(needWiredMap);
  
     //模拟要实例化的列表
     List<String> beanList = new ArrayList<>();
     beanList.add("net.plaz.bean.SimpleBean");
     beanList.add("net.plaz.bean.FooBean");
  
     List<Object> result = new ArrayList<> ();
     for(String bean : beanList){
        result.add(factory.getBeanInstance(bean));
     }
     System.out.println(result);
  }
  
  //执行结果
  //成功的处理了循环依赖(●'◡'●)
  SimpleBean构造
  FooBean构造
  [net.plaz.bean.SimpleBean@2344fc66, net.plaz.bean.FooBean@458ad742]
  ```

代码执行逻辑如下：

1. 先创建simpleBean空对象，将对象放入未实例化完成的缓存中便于其他对象调用

2. 之后对其依赖对象FooBean进行实例化，同样将FooBean空对象放入未实例化完成的缓存中

3. 在FooBean实例化中进行填充对象属性时，又要创建simpleBean对象；此时simpleBean处于创建中的bean列表中，同时在未实例化完成的缓存中已经有一个simpleBean对象，所以直接将步骤1创建的simpleBean对象引用赋值到FooBean对象的属性中

4. 在FooBean创建完成后回到步骤2，将创建完成的FooBean对象引用赋值给simpleBean对象完成实例化

#### 3. spring如何处理循环依赖

在spring DI过程中，对于循环依赖的处理方式和上述处理基本相同(上述处理属于spring的简化版)。下面来扒下spring的源码学习下大致的流程：

1.我们通常使用`getBean(java.lang.Class<T>)`从IOC中获取bean信息，实际上在IOC容器通过扫描包或加载XML后也会循环调用`getBean(...)`进行Bean的首轮实例化(有兴趣详见`DefaultListableBeanFactory#preInstantiateSingletons()`)。下面来详细了解下`getBean(...)`中对于循环依赖的处理。

```java
//org.springframework.beans.factory.support.AbstractBeanFactory#doGetBean
//doGetBean是getBean方法的实际逻辑方法,这里只贴出了相关的部分代码
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
   }

   else {
	  //省略...

      try {
         //获取beanName对应的BeanDefinition
         final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
		//省略...
          
         // Create bean instance.
         //根据bean的作用域来创建bean实例
         if (mbd.isSingleton()) {
            //创建单例模式的bean
            sharedInstance = getSingleton(beanName, () -> {
               try {
                   //单例的bean实例化方法
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
            //创建原型模式bean
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
             //创建其他模式bean
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

   //省略...
   return (T) bean;
}
```

上述`doGetBean`大致做了几个步骤：

1. 尝试根据beanName从缓存中获取获取bean对象
2. 若获取到缓存对象则执行`getObjectForBeanInstance(...)`后返回bean信息
3. 若没有获取到缓存对象(首次创建)，则根据bean的作用域类型来采取不同方式创建bean(这里默认为单例模式)，然后再执行`getObjectForBeanInstance(...)`后返回bean信息

其中涉及到循环依赖的处理有`getSingleton(beanName)`先获取缓存对象：

```java
//DefaultSingletonBeanRegistry#getSingleton(java.lang.String, boolean)
@Nullable
protected Object getSingleton(String beanName, boolean allowEarlyReference) {
    //从singletonObjects(存储已完成实例化的单例对象)缓存中获取
   Object singletonObject = this.singletonObjects.get(beanName);
    //没有获取到bean，判断当前beanName对象是否在创建中
   if (singletonObject == null && isSingletonCurrentlyInCreation(beanName)) {
      synchronized (this.singletonObjects) {
         //从earlySingletonObjects(存储刚实例化的单例对象)缓存中获取==>循环依赖的一种缓存对象
         singletonObject = this.earlySingletonObjects.get(beanName);
         //没有获取到bean，判断是否允许提前引用其他bean
         if (singletonObject == null && allowEarlyReference) {
             //从singletonFactories缓存中获取==>循环依赖的一种缓存对象
             //获取到的对象是一个函数式接口对象，能直接获取到beanName首次创建的对象
            ObjectFactory<?> singletonFactory = this.singletonFactories.get(beanName);
            if (singletonFactory != null) {
                //singletonFactories有，earlySingletonObjects没有，则将对象从singletonFactories挪到earlySingletonObjects
               singletonObject = singletonFactory.getObject();
               this.earlySingletonObjects.put(beanName, singletonObject);
               this.singletonFactories.remove(beanName);
            }
         }
      }
   }
   return singletonObject;
}
```

2.这里我们的bean按照单例模式，走首次创建路径`createBean(beanName, mbd, args);`，而`createBean(beanName, mbd, args);`中真正的逻辑方法是`doCreateBean(...)`，下面我们看下`doCreateBean(...)`的方法：

```java
protected Object doCreateBean(final String beanName, final RootBeanDefinition mbd, final @Nullable Object[] args)
      throws BeanCreationException {

   // Instantiate the bean.
   BeanWrapper instanceWrapper = null;
   if (mbd.isSingleton()) {
      //根据beanName将当前对象从未完成实例化列表缓存中移除并返回
      instanceWrapper = this.factoryBeanInstanceCache.remove(beanName);
   }
   //若未完成实例化列表缓存中没有数据则创建一个空对象
   if (instanceWrapper == null) {
      instanceWrapper = createBeanInstance(beanName, mbd, args);
   }
   final Object bean = instanceWrapper.getWrappedInstance();
   //省略...

   // Eagerly cache singletons to be able to resolve circular references
   // even when triggered by lifecycle interfaces like BeanFactoryAware.
   //将bean写入提前暴露的缓存中(此时的bean刚实例化，还没有对其属性进行赋值处理)
   boolean earlySingletonExposure = (mbd.isSingleton() && this.allowCircularReferences &&
         isSingletonCurrentlyInCreation(beanName));
   if (earlySingletonExposure) {
      if (logger.isTraceEnabled()) {
         logger.trace("Eagerly caching bean '" + beanName +
               "' to allow for resolving potential circular references");
      }
      addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
   }

   // Initialize the bean instance.
   Object exposedObject = bean;
   try {
      //将beandefinition中的属性写入对应的instanceWrapper对象实例中
      //依赖循环就是在这里处理的 
      populateBean(beanName, mbd, instanceWrapper);
      //如果exposedObject对象有实现一些aware、init接口则初始化这些接口
      exposedObject = initializeBean(beanName, exposedObject, mbd);
   }
   catch (Throwable ex) {
      if (ex instanceof BeanCreationException && beanName.equals(((BeanCreationException) ex).getBeanName())) {
         throw (BeanCreationException) ex;
      }
      else {
         throw new BeanCreationException(
               mbd.getResourceDescription(), beanName, "Initialization of bean failed", ex);
      }
   }
   //省略...

   return exposedObject;
}
```

`doCreateBean(...)`的主要逻辑有以下几步：

1. 创建一个bean的包装对象instanceWrapper(实际为Class.forName(className).newInstance()创建,有兴趣自行可跟踪代码)
2. 通过`addSingletonFactory(...)`将刚实例化的对象放入缓存中
3. 在`populateBean(...)`中处理bean对象的依赖属性(在这里递归调用其他依赖的bean)
4. 在`initializeBean(...)`中调用对象的一些初始化接口(如实现InitializingBean)，并返回结果bean

涉及循环依赖的处理有`addSingletonFactory(...)`和`populateBean(...)`两部分，我们先看下`addSingletonFactory(...)`将bean加入缓存中：

```java
//org.springframework.beans.factory.support.DefaultSingletonBeanRegistry#addSingletonFactory
protected void addSingletonFactory(String beanName, ObjectFactory<?> singletonFactory) {
   Assert.notNull(singletonFactory, "Singleton factory must not be null");
   synchronized (this.singletonObjects) {
      //没有创建过beanName的bean则加入缓存
      if (!this.singletonObjects.containsKey(beanName)) {
         //存储在singletonFactories中，在getSingleton(...)中获取调用
         this.singletonFactories.put(beanName, singletonFactory);
         this.earlySingletonObjects.remove(beanName);
         this.registeredSingletons.add(beanName);
      }
   }
}

//参数ObjectFactory<?> singletonFactory是一个函数式接口对象
//内容为() -> getEarlyBeanReference(beanName, mbd, bean)
//调用singletonFactory会执行getEarlyBeanReference(beanName, mbd, bean)，返回bean的首次创建对象
//实际上会在获取缓存对象的getSingleton(...)中调用 singletonFactory.getObject();
protected Object getEarlyBeanReference(String beanName, RootBeanDefinition mbd, Object bean) {
	Object exposedObject = bean;
	//忽略...
	return exposedObject;
}
```

3.而`populateBean(...)`是根据BeanDefinition将属性赋值到刚创建的对象中，主要的逻辑在`applyPropertyValues(...)`中执行，大致代码如下：

```java
//org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory#applyPropertyValues
protected void applyPropertyValues(String beanName, BeanDefinition mbd, BeanWrapper bw, PropertyValues pvs) {
   //省略...
    //创建属性解析器(主要完成属性值的处理，包括依赖其他bean的创建)
   BeanDefinitionValueResolver valueResolver = new BeanDefinitionValueResolver(this, beanName, mbd, converter);

   // Create a deep copy, resolving any references for values.
   List<PropertyValue> deepCopy = new ArrayList<>(original.size());
   boolean resolveNecessary = false;
   for (PropertyValue pv : original) {
      if (pv.isConverted()) {
         deepCopy.add(pv);
      }
      else {
		 //获取属性名称
		 String propertyName = pv.getName();
		 Object originalValue = pv.getValue();
		 //使用解析器解析不同类型的值
		 Object resolvedValue = valueResolver.resolveValueIfNecessary(pv, originalValue);
          //将值包装到deepCopy的list中
         Object convertedValue = resolvedValue;
         boolean convertible = bw.isWritableProperty(propertyName) &&
               !PropertyAccessorUtils.isNestedOrIndexedProperty(propertyName);
         if (convertible) {
            convertedValue = convertForProperty(resolvedValue, propertyName, bw, converter);
         }
         // Possibly store converted value in merged bean definition,
         // in order to avoid re-conversion for every created bean instance.
         if (resolvedValue == originalValue) {
            if (convertible) {
               pv.setConvertedValue(convertedValue);
            }
            deepCopy.add(pv);
         }
         else if (convertible && originalValue instanceof TypedStringValue &&
               !((TypedStringValue) originalValue).isDynamic() &&
               !(convertedValue instanceof Collection || ObjectUtils.isArray(convertedValue))) {
            pv.setConvertedValue(convertedValue);
            deepCopy.add(pv);
         }
         else {
            resolveNecessary = true;
            deepCopy.add(new PropertyValue(pv, convertedValue));
         }
      }
   }
   if (mpvs != null && !resolveNecessary) {
      mpvs.setConverted();
   }

   // Set our (possibly massaged) deep copy.
   try {
       //将属性赋值到对象中
      bw.setPropertyValues(new MutablePropertyValues(deepCopy));
   }
   catch (BeansException ex) {
      throw new BeanCreationException(
            mbd.getResourceDescription(), beanName, "Error setting property values", ex);
   }
}
```

主要逻辑是如下：

1. 创建属性解析器valueResolver， 之后循环BeanDefinition中的属性列表，使用解析器对每个property进行实际值的解析(保存创建依赖bean对象)
2. 根据属性的名称将属性值赋值到对象中

4.涉及到循环依赖的逻辑是`valueResolver.resolveValueIfNecessary(pv, originalValue)`,使用属性解析器获取property的实际内容，下面我们看下如何解析property的(只看依赖其他bean的property)：

```java
//org.springframework.beans.factory.support.BeanDefinitionValueResolver#resolveValueIfNecessary
@Nullable
public Object resolveValueIfNecessary(Object argName, @Nullable Object value) {
   // We must check each value to see whether it requires a runtime reference
   // to another bean to be resolved.
    //处理依赖其他bean的property
   if (value instanceof RuntimeBeanReference) {
      RuntimeBeanReference ref = (RuntimeBeanReference) value;
      return resolveReference(argName, ref);
   }
    //省略...
}

//详细处理逻辑
@Nullable
private Object resolveReference(Object argName, RuntimeBeanReference ref) {
	try {
		Object bean;
        //获取依赖bean名称
		String refName = ref.getBeanName();
		refName = String.valueOf(doEvaluate(refName));
        //依赖是否属于父容器
		if (ref.isToParent()) {
			if (this.beanFactory.getParentBeanFactory() == null) {
				throw new BeanCreationException(
						this.beanDefinition.getResourceDescription(), this.beanName,
						"Can't resolve reference to bean '" + refName +
								"' in parent factory: no parent factory available");
			}
			bean = this.beanFactory.getParentBeanFactory().getBean(refName);
		}
		else {
            //嵌套调用IOC容器的getBean方法
			bean = this.beanFactory.getBean(refName);
			this.beanFactory.registerDependentBean(refName, this.beanName);
		}
		if (bean instanceof NullBean) {
			bean = null;
		}
		return bean;
	}
	catch (BeansException ex) {
		throw new BeanCreationException(
				this.beanDefinition.getResourceDescription(), this.beanName,
				"Cannot resolve reference to bean '" + ref.getBeanName() + "' while setting " + argName, ex);
	}
}
```

上述逻辑比较清晰简单，就是根据依赖的beanName嵌套调用`this.beanFactory.getBean(refName)`去创建所依赖对象，创建完成后返回该bean信息。

- ##### 总结：

   到这里我们就可以大致的明白spring是如何处理依赖循环的了：

1. 调用`getBean(...)`方法创建一个bean，前先从缓存`getSingleton(...)`中获取对象信息
2. 若是没有缓存，则首次创建后将其对象加入到缓存中
3. 之后对创建的对象进行属性填充`populateBean(...)`，填充过程中创建属性解析器对bean的属性进行处理
4. 若属性类型依赖其他的bean，则会嵌套调用IOC容器的getBean方法去创建所依赖的bean对象，直到出现从缓存中获取到对象后跳出嵌套逻辑，才可以完成整个bean的属性赋值过程。

#### 4. spring中循环依赖的的一些思考

上述所spring处理的循环依赖有两个关键点：

1. 创建的bean是单例模式的，

2. 是通过属性的set方法对其依赖bean进行赋值的。

所以思考以下几个问题：

1. Q：若bean类型是原型模式(prototye)是否可适用这样的循环依赖处理方式？

   S：不可以，原型模式每次创建的bean都是新对象，无法保证对象统一，spring也不会缓存原型模式的bean

2. Q：处理循环依赖中，是否可以通过构造方法进行依赖注入？

   S：不可以，set方法是在对象创建后进行的，而构造方法是在对象创建中执行的，此时beanA是没有缓存信息的，只能在创建之前就获取到依赖的beanB对象，而依赖的beanB再次嵌套创建beanA时，由于beanA处于创建中的状态，就会报错。

3. Q：除了通过set方法进行依赖注入外，还可以通过其他方法完成依赖注入吗？

   S：只要是在对象创建之后进行bean赋值基本都可实现，下面介绍几种：

   - 使用@Autowired和@PostConstruct在初始化方法中进行赋值

   - 实现ApplicationContextAware和InitializingBean接口在afterPropertiesSet()方法中调用getBean()赋值
   - 使用@Lazy注解，先注入代理对象，在后面首次使用时完成赋值