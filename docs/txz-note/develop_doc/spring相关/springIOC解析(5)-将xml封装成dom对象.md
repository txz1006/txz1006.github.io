springIOC解析(5)-将xml封装成dom对象

### 一、doLoadBeanDefinitions(真正解析配置文件的对象)

上次我们跟踪到了XmlBeanDefinitionReader#doLoadBeanDefinitions(InputSource inputSource, Resource resource)，这里是配置信息解析成spring可识别Bean定义对象的真正方法。业务代码如下：

```java
//XmlBeanDefinitionReader#doLoadBeanDefinitions
//-------------------------
protected int doLoadBeanDefinitions(InputSource inputSource, Resource resource)
      throws BeanDefinitionStoreException {

   try {
      //将获取到的配置资源转成dom对象
      Document doc = doLoadDocument(inputSource, resource);
      //根据配置的dom对象注册Bean定义，并返回注册过的数量
      int count = registerBeanDefinitions(doc, resource);
      if (logger.isDebugEnabled()) {
         logger.debug("Loaded " + count + " bean definitions from " + resource);
      }
      return count;
   }
   catch (BeanDefinitionStoreException ex) {
      throw ex;
   }
   catch (SAXParseException ex) {
      throw new XmlBeanDefinitionStoreException(resource.getDescription(),
            "Line " + ex.getLineNumber() + " in XML document from " + resource + " is invalid", ex);
   }
   catch (SAXException ex) {
      throw new XmlBeanDefinitionStoreException(resource.getDescription(),
            "XML document from " + resource + " is invalid", ex);
   }
   catch (ParserConfigurationException ex) {
      throw new BeanDefinitionStoreException(resource.getDescription(),
            "Parser configuration exception parsing XML from " + resource, ex);
   }
   catch (IOException ex) {
      throw new BeanDefinitionStoreException(resource.getDescription(),
            "IOException parsing XML document from " + resource, ex);
   }
   catch (Throwable ex) {
      throw new BeanDefinitionStoreException(resource.getDescription(),
            "Unexpected exception parsing XML document from " + resource, ex);
   }
}
```

这是解析配置的关键步骤，不难明白代码的实际意义为：

1. 将配置文件读取成一个dom文件对象
2. 解析dom文档对象，注册解析Bean定义信息，并返回注册的数量

### 二、配置文件解析为dom对象

Document doc = doLoadDocument(inputSource, resource);实现了将配置资源解析为dom对象，代码如下：

```java
//XmlBeanDefinitionReader#doLoadBeanDefinitions
//------------------------
protected int doLoadBeanDefinitions(InputSource inputSource, Resource resource)
      throws BeanDefinitionStoreException {

   try {
      //将获取到的配置资源转成dom对象
      Document doc = doLoadDocument(inputSource, resource);
      //根据配置的dom对象注册Bean定义，并返回注册过的数量
      int count = registerBeanDefinitions(doc, resource);
      if (logger.isDebugEnabled()) {
         logger.debug("Loaded " + count + " bean definitions from " + resource);
      }
      return count;
   }
   catch (BeanDefinitionStoreException ex) {
      throw ex;
   }
   catch (SAXParseException ex) {
      throw new XmlBeanDefinitionStoreException(resource.getDescription(),
            "Line " + ex.getLineNumber() + " in XML document from " + resource + " is invalid", ex);
   }
   catch (SAXException ex) {
      throw new XmlBeanDefinitionStoreException(resource.getDescription(),
            "XML document from " + resource + " is invalid", ex);
   }
   catch (ParserConfigurationException ex) {
      throw new BeanDefinitionStoreException(resource.getDescription(),
            "Parser configuration exception parsing XML from " + resource, ex);
   }
   catch (IOException ex) {
      throw new BeanDefinitionStoreException(resource.getDescription(),
            "IOException parsing XML document from " + resource, ex);
   }
   catch (Throwable ex) {
      throw new BeanDefinitionStoreException(resource.getDescription(),
            "Unexpected exception parsing XML document from " + resource, ex);
   }
}

protected Document doLoadDocument(InputSource inputSource, Resource resource) throws Exception {
   //委托给DefaultDocumentLoader文档加载对象进行文档解析
   return this.documentLoader.loadDocument(inputSource, getEntityResolver(), this.errorHandler,
         getValidationModeForResource(resource), isNamespaceAware());
}
```

上述代码逐步开始了对配置资源的解析工作，实际上就是委托给DefaultDocumentLoader#loadDocument来进行的，解析参数中除了inputSource外加入了getEntityResolver()用来进行资源实体解析：

```java
//XmlBeanDefinitionReader#getEntityResolver
//---------------------
protected EntityResolver getEntityResolver() {
   if (this.entityResolver == null) {
      // Determine default EntityResolver to use.
      //获取当前资源加载对象
      ResourceLoader resourceLoader = getResourceLoader();
      if (resourceLoader != null) {
         //资源加载对象非空时，返回一个默认的资源实体解析对象
         this.entityResolver = new ResourceEntityResolver(resourceLoader);
      }
      else {
         //资源加载对象为空时，返回一个代理实体解析对象
         this.entityResolver = new DelegatingEntityResolver(getBeanClassLoader());
      }
   }
   return this.entityResolver;
}
```

、getValidationModeForResource(resource)用来确定配置文件的校验格式是DTD还是XSD：

```java
//XmlBeanDefinitionReader#getValidationModeForResource
//---------------------
protected int getValidationModeForResource(Resource resource) {
   //获取默认校验方式(getValidationMode()默认为VALIDATION_AUTO)
   //VALIDATION_AUTO = 1
   int validationModeToUse = getValidationMode();
   //当验证方式不是默认值时，返回新validationModeToUse
   if (validationModeToUse != VALIDATION_AUTO) {
      return validationModeToUse;
   }
   //获取配置资源的校验方式
   int detectedMode = detectValidationMode(resource);
   //当验证方式不是默认值时，返回新validationModeToUse
   if (detectedMode != VALIDATION_AUTO) {
      return detectedMode;
   }
   // Hmm, we didn't get a clear indication... Let's assume XSD,
   // since apparently no DTD declaration has been found up until
   // detection stopped (before finding the document's root tag).
   //如果没有指定明确的校验方式，这里假定默认使用XSD校验方式
   return VALIDATION_XSD;
}

protected int detectValidationMode(Resource resource) {
   if (resource.isOpen()) {
      throw new BeanDefinitionStoreException(
            "Passed-in Resource [" + resource + "] contains an open stream: " +
            "cannot determine validation mode automatically. Either pass in a Resource " +
            "that is able to create fresh streams, or explicitly specify the validationMode " +
            "on your XmlBeanDefinitionReader instance.");
   }

   InputStream inputStream;
   try {
      inputStream = resource.getInputStream();
   }
   catch (IOException ex) {
      throw new BeanDefinitionStoreException(
            "Unable to determine validation mode for [" + resource + "]: cannot open InputStream. " +
            "Did you attempt to load directly from a SAX InputSource without specifying the " +
            "validationMode on your XmlBeanDefinitionReader instance?", ex);
   }

   try {
      //检测xml配置使用的dtd还是xsd校验方式
      //委托给XmlValidationModeDetector对象进行检查
      //最后返回xml使用的校验方式(isDtdValidated ? VALIDATION_DTD : VALIDATION_XSD)
      return this.validationModeDetector.detectValidationMode(inputStream);
   }
   catch (IOException ex) {
      throw new BeanDefinitionStoreException("Unable to determine validation mode for [" +
            resource + "]: an error occurred whilst reading from the InputStream.", ex);
   }
}
```