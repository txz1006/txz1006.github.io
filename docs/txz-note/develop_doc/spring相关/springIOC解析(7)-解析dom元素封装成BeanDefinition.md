springIOC解析(7)-解析dom元素封装成BeanDefinition

### 一、XMLBean配置的解析与封装

在DefaultBeanDefinitionDocumentReader#processBeanDefinition中，对标签进行了下一步的委托处理：

```java
//BeanDefinitionParserDelegate#parseBeanDefinitionElement(org.w3c.dom.Element)
//----------------------
@Nullable
public BeanDefinitionHolder parseBeanDefinitionElement(Element ele) {
   return parseBeanDefinitionElement(ele, null);
}

@Nullable
public BeanDefinitionHolder parseBeanDefinitionElement(Element ele, @Nullable BeanDefinition containingBean) {
   //获取id属性
   String id = ele.getAttribute(ID_ATTRIBUTE);
   //获取名称属性
   String nameAttr = ele.getAttribute(NAME_ATTRIBUTE);

   //名称处理为别名列表
   List<String> aliases = new ArrayList<>();
   if (StringUtils.hasLength(nameAttr)) {
      String[] nameArr = StringUtils.tokenizeToStringArray(nameAttr, MULTI_VALUE_ATTRIBUTE_DELIMITERS);
      aliases.addAll(Arrays.asList(nameArr));
   }

   //id属性为空时，取第一个别名代替id
   String beanName = id;
   if (!StringUtils.hasText(beanName) && !aliases.isEmpty()) {
      beanName = aliases.remove(0);
      if (logger.isTraceEnabled()) {
         logger.trace("No XML 'id' specified - using '" + beanName +
               "' as bean name and " + aliases + " as aliases");
      }
   }

   //containingBean检查是否包含子Bean信息
   if (containingBean == null) {
      //检查Bean名称是否有重复
      checkNameUniqueness(beanName, aliases, ele);
   }
   //创建Bean定义对象，并解析beanXML元素的属性和子元素
   AbstractBeanDefinition beanDefinition = parseBeanDefinitionElement(ele, beanName, containingBean);
   if (beanDefinition != null) {
      if (!StringUtils.hasText(beanName)) {
         try {
            if (containingBean != null) {
               //若bean没有设置id，name，且包含子bean信息，则生成一个唯一bean名称并注册
               beanName = BeanDefinitionReaderUtils.generateBeanName(
                     beanDefinition, this.readerContext.getRegistry(), true);
            }
            else {
               beanName = this.readerContext.generateBeanName(beanDefinition);
               // Register an alias for the plain bean class name, if still possible,
               // if the generator returned the class name plus a suffix.
               // This is expected for Spring 1.2/2.0 backwards compatibility.
               String beanClassName = beanDefinition.getBeanClassName();
               if (beanClassName != null &&
                     beanName.startsWith(beanClassName) && beanName.length() > beanClassName.length() &&
                     !this.readerContext.getRegistry().isBeanNameInUse(beanClassName)) {
                  aliases.add(beanClassName);
               }
            }
            if (logger.isTraceEnabled()) {
               logger.trace("Neither XML 'id' nor 'name' specified - " +
                     "using generated bean name [" + beanName + "]");
            }
         }
         catch (Exception ex) {
            error(ex.getMessage(), ele);
            return null;
         }
      }
      String[] aliasesArray = StringUtils.toStringArray(aliases);
      //将bean定义对象封装为BeanDefinitionHolder对象，并返回
      return new BeanDefinitionHolder(beanDefinition, beanName, aliasesArray);
   }

   return null;
}

//bean是否重名
protected void checkNameUniqueness(String beanName, List<String> aliases, Element beanElement) {
	String foundName = null;

	if (StringUtils.hasText(beanName) && this.usedNames.contains(beanName)) {
		foundName = beanName;
	}
	if (foundName == null) {
		foundName = CollectionUtils.findFirstMatch(this.usedNames, aliases);
	}
	if (foundName != null) {
		error("Bean name '" + foundName + "' is already used in this <beans> element", beanElement);
	}

	this.usedNames.add(beanName);
	this.usedNames.addAll(aliases);
}
```

处理逻辑如下：

1. 获取bean标签的id和name属性，处理name多个别名的情况(转为List)，当没有id属性时，把第一个别名当作唯属性beanName。
2. 检查当前beanName在this.usedNames列表中是否已存在，若已存在则报错(beanName重复)，不存在则将将当前beanName和别名加入this.usedNames中用于下次检查。
3. 进一步将XML元素解析封装为一个AbstractBeanDefinition对象，若beanName还为空，则生成一个唯一的beanName和一个beanClassName别名。
4. 将AbstractBeanDefinition对象、beanName、aliasesArray别名数组再次封装成一个BeanDefinitionHolder返回

我们来看下详细的XML属性解析的AbstractBeanDefinition beanDefinition = parseBeanDefinitionElement(ele, beanName, containingBean);

```java
//BeanDefinitionParserDelegate#parseBeanDefinitionElement
//-------------------------
@Nullable
public AbstractBeanDefinition parseBeanDefinitionElement(
      Element ele, String beanName, @Nullable BeanDefinition containingBean) {
   //记录解析bean的名称
   this.parseState.push(new BeanEntry(beanName));
   //获取class属性
   String className = null;
   if (ele.hasAttribute(CLASS_ATTRIBUTE)) {
      className = ele.getAttribute(CLASS_ATTRIBUTE).trim();
   }
   //获取parent属性
   String parent = null;
   if (ele.hasAttribute(PARENT_ATTRIBUTE)) {
      parent = ele.getAttribute(PARENT_ATTRIBUTE);
   }

   try {
      //创建Bean定义对象
      AbstractBeanDefinition bd = createBeanDefinition(className, parent);

      //解析ele元素，给Bean定义对象设置Bean属性值
      parseBeanDefinitionAttributes(ele, beanName, containingBean, bd);
      //获取Bean描述
      bd.setDescription(DomUtils.getChildElementValueByTagName(ele, DESCRIPTION_ELEMENT));
      //处理Bean的meta属性
      parseMetaElements(ele, bd);
      //处理Bean的lookup-Method属性
      parseLookupOverrideSubElements(ele, bd.getMethodOverrides());
      //处理Bean的replace-Method属性
      parseReplacedMethodSubElements(ele, bd.getMethodOverrides());

      //处理Bean的constructor-arg构造方法
      parseConstructorArgElements(ele, bd);
      //处理Bean的property设置
      parsePropertyElements(ele, bd);
      //处理bean的qualifier属性
      parseQualifierElements(ele, bd);

      //将当前对象做为资源对象赋值给Beandefinition
      bd.setResource(this.readerContext.getResource());
      //
      bd.setSource(extractSource(ele));

      return bd;
   }
   catch (ClassNotFoundException ex) {
      error("Bean class [" + className + "] not found", ele, ex);
   }
   catch (NoClassDefFoundError err) {
      error("Class that bean class [" + className + "] depends on not found", ele, err);
   }
   catch (Throwable ex) {
      error("Unexpected failure during bean definition parsing", ele, ex);
   }
   finally {
      this.parseState.pop();
   }

   return null;
}

//创建bean对象
protected AbstractBeanDefinition createBeanDefinition(@Nullable String className, @Nullable String parentName)
		throws ClassNotFoundException {
	//创建一个Bean定义对象(实际为GenericBeanDefinition)，存储className信息
	//this.readerContext.getBeanClassLoader()实际为XmlBeanDefinitionReader的classLoader
	return BeanDefinitionReaderUtils.createBeanDefinition(
			parentName, className, this.readerContext.getBeanClassLoader());
}
```

处理逻辑如下：

1. 获取标签中的class、parent属性，根据这些属性创建bean定义对象(实际创建了GenericBeanDefinition)，继承链如下图：
    ![image-20200516151901483](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103505.png)

2. 处理XML配置属性，将属性设置进Bean定义对象中，并返回。

其中parseBeanDefinitionAttributes代码如下：

```java
//BeanDefinitionParserDelegate#parseBeanDefinitionAttributes
//------------------------
public AbstractBeanDefinition parseBeanDefinitionAttributes(Element ele, String beanName,
      @Nullable BeanDefinition containingBean, AbstractBeanDefinition bd) {

   //是否右singleton属性
   if (ele.hasAttribute(SINGLETON_ATTRIBUTE)) {
      error("Old 1.x 'singleton' attribute in use - upgrade to 'scope' declaration", ele);
   }
   //是否有scope属性
   else if (ele.hasAttribute(SCOPE_ATTRIBUTE)) {
      bd.setScope(ele.getAttribute(SCOPE_ATTRIBUTE));
   }
   //存在子bean时，设置与子作用域相同的scope
   else if (containingBean != null) {
      // Take default from containing bean in case of an inner bean definition.
      bd.setScope(containingBean.getScope());
   }

   //是否有attribute属性
   if (ele.hasAttribute(ABSTRACT_ATTRIBUTE)) {
      bd.setAbstract(TRUE_VALUE.equals(ele.getAttribute(ABSTRACT_ATTRIBUTE)));
   }

   String lazyInit = ele.getAttribute(LAZY_INIT_ATTRIBUTE);
   //是否懒加载
   if (isDefaultValue(lazyInit)) {
      lazyInit = this.defaults.getLazyInit();
   }
   bd.setLazyInit(TRUE_VALUE.equals(lazyInit));

   //获取设置要注入的autowire属性
   String autowire = ele.getAttribute(AUTOWIRE_ATTRIBUTE);
   bd.setAutowireMode(getAutowireMode(autowire));

   //是否有depends-on属性
   if (ele.hasAttribute(DEPENDS_ON_ATTRIBUTE)) {
      String dependsOn = ele.getAttribute(DEPENDS_ON_ATTRIBUTE);
      bd.setDependsOn(StringUtils.tokenizeToStringArray(dependsOn, MULTI_VALUE_ATTRIBUTE_DELIMITERS));
   }

   //获取autowire-candidate属性，是否待注入
   String autowireCandidate = ele.getAttribute(AUTOWIRE_CANDIDATE_ATTRIBUTE);
   if (isDefaultValue(autowireCandidate)) {
      String candidatePattern = this.defaults.getAutowireCandidates();
      if (candidatePattern != null) {
         String[] patterns = StringUtils.commaDelimitedListToStringArray(candidatePattern);
         bd.setAutowireCandidate(PatternMatchUtils.simpleMatch(patterns, beanName));
      }
   }
   else {
      bd.setAutowireCandidate(TRUE_VALUE.equals(autowireCandidate));
   }

   //是否有primary属性（优先加载）
   if (ele.hasAttribute(PRIMARY_ATTRIBUTE)) {
      bd.setPrimary(TRUE_VALUE.equals(ele.getAttribute(PRIMARY_ATTRIBUTE)));
   }

   //是否有init-method属性
   if (ele.hasAttribute(INIT_METHOD_ATTRIBUTE)) {
      String initMethodName = ele.getAttribute(INIT_METHOD_ATTRIBUTE);
      bd.setInitMethodName(initMethodName);
   }
   else if (this.defaults.getInitMethod() != null) {
      bd.setInitMethodName(this.defaults.getInitMethod());
      bd.setEnforceInitMethod(false);
   }

   //是否有destroy-method属性
   if (ele.hasAttribute(DESTROY_METHOD_ATTRIBUTE)) {
      String destroyMethodName = ele.getAttribute(DESTROY_METHOD_ATTRIBUTE);
      bd.setDestroyMethodName(destroyMethodName);
   }
   //是否有强制销毁方法
   else if (this.defaults.getDestroyMethod() != null) {
      bd.setDestroyMethodName(this.defaults.getDestroyMethod());
      bd.setEnforceDestroyMethod(false);
   }

   //是否有factory-method属性
   if (ele.hasAttribute(FACTORY_METHOD_ATTRIBUTE)) {
      bd.setFactoryMethodName(ele.getAttribute(FACTORY_METHOD_ATTRIBUTE));
   }
   //是否有factory-bean属性
   if (ele.hasAttribute(FACTORY_BEAN_ATTRIBUTE)) {
      bd.setFactoryBeanName(ele.getAttribute(FACTORY_BEAN_ATTRIBUTE));
   }

   return bd;
}
```

可以看到根据标签的属性，对Bean定义对象进行赋值。我们回到parseBeanDefinitionElement类中看下处理property的方法parsePropertyElements()：

```java
//BeanDefinitionParserDelegate#parsePropertyElements
//------------------------
public void parsePropertyElements(Element beanEle, BeanDefinition bd) {
   //获取子元素列表
   NodeList nl = beanEle.getChildNodes();
   for (int i = 0; i < nl.getLength(); i++) {
      Node node = nl.item(i);
      //解析默认命名空间，名称为property的标签
      if (isCandidateElement(node) && nodeNameEquals(node, PROPERTY_ELEMENT)) {
         parsePropertyElement((Element) node, bd);
      }
   }
}

public void parsePropertyElement(Element ele, BeanDefinition bd) {
	//获取name属性
	String propertyName = ele.getAttribute(NAME_ATTRIBUTE);
	if (!StringUtils.hasLength(propertyName)) {
		error("Tag 'property' must have a 'name' attribute", ele);
		return;
	}
	this.parseState.push(new PropertyEntry(propertyName));
	try {
		//不允许property元素重复
		if (bd.getPropertyValues().contains(propertyName)) {
			error("Multiple 'property' definitions for property '" + propertyName + "'", ele);
			return;
		}
		//获取property元素的值(ref和value中的一种)
		Object val = parsePropertyValue(ele, bd, propertyName);
		//创建Property对象
		PropertyValue pv = new PropertyValue(propertyName, val);
		//处理meta信息
		parseMetaElements(ele, pv);
		//设置引用关系
		pv.setSource(extractSource(ele));
		//赋值给bean定义对象
		bd.getPropertyValues().addPropertyValue(pv);
	}
	finally {
		this.parseState.pop();
	}
}

@Nullable
public Object parsePropertyValue(Element ele, BeanDefinition bd, @Nullable String propertyName) {
	String elementName = (propertyName != null ?
			"<property> element for property '" + propertyName + "'" :
			"<constructor-arg> element");

	// Should only have one child element: ref, value, list, etc.
	//获取property子元素，只能是ref, value, list, etc四种类型
	NodeList nl = ele.getChildNodes();
	Element subElement = null;
	for (int i = 0; i < nl.getLength(); i++) {
		Node node = nl.item(i);
		//获取不是元素名称不是description和meta的元素
		if (node instanceof Element && !nodeNameEquals(node, DESCRIPTION_ELEMENT) &&
				!nodeNameEquals(node, META_ELEMENT)) {
			// Child element is what we're looking for.
			if (subElement != null) {
				error(elementName + " must not contain more than one sub-element", ele);
			}
			else {
				subElement = (Element) node;
			}
		}
	}

	//是否ref属性
	boolean hasRefAttribute = ele.hasAttribute(REF_ATTRIBUTE);
	//是否value属性
	boolean hasValueAttribute = ele.hasAttribute(VALUE_ATTRIBUTE);
	//不允许ref和value同时存在
	if ((hasRefAttribute && hasValueAttribute) ||
			((hasRefAttribute || hasValueAttribute) && subElement != null)) {
		error(elementName +
				" is only allowed to contain either 'ref' attribute OR 'value' attribute OR sub-element", ele);
	}

	//处理ref属性
	if (hasRefAttribute) {
		String refName = ele.getAttribute(REF_ATTRIBUTE);
		if (!StringUtils.hasText(refName)) {
			error(elementName + " contains empty 'ref' attribute", ele);
		}
		//创建一个依赖引用对象(在解析的时候才会实例化依赖对象)
		RuntimeBeanReference ref = new RuntimeBeanReference(refName);
		//设置这个ref被当前对象引用
		ref.setSource(extractSource(ele));
		return ref;
	}
	//处理value属性
	else if (hasValueAttribute) {
		///创建一个String类型对象
		TypedStringValue valueHolder = new TypedStringValue(ele.getAttribute(VALUE_ATTRIBUTE));
		//设置引用
		valueHolder.setSource(extractSource(ele));
		return valueHolder;
	}
	else if (subElement != null) {
		return parsePropertySubElement(subElement, bd);
	}
	else {
		// Neither child element nor "ref" or "value" attribute found.
		error(elementName + " must specify a ref or value", ele);
		return null;
	}
}
```

解析Property标签，处理ref和value两种情况的值，返回一个PropertyValue赋值给bean定义对象。

其中对Property标签是否有子元素parsePropertySubElement进行进一步的处理：

```java
//BeanDefinitionParserDelegate#parsePropertySubElement
//-----------------------------
@Nullable
public Object parsePropertySubElement(Element ele, @Nullable BeanDefinition bd) {
   return parsePropertySubElement(ele, bd, null);
}

@Nullable
public Object parsePropertySubElement(Element ele, @Nullable BeanDefinition bd, @Nullable String defaultValueType) {
   //非默认命名空间进入自定义解析方法
   if (!isDefaultNamespace(ele)) {
      return parseNestedCustomElement(ele, bd);
   }
   //若property的子元素为bean的处理方法
   else if (nodeNameEquals(ele, BEAN_ELEMENT)) {
      BeanDefinitionHolder nestedBd = parseBeanDefinitionElement(ele, bd);
      if (nestedBd != null) {
         nestedBd = decorateBeanDefinitionIfRequired(ele, nestedBd, bd);
      }
      return nestedBd;
   }
   //处理ref标签
   else if (nodeNameEquals(ele, REF_ELEMENT)) {
      // A generic reference to any name of any bean.
      String refName = ele.getAttribute(BEAN_REF_ATTRIBUTE);
      boolean toParent = false;
      if (!StringUtils.hasLength(refName)) {
         // A reference to the id of another bean in a parent context.
         refName = ele.getAttribute(PARENT_REF_ATTRIBUTE);
         toParent = true;
         if (!StringUtils.hasLength(refName)) {
            error("'bean' or 'parent' is required for <ref> element", ele);
            return null;
         }
      }
      if (!StringUtils.hasText(refName)) {
         error("<ref> element contains empty target attribute", ele);
         return null;
      }
      RuntimeBeanReference ref = new RuntimeBeanReference(refName, toParent);
      ref.setSource(extractSource(ele));
      return ref;
   }
   //处理idref标签
   else if (nodeNameEquals(ele, IDREF_ELEMENT)) {
      return parseIdRefElement(ele);
   }
   //处理value标签
   else if (nodeNameEquals(ele, VALUE_ELEMENT)) {
      return parseValueElement(ele, defaultValueType);
   }
   //处理null标签
   else if (nodeNameEquals(ele, NULL_ELEMENT)) {
      // It's a distinguished null value. Let's wrap it in a TypedStringValue
      // object in order to preserve the source location.
      TypedStringValue nullHolder = new TypedStringValue(null);
      nullHolder.setSource(extractSource(ele));
      return nullHolder;
   }
   //处理array标签
   else if (nodeNameEquals(ele, ARRAY_ELEMENT)) {
      return parseArrayElement(ele, bd);
   }
   //处理list标签
   else if (nodeNameEquals(ele, LIST_ELEMENT)) {
      return parseListElement(ele, bd);
   }
   //处理set标签
   else if (nodeNameEquals(ele, SET_ELEMENT)) {
      return parseSetElement(ele, bd);
   }
   //处理map标签
   else if (nodeNameEquals(ele, MAP_ELEMENT)) {
      return parseMapElement(ele, bd);
   }
   //处理props标签
   else if (nodeNameEquals(ele, PROPS_ELEMENT)) {
      return parsePropsElement(ele);
   }
   else {
      error("Unknown property sub-element: [" + ele.getNodeName() + "]", ele);
      return null;
   }
}
```

通过上述标签解析的过程，便完成了一个标签的完整解读封装。