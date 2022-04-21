springIOC解析(6)-XmlBeanDefinitionReader解析dom对象

### 文档加载与Bean定义注册

在XmlBeanDefinitionReader中我们知道实际的配置解析工作委托给了DefaultDocumentLoader#loadDocument进行，代码如下：

```java
//DefaultDocumentLoader#loadDocument
//---------------------
@Override
public Document loadDocument(InputSource inputSource, EntityResolver entityResolver,
      ErrorHandler errorHandler, int validationMode, boolean namespaceAware) throws Exception {
   //创建文档构建工厂
   DocumentBuilderFactory factory = createDocumentBuilderFactory(validationMode, namespaceAware);
   if (logger.isTraceEnabled()) {
      logger.trace("Using JAXP provider [" + factory.getClass().getName() + "]");
   }
   //使用工厂构建文档解析器
   DocumentBuilder builder = createDocumentBuilder(factory, entityResolver, errorHandler);
   //解析配置信息返回dom对象
   return builder.parse(inputSource);
}


```

创建文档解析工厂对象，而后使用工厂创建出文档构造器DocumentBuilder对象，builder.parse(inputSource)实现了读取配置资源的详细过程(具体使用了jdk中xml解析过程)；得到Document对象后，我们回XmlBeanDefinitionReader中进行下一步registerBeanDefinitions操作，代码如下：

```java
//XmlBeanDefinitionReader#registerBeanDefinitions
//-----------------------
public int registerBeanDefinitions(Document doc, Resource resource) throws BeanDefinitionStoreException {
   //创建Bean定义对象读取器DefaultBeanDefinitionDocumentReader
   BeanDefinitionDocumentReader documentReader = createBeanDefinitionDocumentReader();
   //获取IOC容器DefaultListableBeanFactory中当前存储的Bean定义数
   int countBefore = getRegistry().getBeanDefinitionCount();
   //对配置文档进行Bean定义读取
   documentReader.registerBeanDefinitions(doc, createReaderContext(resource));
   //返回注册的配置文档Bean定义数
   return getRegistry().getBeanDefinitionCount() - countBefore;
}
```

这里创建了一个Bean定义对象读取器，对配置文档的Bean定义信息进行读取，并返回读取的Bean数量。详细的解析过程，我们要看documentReader.registerBeanDefinitions的代码：

```java
//DefaultBeanDefinitionDocumentReader#registerBeanDefinitions
//--------------
@Override
public void registerBeanDefinitions(Document doc, XmlReaderContext readerContext) {
	this.readerContext = readerContext;
	doRegisterBeanDefinitions(doc.getDocumentElement());
}
protected void doRegisterBeanDefinitions(Element root) {
	// Any nested <beans> elements will cause recursion in this method. In
	// order to propagate and preserve <beans> default-* attributes correctly,
	// keep track of the current (parent) delegate, which may be null. Create
	// the new (child) delegate with a reference to the parent for fallback purposes,
	// then ultimately reset this.delegate back to its original (parent) reference.
	// this behavior emulates a stack of delegates without actually necessitating one.
	//先将委托对象赋值给一个父对象，再给当前委托对象实例化(处理初始值,带上父对象，设置成父子链式结构)，
	//再次调用当前方法时，之前的delegate就成了新的父委托对象
	BeanDefinitionParserDelegate parent = this.delegate;
	//创建委托对象
	this.delegate = createDelegate(getReaderContext(), root, parent);
	//是否是默认的命名空间
	if (this.delegate.isDefaultNamespace(root)) {
		//是否有设置profile
		String profileSpec = root.getAttribute(PROFILE_ATTRIBUTE);
		if (StringUtils.hasText(profileSpec)) {
			//若profile有多个，则读取为数组，分割符号为,;
			String[] specifiedProfiles = StringUtils.tokenizeToStringArray(
					profileSpec, BeanDefinitionParserDelegate.MULTI_VALUE_ATTRIBUTE_DELIMITERS);
			// We cannot use Profiles.of(...) since profile expressions are not supported
			// in XML config. See SPR-12458 for details.
			//开启profile对应的配置文件
			if (!getReaderContext().getEnvironment().acceptsProfiles(specifiedProfiles)) {
				if (logger.isDebugEnabled()) {
					logger.debug("Skipped XML bean definition file due to specified profiles [" + profileSpec +
							"] not matching: " + getReaderContext().getResource());
				}
				return;
			}
		}
	}
	//解析xml前的空方法，用于子类继承扩展
	preProcessXml(root);
	//使用delegate对象解析xml
	parseBeanDefinitions(root, this.delegate);
	//解析xml后的空方法，用于子类继承扩展
	postProcessXml(root);

	this.delegate = parent;
}

protected BeanDefinitionParserDelegate createDelegate(
		XmlReaderContext readerContext, Element root, @Nullable BeanDefinitionParserDelegate parentDelegate) {

	BeanDefinitionParserDelegate delegate = new BeanDefinitionParserDelegate(readerContext);
	//初始化，处理默认值和父对象
	delegate.initDefaults(root, parentDelegate);
	return delegate;
}

```

上文的核心内容是创建了一个链式的BeanDefinitionParserDelegate委托对象，并使用该对象来解析XML文档。在解析方法的前后都留有空的方法用于自行扩展内容，下面我们来看下委托对象的如何进行XML的解析工作：

```java
//DefaultBeanDefinitionDocumentReader#parseBeanDefinitions
//---------------
protected void parseBeanDefinitions(Element root, BeanDefinitionParserDelegate delegate) {
	//root元素是否使用默认命名空间
	if (delegate.isDefaultNamespace(root)) {
		NodeList nl = root.getChildNodes();
		//循环子节点
		for (int i = 0; i < nl.getLength(); i++) {
			Node node = nl.item(i);
            //寻找XML元素节点再进行解析
			if (node instanceof Element) {
				Element ele = (Element) node;
                //ele元素是否使用的是默认命名空间
				if (delegate.isDefaultNamespace(ele)) {
					//解析默认元素
					parseDefaultElement(ele, delegate);
				}
				else {
					//解析自定义元素
					delegate.parseCustomElement(ele);
				}
			}
		}
	}
	else {
        //解析自定义元素
		delegate.parseCustomElement(root);
	}
}

private void parseDefaultElement(Element ele, BeanDefinitionParserDelegate delegate) {
	//标签元素共四种import，alias，bean，beans/根据类型不同选择不同的解析方式
	//是否是import元素
	if (delegate.nodeNameEquals(ele, IMPORT_ELEMENT)) {
		importBeanDefinitionResource(ele);
	}
	//是否是alias元素
	else if (delegate.nodeNameEquals(ele, ALIAS_ELEMENT)) {
		processAliasRegistration(ele);
	}
	//是否是bean元素
	else if (delegate.nodeNameEquals(ele, BEAN_ELEMENT)) {
		processBeanDefinition(ele, delegate);
	}
	//是否是beans元素
	else if (delegate.nodeNameEquals(ele, NESTED_BEANS_ELEMENT)) {
		// recurse
		doRegisterBeanDefinitions(ele);
	}
}
```

循环root元素及其子节点元素，根据元素使用的命名空间来确定使用默认的解析方式还是自定义的解析方式，这里一般都是默认命名空间的，所以走parseDefaultElement解析路线，自定义的方式可以自行了解。parseDefaultElement解析分了四种元素标签，这里我们走的是bean元素的解析路线，processBeanDefinition的代码如下：

```java
protected void processBeanDefinition(Element ele, BeanDefinitionParserDelegate delegate) {
   //将ele元素封装成一个BeanDefinitionHolder对象
   BeanDefinitionHolder bdHolder = delegate.parseBeanDefinitionElement(ele);
   if (bdHolder != null) {
      bdHolder = delegate.decorateBeanDefinitionIfRequired(ele, bdHolder);
      try {
// Register the final decorated instance.
//将Bean定义注册到IOC容器中(实际上就是将Bean定义对象放入容器的map对象中)
 //getReaderContext().getRegistry()实际获取的对象为DefaultListableBeanFactory(容器主体)
BeanDefinitionReaderUtils.registerBeanDefinition(bdHolder, getReaderContext().getRegistry());
      }
      catch (BeanDefinitionStoreException ex) {
         getReaderContext().error("Failed to register bean definition with name '" +
               bdHolder.getBeanName() + "'", ele, ex);
      }
      // Send registration event.
      //发送注册事件
      getReaderContext().fireComponentRegistered(new BeanComponentDefinition(bdHolder));
   }
}
```

使用委托对象delegate解析ele元素，将其解析封装为一个BeanDefinitionHolder对象，之后将其注册放入IOC容器中，这就是我们后期从IOC中实例化Bean的原型对象。