springIOC解析(4)-loadBeanDefinitions加载bean定义

### 一、XmlBeanDefinitionReader读取配置信息

上次我们跟踪源码到reader.loadBeanDefinitions(configLocations);通过名称我可以了解到这行代码的逻辑是使用读取器加载Bean定义信息，参数是String数组，实际为["config.xml"]。下面我们学习下loadBeanDefinitions的详细逻辑，代码的实际实现在父类AbstractBeanDefinitionReader中：

```java
//位置：AbstractBeanDefinitionReader#loadBeanDefinitions(java.lang.String...)
//----------------
public int loadBeanDefinitions(String... locations) throws BeanDefinitionStoreException {
	Assert.notNull(locations, "Location array must not be null");
	int count = 0;
	//循环数组加载不同的配置文件路径
	for (String location : locations) {
		count += loadBeanDefinitions(location);
	}
	return count;
}

//最终实现逻辑，actualResources参数为null
public int loadBeanDefinitions(String location, @Nullable Set<Resource> actualResources) throws BeanDefinitionStoreException {
    //获取当前对象的资源加载器特性
	ResourceLoader resourceLoader = getResourceLoader();
	if (resourceLoader == null) {
		throw new BeanDefinitionStoreException(
				"Cannot load bean definitions from location [" + location + "]: no ResourceLoader available");
	}

	if (resourceLoader instanceof ResourcePatternResolver) {
		// Resource pattern matching available.
		try {
            //实际通过委托给PathMatchingResourcePatternResolver#getResources来获取资源数组
			Resource[] resources = ((ResourcePatternResolver) resourceLoader).getResources(location);
            //调用重载方法，获取加载的bean定义数
			int count = loadBeanDefinitions(resources);
			if (actualResources != null) {
				Collections.addAll(actualResources, resources);
			}
			if (logger.isTraceEnabled()) {
				logger.trace("Loaded " + count + " bean definitions from location pattern [" + location + "]");
			}
			return count;
		}
		catch (IOException ex) {
			throw new BeanDefinitionStoreException(
					"Could not resolve bean definition resource pattern [" + location + "]", ex);
		}
	}
	else {
		// Can only load single resources by absolute URL.
		Resource resource = resourceLoader.getResource(location);
		int count = loadBeanDefinitions(resource);
		if (actualResources != null) {
			actualResources.add(resource);
		}
		if (logger.isTraceEnabled()) {
			logger.trace("Loaded " + count + " bean definitions from location [" + location + "]");
		}
		return count;
	}
}

public int loadBeanDefinitions(Resource... resources) throws BeanDefinitionStoreException {
	Assert.notNull(resources, "Resource array must not be null");
	int count = 0;
	for (Resource resource : resources) {
        //（子类XmlBeanDefinitionReader实现）
		count += loadBeanDefinitions(resource);
	}
	return count;
}
```

上述代码主要完成了两个动作：首先，将当前对象ClassPathXmlApplicationContext作为一个资源加载对象获取到资源数组；其次，将资源数组传给子类XmlBeanDefinitionReader做进一步处理。

### 二、解析配置文件路径

上一节中使用Resource[] resources = ((ResourcePatternResolver) resourceLoader).getResources(location);获取到了资源数组，这里我们来详解下对应逻辑：

```java
//PathMatchingResourcePatternResolver#getResources
//----------------
@Override
public Resource[] getResources(String locationPattern) throws IOException {
   Assert.notNull(locationPattern, "Location pattern must not be null");
   //是否classpath*:开头
   if (locationPattern.startsWith(CLASSPATH_ALL_URL_PREFIX)) {
      // a class path resource (multiple resources for same name possible)
      //处理出现同名多个资源的情况
      if (getPathMatcher().isPattern(locationPattern.substring(CLASSPATH_ALL_URL_PREFIX.length()))) {
         // a class path resource pattern
         return findPathMatchingResources(locationPattern);
      }
      else {
         // all class path resources with the given name
         return findAllClassPathResources(locationPattern.substring(CLASSPATH_ALL_URL_PREFIX.length()));
      }
   }
   else {
      // Generally only look for a pattern after a prefix here,
      // and on Tomcat only after the "*/" separator for its "war:" protocol.
      //去除前缀截取剩余配置路径串
      int prefixEnd = (locationPattern.startsWith("war:") ? locationPattern.indexOf("*/") + 1 :
            locationPattern.indexOf(':') + 1);
      if (getPathMatcher().isPattern(locationPattern.substring(prefixEnd))) {
         // a file pattern
         return findPathMatchingResources(locationPattern);
      }
      else {
         // a single resource with the given name
         //处理单个资源（实际实现为ClassPathXmlApplicationContext的父类DefaultResourceLoader）
         return new Resource[] {getResourceLoader().getResource(locationPattern)};
      }
   }
}
```

在PathMatchingResourcePatternResolver#getResources中进行预处理，处理完前缀问题后返回一个资源数组，这里的getResourceLoader()为DefaultResourceLoader，进一步进行解析，代码如下：

```java
//DefaultResourceLoader#getResource
//---------------------
@Override
public Resource getResource(String location) {
   Assert.notNull(location, "Location must not be null");

   for (ProtocolResolver protocolResolver : this.protocolResolvers) {
      Resource resource = protocolResolver.resolve(location, this);
      if (resource != null) {
         return resource;
      }
   }
   //如果是类路径的配置串，则委托给ClassPathContextResource对象进行解析
   if (location.startsWith("/")) {
      return getResourceByPath(location);
   }
   //如果是‘classpath:’开头，则委托给ClassPathResource对象进行解析
   else if (location.startsWith(CLASSPATH_URL_PREFIX)) {
      return new ClassPathResource(location.substring(CLASSPATH_URL_PREFIX.length()), getClassLoader());
   }
   else {
      try {
         // Try to parse the location as a URL...
         //如果是url格式，文件路径委托给FileUrlResource解析，网络路径委托给UrlResource解析
         URL url = new URL(location);
         return (ResourceUtils.isFileURL(url) ? new FileUrlResource(url) : new UrlResource(url));
      }
      catch (MalformedURLException ex) {
         // No URL -> resolve as resource path.
         //上述解析方式都不满足时，时用默认解析方式ClassPathContextResource
         return getResourceByPath(location);
      }
   }
}
```

上述代码逻辑为：根据配置路径的格式(类路径、‘classpath:’开头、URL等)来选择不同的解析方法，这里采用的最后的默认解析方式getResourceByPath(location)，即返回一个ClassPathContextResource对象。

### 三、Resource[]资源的进一步解析

在AbstractBeanDefinitionReader中count += loadBeanDefinitions(resource);对获取到的资源进行下一步的解析工作，实际代码在子类XmlBeanDefinitionReader中实现，代码如下：


```java
//XmlBeanDefinitionReader#loadBeanDefinitions
//--------------------------
@Override
public int loadBeanDefinitions(Resource resource) throws BeanDefinitionStoreException {
   //将资源包装为EncodedResource，处理编码问题
   return loadBeanDefinitions(new EncodedResource(resource));
}

public int loadBeanDefinitions(EncodedResource encodedResource) throws BeanDefinitionStoreException {
   Assert.notNull(encodedResource, "EncodedResource must not be null");
   if (logger.isTraceEnabled()) {
      logger.trace("Loading XML bean definitions from " + encodedResource);
   }

   //创建一个线程资源容器，将encodedResource放入其中
   Set<EncodedResource> currentResources = this.resourcesCurrentlyBeingLoaded.get();
   if (currentResources == null) {
      currentResources = new HashSet<>(4);
      this.resourcesCurrentlyBeingLoaded.set(currentResources);
   }
   if (!currentResources.add(encodedResource)) {
      throw new BeanDefinitionStoreException(
            "Detected cyclic loading of " + encodedResource + " - check your import definitions!");
   }
   try {
      //config.xml encodedResource.getResource()实际为ClassPathContextResource
      //getResource().getInputStream()实际为ClassPathContextResource的父类ClassPathResource.getInputStream
      InputStream inputStream = encodedResource.getResource().getInputStream();
      try {
         //将inputStream封装为InputSource对象
         InputSource inputSource = new InputSource(inputStream);
         if (encodedResource.getEncoding() != null) {
            inputSource.setEncoding(encodedResource.getEncoding());
         }
         //使用输入流和原资源对象，进行正式解析
         return doLoadBeanDefinitions(inputSource, encodedResource.getResource());
      }
      finally {
         inputStream.close();
      }
   }
   catch (IOException ex) {
      throw new BeanDefinitionStoreException(
            "IOException parsing XML document from " + encodedResource.getResource(), ex);
   }
   finally {
      currentResources.remove(encodedResource);
      if (currentResources.isEmpty()) {
         this.resourcesCurrentlyBeingLoaded.remove();
      }
   }
}
```

不难看出loadBeanDefinitions(EncodedResource)有两步逻辑：首先创建了一个线程容器

```java
//XmlBeanDefinitionReader
//-------------------
private final ThreadLocal<Set<EncodedResource>> resourcesCurrentlyBeingLoaded =
      new NamedThreadLocal<>("XML bean definition resources currently being loaded");
```

将encodedResource放入线程容器后，获取encodedResource的输入流inputStream，将inputStream封装为InputSource对象；

其次，进行下一步处理doLoadBeanDefinitions()。