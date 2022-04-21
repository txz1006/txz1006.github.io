springIOC解析(8)-将bean定义对象注册到IOC容器

### 一、IOC容器注册BeanDefinitionHolder

在解析XML标签完成后，我们得到了一个BeanDefinitionHolder对象，接下来需要关注的就是如何将这个对象注册到IOC容器中了，我们回到DefaultBeanDefinitionDocumentReader#processBeanDefinition中继续跟踪代码的执行找到BeanDefinitionReaderUtils.registerBeanDefinition,很明显这就是注册过程的的调用，让我们来详细了解下：

```java
//BeanDefinitionReaderUtils.registerBeanDefinition
//-------------------------
public static void registerBeanDefinition(
		BeanDefinitionHolder definitionHolder, BeanDefinitionRegistry registry)
		throws BeanDefinitionStoreException {
	// Register bean definition under primary name.
	//获取beanName
	String beanName = definitionHolder.getBeanName();
	//调用DefaultListableBeanFactory.registerBeanDefinition注册BeanDefinitionHolder
	registry.registerBeanDefinition(beanName, definitionHolder.getBeanDefinition());

	// Register aliases for bean name, if any.
	//如果有别名也注册到容器
	String[] aliases = definitionHolder.getAliases();
	if (aliases != null) {
		for (String alias : aliases) {
			registry.registerAlias(beanName, alias);
		}
	}
}
```

注册bean用到了容器对象DefaultListableBeanFactory，调用registerBeanDefinition将definitionHolder注册到IOC中；如果bean与别名信息，也会注册到容器中。下面继续跟进registerBeanDefinition：

```java
//DefaultListableBeanFactory#registerBeanDefinition
//--------------------------
public void registerBeanDefinition(String beanName, BeanDefinition beanDefinition)
      throws BeanDefinitionStoreException {

   Assert.hasText(beanName, "Bean name must not be empty");
   Assert.notNull(beanDefinition, "BeanDefinition must not be null");

   //bean校验
   if (beanDefinition instanceof AbstractBeanDefinition) {
      try {
         ((AbstractBeanDefinition) beanDefinition).validate();
      }
      catch (BeanDefinitionValidationException ex) {
         throw new BeanDefinitionStoreException(beanDefinition.getResourceDescription(), beanName,
               "Validation of bean definition failed", ex);
      }
   }

   //在beanDefinitionMap中查询是否存在名称为beanName的对象
   BeanDefinition existingDefinition = this.beanDefinitionMap.get(beanName);
   if (existingDefinition != null) {
      //存在则需要更新
      if (!isAllowBeanDefinitionOverriding()) {
         throw new BeanDefinitionOverrideException(beanName, beanDefinition, existingDefinition);
      }
      else if (existingDefinition.getRole() < beanDefinition.getRole()) {
         // e.g. was ROLE_APPLICATION, now overriding with ROLE_SUPPORT or ROLE_INFRASTRUCTURE
         if (logger.isInfoEnabled()) {
            logger.info("Overriding user-defined bean definition for bean '" + beanName +
                  "' with a framework-generated bean definition: replacing [" +
                  existingDefinition + "] with [" + beanDefinition + "]");
         }
      }
      else if (!beanDefinition.equals(existingDefinition)) {
         if (logger.isDebugEnabled()) {
            logger.debug("Overriding bean definition for bean '" + beanName +
                  "' with a different definition: replacing [" + existingDefinition +
                  "] with [" + beanDefinition + "]");
         }
      }
      else {
         if (logger.isTraceEnabled()) {
            logger.trace("Overriding bean definition for bean '" + beanName +
                  "' with an equivalent definition: replacing [" + existingDefinition +
                  "] with [" + beanDefinition + "]");
         }
      }
      this.beanDefinitionMap.put(beanName, beanDefinition);
   }
   else {
      //beanDefinitionMap中不存在，则要新创建
      if (hasBeanCreationStarted()) {
         //处理多线程是否已经在注册了,保证数据一致性
         // Cannot modify startup-time collection elements anymore (for stable iteration)
         synchronized (this.beanDefinitionMap) {
            //beanDefinition放入容器map
            this.beanDefinitionMap.put(beanName, beanDefinition);
            List<String> updatedDefinitions = new ArrayList<>(this.beanDefinitionNames.size() + 1);
            updatedDefinitions.addAll(this.beanDefinitionNames);
            updatedDefinitions.add(beanName);
            this.beanDefinitionNames = updatedDefinitions;
            removeManualSingletonName(beanName);
         }
      }
      else {
         // Still in startup registration phase
         this.beanDefinitionMap.put(beanName, beanDefinition);
         this.beanDefinitionNames.add(beanName);
         removeManualSingletonName(beanName);
      }
      this.frozenBeanDefinitionNames = null;
   }
   //若之前注册过该bean，则重置bean缓存信息
   if (existingDefinition != null || containsSingleton(beanName)) {
      resetBeanDefinition(beanName);
   }
}
```

注册过程有以下几步：

1. 校验bean是否符合要求
2. 根据beanName判断该bean是否在IOC容器中中注册过，注册过则经过判断后进行bean信息在容器Map的更新
3. 未注册则直接将bean加入容器Map中，过程线程同步保存数据一致
4. 如果之前注册过，则进行bean缓存重置

注册完成后容器就可以使用这些beanDefinition进行依赖注入了。

### 二、回溯Bean定义注册过程

![spring(5.1.9)加载时序图1](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103521.svg)