springIOC解析(13)-扫描注解注册Beandefinition

### 一、ClassPathBeanDefinitionScanner扫描包信息

首先查看AnnotationConfigApplicationContext#scan方法,发现扫描工作委托给了ClassPathBeanDefinitionScanner进行：

```java
//AnnotationConfigApplicationContext#scan
private final ClassPathBeanDefinitionScanner scanner;
public void scan(String... basePackages) {
	Assert.notEmpty(basePackages, "At least one base package must be specified");
	this.scanner.scan(basePackages);
}
```

直接调用ClassPathBeanDefinitionScanner#scan方法。

```java
//ClassPathBeanDefinitionScanner#scan
public int scan(String... basePackages) {
   //记录注册bean前容器中的bean数
   int beanCountAtScanStart = this.registry.getBeanDefinitionCount();
   //扫描包路径中的bean
   doScan(basePackages);

   // Register annotation config processors, if necessary.
   //是否要注册Processors接口的bean
   if (this.includeAnnotationConfig) {
      AnnotationConfigUtils.registerAnnotationConfigProcessors(this.registry);
   }
   //返回注册的bean数
   return (this.registry.getBeanDefinitionCount() - beanCountAtScanStart);
}
```

scan方法主要做了两件事：1.扫描包信息，注册beanDefinition。2.注册Processor接口，之后返回注册bean的数量

下面来看下doScan(basePackages)的方法：

```java
//ClassPathBeanDefinitionScanner#doScan
protected Set<BeanDefinitionHolder> doScan(String... basePackages) {
   Assert.notEmpty(basePackages, "At least one base package must be specified");
   Set<BeanDefinitionHolder> beanDefinitions = new LinkedHashSet<>();
   //包路径可以是一个数组
   for (String basePackage : basePackages) {
      //获取当前路径中的beandefinition列表
      // findCandidateComponents方法会根据basePackage扫描读取class资源文件，将每个class文件封装为ScannedGenericBeanDefinition
      Set<BeanDefinition> candidates = findCandidateComponents(basePackage);
      //循环beandefinition列表
      for (BeanDefinition candidate : candidates) {
         //通过作用域返回解析器获取bean的@Scope信息，封装成ScopeMetadata对象
         ScopeMetadata scopeMetadata = this.scopeMetadataResolver.resolveScopeMetadata(candidate);
         //给bean定义对象设置作用域
         candidate.setScope(scopeMetadata.getScopeName());
         //通过生成器生成beanName
         String beanName = this.beanNameGenerator.generateBeanName(candidate, this.registry);
         //给bean定义对象设置LazyInit、AutowireMode、autowire-candidate、EnforceInitMethod等属性默认值
         if (candidate instanceof AbstractBeanDefinition) {
            postProcessBeanDefinition((AbstractBeanDefinition) candidate, beanName);
         }
         //根据Metadata获取bean的Lazy.class、Primary.class、DependsOn.class等注解信息，并将其设置到bean定义中
         if (candidate instanceof AnnotatedBeanDefinition) {
            AnnotationConfigUtils.processCommonDefinitionAnnotations((AnnotatedBeanDefinition) candidate);
         }
         //检查bean信息是否冲突
         if (checkCandidate(beanName, candidate)) {
            //创建BeanDefinitionHolder对象
            BeanDefinitionHolder definitionHolder = new BeanDefinitionHolder(candidate, beanName);
            //判断bean的@Scope属性，是否需要创建代理bean对象
            definitionHolder =
                  AnnotationConfigUtils.applyScopedProxyMode(scopeMetadata, definitionHolder, this.registry);
            beanDefinitions.add(definitionHolder);
            //将bean定义对象注册到BeanDefinition容器中
            registerBeanDefinition(definitionHolder, this.registry);
         }
      }
   }
   return beanDefinitions;
}
```

简单解读下此方法的的逻辑：

1. 循环包路径，通过findCandidateComponents(basePackage)解析得到beanDefinition的列表(实际为通过asm字节码方式获取类的元数据信息Metadata)
2. 循环beanDefinition列表，通过scopeMetadataResolver读取类的Metadata获取@Scope注解信息，反过来赋值到bean定义对象中
3. 生成beanName，给bean定义对象的一些属性设置默认值(LazyInit、AutowireMode、autowire-candidate等等属性)
4. 调用processCommonDefinitionAnnotations，通过读取类的Metadata获取常用注解信息(Lazy.class、Primary.class、DependsOn.class等),赋值到bean定义对象中，此时beanDefinition基本完整。
5. 检查当前bean信息是否重复冲突，之后将beanDefinition封装成BeanDefinitionHolder对象
6. 调用applyScopedProxyMode，根据@Scope的proxyMode属性判断是否需要生成代理bean对象
7. 将BeanDefinitionHolder对象加入bean定义对象列表，之后将其注册到IOC容器中

有上述步骤可以知道，doScan方法主要通过basePackages包路径获取到beanDefinition信息(实际为Metadata信息)，通过解析Metadata信息得到类中的各种注解信息，并根据注解信息完善beanDefinition对象，最后封装成BeanDefinitionHolder对象注册到IOC容器中。

下面我们来详解下findCandidateComponents、postProcessBeanDefinition、AnnotationConfigUtils.processCommonDefinitionAnnotations等几个关键方法的逻辑。



