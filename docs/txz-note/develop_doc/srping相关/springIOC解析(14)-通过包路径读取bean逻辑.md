springIOC解析(14)-通过包路径读取bean逻辑

### 一、ClassPathBeanDefinitionScanner#doScan详解

此章详细解析ClassPathBeanDefinitionScanner#doScan中的几个关键方法：

#### 1.findCandidateComponents()解析

```java
//ClassPathScanningCandidateComponentProvider#findCandidateComponents
public Set<BeanDefinition> findCandidateComponents(String basePackage) {
    //是否添加限定的beandefinition
   if (this.componentsIndex != null && indexSupportsIncludeFilters()) {
      return addCandidateComponentsFromIndex(this.componentsIndex, basePackage);
   }
   else {
      return scanCandidateComponents(basePackage);
   }
}
```

判断是加载限定设置的BeanDefinition还是通过扫描获取BeanDefinition，这里一般是走else执行scanCandidateComponents()

```java
//ClassPathScanningCandidateComponentProvider
//获取元数据解析对象
public final MetadataReaderFactory getMetadataReaderFactory() {
	if (this.metadataReaderFactory == null) {
		this.metadataReaderFactory = new CachingMetadataReaderFactory();
	}
	return this.metadataReaderFactory;
}

//获取资源解析对象
private ResourcePatternResolver getResourcePatternResolver() {
	if (this.resourcePatternResolver == null) {
		this.resourcePatternResolver = new PathMatchingResourcePatternResolver();
	}
	return this.resourcePatternResolver;
}

private Set<BeanDefinition> scanCandidateComponents(String basePackage) {
   //需要返回一个bean定义列表
   Set<BeanDefinition> candidates = new LinkedHashSet<>();
   try {
      //获取class文件访问路径
      String packageSearchPath = ResourcePatternResolver.CLASSPATH_ALL_URL_PREFIX +
            resolveBasePackage(basePackage) + '/' + this.resourcePattern;
      //获取包路径下的class文件数组
      Resource[] resources = getResourcePatternResolver().getResources(packageSearchPath);
      boolean traceEnabled = logger.isTraceEnabled();
      boolean debugEnabled = logger.isDebugEnabled();
      for (Resource resource : resources) {
         if (traceEnabled) {
            logger.trace("Scanning " + resource);
         }
         if (resource.isReadable()) {
            try {
               //将class资源对象封装成元数据读取对象(并缓存元数据信息)
               MetadataReader metadataReader = getMetadataReaderFactory().getMetadataReader(resource);
               //判断资源对象是否需要会被过滤
               if (isCandidateComponent(metadataReader)) {
                  //将元数据封装成扫描得到的通用BeanDefinition对象
                  ScannedGenericBeanDefinition sbd = new ScannedGenericBeanDefinition(metadataReader);
                  //将资源信息放入bean定义中
                  sbd.setResource(resource);
                  sbd.setSource(resource);
                  if (isCandidateComponent(sbd)) {
                     if (debugEnabled) {
                        logger.debug("Identified candidate component class: " + resource);
                     }
                     candidates.add(sbd);
                  }
                  else {
                     if (debugEnabled) {
                        logger.debug("Ignored because not a concrete top-level class: " + resource);
                     }
                  }
               }
               else {
                  if (traceEnabled) {
                     logger.trace("Ignored because not matching any filter: " + resource);
                  }
               }
            }
            catch (Throwable ex) {
               throw new BeanDefinitionStoreException(
                     "Failed to read candidate component class: " + resource, ex);
            }
         }
         else {
            if (traceEnabled) {
               logger.trace("Ignored because not readable: " + resource);
            }
         }
      }
   }
   catch (IOException ex) {
      throw new BeanDefinitionStoreException("I/O failure during classpath scanning", ex);
   }
   return candidates;
}
```

上面的scanCandidateComponents方法就是通过包路径将class解析成了beanDefinition对象，我们来梳理一下实现逻辑：

1. 将路径补全为文件读取路径后，使用PathMatchingResourcePatternResolver对象解析路径获取class文件封装成Resource数组

2. 循环Resource数组，通过CachingMetadataReaderFactory对象getMetadataReader方法，将Resource对象封装成MetadataReader对象，并将MetadataReader对象加入spring的metadataReaderCache对象中(Map对象)

   ```java
   //CachingMetadataReaderFactory#getMetadataReader
   @Override
   public MetadataReader getMetadataReader(Resource resource) throws IOException {
      if (this.metadataReaderCache instanceof ConcurrentMap) {
         // No synchronization necessary...
         MetadataReader metadataReader = this.metadataReaderCache.get(resource);
         if (metadataReader == null) {
            metadataReader = super.getMetadataReader(resource);
             //将元数据对象加入缓存
            this.metadataReaderCache.put(resource, metadataReader);
         }
         return metadataReader;
      }
      else if (this.metadataReaderCache != null) {
         synchronized (this.metadataReaderCache) {
            MetadataReader metadataReader = this.metadataReaderCache.get(resource);
            if (metadataReader == null) {
               metadataReader = super.getMetadataReader(resource);
               this.metadataReaderCache.put(resource, metadataReader);
            }
            return metadataReader;
         }
      }
      else {
         return super.getMetadataReader(resource);
      }
   }
   //super.getMetadataReader()调用父类方法
   //SimpleMetadataReaderFactory#getMetadataReader(org.springframework.core.io.Resource)
   @Override
   public MetadataReader getMetadataReader(Resource resource) throws IOException {
       //SimpleMetadataReader中会通过asm字节码获取resource的元数据信息(后面可以通过元数据获取类的注解信息)
   	return new SimpleMetadataReader(resource, this.resourceLoader.getClassLoader());
   }
   
   ```

3. 判断MetadataReader对象是否被过滤掉，若不被过滤则将MetadataReader进一步封装成ScannedGenericBeanDefinition对象，ScannedGenericBeanDefinition的继承链如下图所示：

   ![image-20200617100745429](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103614.png)

4. 将resource对象赋值到ScannedGenericBeanDefinition中完成初步构建，继续循环下一个resource对象；最后会返回一个ScannedGenericBeanDefinition列表。

#### 2.postProcessBeanDefinition()解析

```java
//ClassPathBeanDefinitionScanner#postProcessBeanDefinition
protected void postProcessBeanDefinition(AbstractBeanDefinition beanDefinition, String beanName) {
   //给beanDefinition设置默认值
   beanDefinition.applyDefaults(this.beanDefinitionDefaults);
   if (this.autowireCandidatePatterns != null) {
      beanDefinition.setAutowireCandidate(PatternMatchUtils.simpleMatch(this.autowireCandidatePatterns, beanName));
   }
}

//AbstractBeanDefinition#applyDefaults
public void applyDefaults(BeanDefinitionDefaults defaults) {
	setLazyInit(defaults.isLazyInit());
	setAutowireMode(defaults.getAutowireMode());
	setDependencyCheck(defaults.getDependencyCheck());
	setInitMethodName(defaults.getInitMethodName());
	setEnforceInitMethod(false);
	setDestroyMethodName(defaults.getDestroyMethodName());
	setEnforceDestroyMethod(false);
}
```

主要逻辑是给beanDefinition设置默认值，之后判断autowireCandidatePatterns属性，决定是否设置beanDefinition的AutowireCandidate属性。

#### 3.AnnotationConfigUtils.processCommonDefinitionAnnotations()解析

```java
//AnnotationConfigUtils
public static void processCommonDefinitionAnnotations(AnnotatedBeanDefinition abd) {
   processCommonDefinitionAnnotations(abd, abd.getMetadata());
}

static void processCommonDefinitionAnnotations(AnnotatedBeanDefinition abd, AnnotatedTypeMetadata metadata) {
   //通过元数据对象获取类中的注解信息
   //获取@Lazy
   AnnotationAttributes lazy = attributesFor(metadata, Lazy.class);
   if (lazy != null) {
      abd.setLazyInit(lazy.getBoolean("value"));
   }
   else if (abd.getMetadata() != metadata) {
      lazy = attributesFor(abd.getMetadata(), Lazy.class);
      if (lazy != null) {
         abd.setLazyInit(lazy.getBoolean("value"));
      }
   }

   //获取@Primary
   if (metadata.isAnnotated(Primary.class.getName())) {
      abd.setPrimary(true);
   }
   //获取@DependsOn
   AnnotationAttributes dependsOn = attributesFor(metadata, DependsOn.class);
   if (dependsOn != null) {
      abd.setDependsOn(dependsOn.getStringArray("value"));
   }

   //获取@Role
   AnnotationAttributes role = attributesFor(metadata, Role.class);
   if (role != null) {
      abd.setRole(role.getNumber("value").intValue());
   }
   //获取@Description
   AnnotationAttributes description = attributesFor(metadata, Description.class);
   if (description != null) {
      abd.setDescription(description.getString("value"));
   }
}
```

通过beanDefinition中的元数据对象获取类中的常用注解信息来给beanDefinition的属性赋值。

#### 4.AnnotationConfigUtils.applyScopedProxyMode()解析

```java
//AnnotationConfigUtils
static BeanDefinitionHolder applyScopedProxyMode(
		ScopeMetadata metadata, BeanDefinitionHolder definition, BeanDefinitionRegistry registry) {

	ScopedProxyMode scopedProxyMode = metadata.getScopedProxyMode();
	//判断bean的@Scope是否设置了ProxyMode属性，没有则直接返回
	if (scopedProxyMode.equals(ScopedProxyMode.NO)) {
		return definition;
	}
	//判断bean的@Scope的ProxyMode是否为cglib代理，是则要通过cglib创建代理对象，否则通过jdk创建
	boolean proxyTargetClass = scopedProxyMode.equals(ScopedProxyMode.TARGET_CLASS);
	//将definitionHolder中的bean定义对象注册到BeanDefinition容器中(注册beanName加scopedTarget.前缀)，
	//并创建一个内容相同的代理BeanDefinition对象，将其封装成BeanDefinitionHolder后返回
	return ScopedProxyCreator.createScopedProxy(definition, registry, proxyTargetClass);
}
```

根据bean的@Scope的proxyMode属性判断是否需要生成代理对象，若是则会返回一个内容相同的BeanDefinitionHolder对象。

关于@Scope的proxyMode属性，可以参考https://blog.csdn.net/u013423085/article/details/82872533