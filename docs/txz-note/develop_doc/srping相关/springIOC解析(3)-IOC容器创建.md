springIOC解析(3)-IOC容器创建

### 一、创建容器

obtainFreshBeanFactory()的逻辑为刷新并返回BeanFactory对象，实际代码在父类AbstractApplicationContext中，代码如下：

```java
//AbstractApplicationContext
//-------------------
protected ConfigurableListableBeanFactory obtainFreshBeanFactory() {
   //refreshBeanFactory为抽象方法，实际由其子类实现
   refreshBeanFactory();
   //getBeanFactory方法返回当前对象的beanFactory属性
   return getBeanFactory();
}
```

refreshBeanFactory()使用了模板模式，AbstractApplicationContext中只定义了抽象方法，实际实现在子类AbstractRefreshableApplicationContext中，代码如下：

```java
//AbstractRefreshableApplicationContext
//-------------
@Override
protected final void refreshBeanFactory() throws BeansException {
   //this.beanFactory是否为空
   if (hasBeanFactory()) {
      //为空先销毁bean，重置beanFactory
      destroyBeans();
      closeBeanFactory();
   }
   try {
      //新建IOC容器
      DefaultListableBeanFactory beanFactory = createBeanFactory();
      //容器设置序列化id
      beanFactory.setSerializationId(getId());
      //容器定制化（设置启动参数、开启其他配置等等）
      customizeBeanFactory(beanFactory);
      //载入Bena定义(同为抽象方法，实际为子类实现)
      loadBeanDefinitions(beanFactory);
      synchronized (this.beanFactoryMonitor) {
         this.beanFactory = beanFactory;
      }
   }
   catch (IOException ex) {
      throw new ApplicationContextException("I/O error parsing bean definition source for " + getDisplayName(), ex);
   }
}
```

refreshBeanFactory()的主要逻辑为，创建一个IOC容器(创建前判空，不为空要进行重置)，进行定制化参数设置，之后进行bean信息的载入(实际上就是将外部的bean信息封装为一个IOC可读取的信息对象，存储在一个Map序列中)。

### 二、加载配置信息

loadBeanDefinitions(beanFactory)由其子类AbstractXmlApplicationContext实现，代码如下：

```java
//AbstractXmlApplicationContext#loadBeanDefinitions
//-------------------
@Override
protected void loadBeanDefinitions(DefaultListableBeanFactory beanFactory) throws BeansException, IOException {
   // Create a new XmlBeanDefinitionReader for the given BeanFactory.
   //给IOC容器创建一个XML Bean配置读取器
   XmlBeanDefinitionReader beanDefinitionReader = new XmlBeanDefinitionReader(beanFactory);

   // Configure the bean definition reader with this context's
   // resource loading environment.
   //将当前对象作为资源加载器参数(当前类的继承序列中有继承DefaultResourceLoader的)设置给Bean读取器
   beanDefinitionReader.setEnvironment(this.getEnvironment());
   beanDefinitionReader.setResourceLoader(this);
   //设置xml资源解析器
   beanDefinitionReader.setEntityResolver(new ResourceEntityResolver(this));

   // Allow a subclass to provide custom initialization of the reader,
   // then proceed with actually loading the bean definitions.
   //开启xml校验
   initBeanDefinitionReader(beanDefinitionReader);
   //使用读取器进行资源读取
   loadBeanDefinitions(beanDefinitionReader);
}

protected void initBeanDefinitionReader(XmlBeanDefinitionReader reader) {
	reader.setValidating(this.validating);
}

protected void loadBeanDefinitions(XmlBeanDefinitionReader reader) throws BeansException, IOException {
	//获取设置的资源路径信息，详情见
	//实际调用ClassPathXmlApplicationContext#getConfigResources，
    //获取构造方法setConfigLocations(configLocations)的值
	//这里为null
	Resource[] configResources = getConfigResources();
	if (configResources != null) {
		//读取配置路径的bean信息
		reader.loadBeanDefinitions(configResources);
	}
	//实际调用AbstractRefreshableConfigApplicationContext#getConfigLocations，获取之前配置文件信息(ClassPathXmlApplicationContext构造方法setConfigLocations(configLocations);)
	String[] configLocations = getConfigLocations();
	if (configLocations != null) {
		//读取配置路径的bean信息
		reader.loadBeanDefinitions(configLocations);
	}
}

```

loadBeanDefinitions(beanFactory)的主要逻辑为，创建一个IOC容器的Bean信息读取器，然后给读取器配置一些参数限定，最后获取一开始设置的资源路径给读取器进行资源读取。

这里要注意下beanDefinitionReader.setResourceLoader(this);这里将ClassPathXmlApplicationContext作为一个资源加载对象参数放入Bean读取器中，因为在ClassPathXmlApplicationContext的继承链中有父类实现了ResourceLoader接口，所以ClassPathXmlApplicationContext是有多个特性的，不仅是一个BeanFactory，同时也可以是一个ResourceLoader；下图为资源加载的继承链。

![image-20200510144853684](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103442.png)