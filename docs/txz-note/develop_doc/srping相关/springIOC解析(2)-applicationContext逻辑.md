springIOC解析(2)-applicationContext逻辑

### 一、了解ClassPathXmlApplicationContext类结构

在源码跟踪前，我们要做一下准备工作，大概了解一下研究对象类的继承关系，这对于梳理代码走向非常重要，ClassPathXmlApplicationContext类主要继承关系如下图所示。

![image-20200503203222955](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103401.png)

### 二、了解IOC容器创建的步骤

我们通过启动SpringTestHander的main()方法加载ClassPathXmlApplicationContext来正式开始IOC的解读：

![image-20200503204058778](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103407.png)

跟随断点进入其构造方法：

![image-20200503204030479](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103410.png)

找到实际调用的构造方法如下:

![image-20200503204553623](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103413.png)

这里一共有三步操作：

1. super(parent)，调用父类中的带ApplicationContext参数的构造方法

2. setConfigLocations(configLocations)，设置当前配置文件位置
3. refresh()，执行刷新操作->容器刷新，实际上很多其他的启动方法最终调用的都是他

### 三、资源配置准备

我们继续跟进代码的走向，找到super(parent)的实际业务父类为AbstractApplicationContext，根据之前的类继承图可以知道这是ClassPathXmlApplicationContext的第五级父类，其构造方法如下：

![image-20200503210350149](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103418.png)

只有两步操作：

1. this()，创建一个资源解析器

2. setParent(parent)， 如果父对象不为空则赋值到parent属性中，这里parent参数为null可以忽视

我们发现当前类ClassPathXmlApplicationContext被作为参数创建了PathMatchingResourcePatternResolver资源解析对象（因为AbstractApplicationContext继承了DefaultResourceLoader，所以也是一个资源加载器）。

![image-20200503211007322](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103423.png)

在设置完资源加载器后，接下来执行setConfigLocations(configLocations)操作,其实际调用位置为第三级父类AbstractRefreshableConfigApplicationContext的方法，代码如下：

![image-20200503213626527](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103431.png)

从其逻辑上不难看出，我们可以配置多个配置文件路径。

总结，这两步主要逻辑是创建了资源解析器对象，之后又定位了资源文件的路径数组。

### 四、资源载入

Bean资源的载入主要是在refresh()中进行的，其源码如下：

```java
	@Override
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
				//调用工厂处理器注册为bean中（调用注册过BeanPostProcessors的bean）
				invokeBeanFactoryPostProcessors(beanFactory);

				// Register bean processors that intercept bean creation.
				//注册bean处理器拦截bean创建。
				registerBeanPostProcessors(beanFactory);

				// Initialize message source for this context.
				//初始化消息来源
				initMessageSource();

				// Initialize event multicaster for this context.
				//初始化事件多播。
				initApplicationEventMulticaster();

				// Initialize other special beans in specific context subclasses.
				//在特定上下文初始化其他特殊bean子类。
				onRefresh();

				// Check for listener beans and register them.
				//检查侦听器bean并注册。
				registerListeners();

				// Instantiate all remaining (non-lazy-init) singletons.
				//实例化所有剩余(non-lazy-init)单件。
				finishBeanFactoryInitialization(beanFactory);

				// Last step: publish corresponding event.
				//最后一步:发布对应的事件。(发布生命周期事件)
				finishRefresh();
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

先大概了解下refresh()方法的整个工作流程，主要逻辑为：在IOC容器创建前，检查是否已经存在容器，若存在则销毁，确保Ioc容器的唯一，之后对容器进行一系列的初始化以及对Bean配置资源进行载入。而载入就是通过ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory()完成的，所以，这就是之后的跟踪目标了。

