spring中WebMvc流程解析

### 一、spring中WebMvc流程解析

#### 1.servlet简介

​		servlet是一种运行在web服务器环境中的java程序，常见的使用形式是定义一个java类，继承HttpServlet类，重写HttpServlet的init()和doGet/doPost方法，之后在web.xml定义这个类的servlet响应路径，将该java类编译后的class文件放入tomcat服务器的/webapps/ROOT/WEB-INF/classes文件夹下，将web.xml文件放入/webapps/ROOT/WEB-INF文件夹下，启动tomcat，访问映射路径后得到结果即访问servlet成功。

##### servlet的工作流程

​		想搞清楚servlet的工作流程前，必须要了解servlet在web服务器中的流转逻辑，这里以tomcat为例，tomcat服务器主要实现了三个功能：

1. 建立通道监听端口的请求数据

2. 创建了servlet容器，规定了servlet执行规则(init->service->(doGet||doPost))

3. 构建端口请求对象和servlet响应地址的映射关系

所以一个完整的请求流程是：

1. 用户在web环境中发起一个请求信息
2. tomcat端口监听对象捕获到请求后会创建request和response对象，将请求报文封装到requset中
3. request对象通过请求url映射关系找到对应servlet对象，若是首次访问该servlet则执行init方法
4. 之后执行service方法，根据resquest中的请求类型进一步执行doGet或doPost一类请求方法
5. 我们在doGet或doPost方法中处理完逻辑后，会将数据封装到response对象中，返回给用户完成请求流程

##### 一个servlet实例

这里使用springboot构建web项目环境

定义一个servlet类：

```java
public class SimpleServlet extends HttpServlet {

    @Override
    public void init() throws ServletException {
        System.out.println("servlet执行");
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        System.out.println("doGet执行");
        doPost(req,resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        System.out.println("doPost执行");
        resp.setContentType("text/html;charset=UTF-8");
        resp.getWriter().append("你好");
    }

    @Override
    protected void service(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        super.service(req, resp);
        System.out.println("service执行");

    }
}
```

创建servlet注册类

```java
@Configuration
public class ServletConfig  {
    @Bean
    public ServletRegistrationBean servletRegistrationBean() {
        ServletRegistrationBean servletRegistrationBean =
                new ServletRegistrationBean(new SimpleServlet(),"/v4/*");
        return servletRegistrationBean;
    }
}
```

启动springboot项目，访问http://localhost/v4，页面显示'你好'，同时项目控制端打印内容：

```java
servlet执行
doGet执行
doPost执行
service执行
```

#### 2.spring中对servlet的应用

​		在上述servlet实例中，实现了对于**/v4** url的请求拦截，如果要拦截其他url的请求我们要创建另外一个servlet了，那么能不能只创建一个servlet完成对所有请求地址的拦截？答案是肯定的，将servlet的拦截地址改为**/***就可以了；在此基础上能不能做一些扩展：根据不同的请求url执行不同的逻辑，当然也可以，spring的MVC模块就是这么做的，中间涉及到了DispatcherServlet、@Controller、@RequestMapping等我们常用到的内容，下面来分析下springMVC的工作原理。

**一个自定义的mvc映射servlet**

我们先简化代码实现springMVC的功能：

项目文件结构如下图：

![image-20200716184930150](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103259.png)

1.定义MVC中常用的注解

```java
@Target({ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface PWBAutowired {
    String value() default "";
}

@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface PWBController {
    String value() default "";
}

@Target({ElementType.TYPE,ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface PWBRequestMapping {
    String value() default "";
}

@Target({ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface PWBRequestParam {
    String value() default "";
}

@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface PWBService {
    String value() default  "";
}
```

2.定义一个通用servlet

```java
@WebServlet(name = "PwbDisparcherServlet", urlPatterns = {
        "/*"
})
public class PwbDisparcherServlet extends HttpServlet {
    //存储扫描到的bean类路径名称
    private  List<String> classNameList = new ArrayList<>();
    //存储bean
    private Map<String,Object> iocMap = new HashMap<>();
    //存储url映射关系
    private Map<String, Method> handlerMap = new HashMap<>();

    @Override
    public void init(ServletConfig cfg) throws ServletException {
        //根据配置读取需要实例化的bean
        doScanner("com.demo");
        //将有注解标注的bean实例化并存储
        doInstance();
        //将被调用的对象进行注入
        doAutowire();
        //将所有映射访问路径进行存储
        doHandlerMapping();
        System.out.println("---------------初始化完成！！！！");
    }


    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) {
        doDisparcher(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) {
        doDisparcher(req, resp);
    }
}
```

这个serlvet的初始化方法包含了以下逻辑：

1. 扫描包路径获取bean对象信息，存储到classNameList中(doScanner方法)

   ```java
   private void doScanner(String scanPackage){
       URL url = this.getClass().getClassLoader().getResource(scanPackage.replaceAll("\\.","/"));
       File classFile = new File(url.getFile());
       if(classFile == null){
           throw new RuntimeException(classFile.toString()+"文件路径错误!");
       }
       if(classFile.listFiles() == null){
           throw new RuntimeException("获取不到"+classFile.toString()+"文件路径下的列表数据!");
       }
       for(File file: classFile.listFiles()){
           if(file.isDirectory()){
               //递归
               doScanner(scanPackage+"."+file.getName());
           }else{
               //获取class绝对路径
               if(file.getName().endsWith(".class")&&!file.getName().contains("PWB")&&!file.getName().contains("Application")&&!file.getName().contains("Servlet")){
                   String className = scanPackage+"."+ file.getName().replaceAll(".class","");
                   classNameList.add(className);
               }
           }
   
       }
   }
   ```

2. 根据classNameList列表，对bean进行实例化并存储到iocMap中(doInstance方法)

   ```java
   private void doInstance(){
       try {
           for(String className: classNameList){
               //过滤
               if (!className.contains(".")) {
                   continue;
               }
               //类实例化
               iocMap.put(className, Class.forName(className).newInstance());
           }
       } catch (ClassNotFoundException e) {
           e.printStackTrace();
       } catch (InstantiationException e) {
           e.printStackTrace();
       } catch (IllegalAccessException e) {
           e.printStackTrace();
       }
   }
   ```

3. 根据bean中的@PWBAutowired注解信息，完成对bean中的一类注入(doAutowire方法)

   ```java
   private void doAutowire() {
       System.out.println("---------------开始注入！！！！");
       try {
           //处理类的依赖注入
           for(Object object: iocMap.values()){
               if(object == null){
                   continue;
               }
               Class clazz = object.getClass();
               //循环类的属性,找要注入的类
               for(Field field : clazz.getDeclaredFields()){
                   if(field.isAnnotationPresent(PWBAutowired.class)){
                       String beanName = field.getAnnotation(PWBAutowired.class).value();
                       if("".equals(beanName)){
                           beanName = field.getType().getName();
                       }
                       //解除限制
                       field.setAccessible(true);
                       field.set(iocMap.get(clazz.getName()), iocMap.get(beanName));
   
                   }
               }
           }
       } catch (IllegalAccessException e) {
           e.printStackTrace();
       }
   }
   ```

4. 根据bean中的@PWBController和@PWBRequestMapping注解信息，构建url和method的对应关系，存储到handlerMap中(doHandlerMapping方法)

   ```java
   private void doHandlerMapping() {
       for(Map.Entry bean: iocMap.entrySet()){
           Class<?> clazz = bean.getValue().getClass();
           //是否有PWBController注解
           if (clazz.isAnnotationPresent(PWBController.class)) {
               //是否有PWBRequestMapping注解
               String mappingUrl = "";
               if (clazz.isAnnotationPresent(PWBRequestMapping.class)) {
                   //获取注解内容
                   mappingUrl = clazz.getAnnotation(PWBRequestMapping.class).value();
               }
               //循环类的方法，记录请求url和对应方法
               Method[] methods = clazz.getMethods();
               for (Method method : methods) {
                   if (method.isAnnotationPresent(PWBRequestMapping.class)) {
                       String url = method.getAnnotation(PWBRequestMapping.class).value();
                       url = (mappingUrl + url).replaceAll("/+", "/");
                       handlerMap.put(url, method);
                   }
               }
           }
       }
   }
   ```

5. 根据request中的请求url，匹配method，通过反射执行目标方法(doDisparcher方法)

   ```java
   private void doDisparcher(HttpServletRequest req, HttpServletResponse resp) {
       String url = req.getRequestURI();
       String contextPath = req.getContextPath();
       url = url.replace(contextPath,"").replaceAll("/+","/");
       try {
           if(!this.handlerMap.containsKey(url)){
               resp.getWriter().append("-------------404 NOT FOUND!");
               return;
           }
           //调用对应方法
           Method method = (Method) handlerMap.get(url);
           //获取实际请求参数
           Map<String, String[]> params = req.getParameterMap();
           //请求方法的入参类型数组
           Class<?> [] paramsTypes = method.getParameterTypes();
           //处理后的参数容器
           Object[] resultArray = new Object[paramsTypes.length];
           //循环参数类型数组
           for (int i=0; i < paramsTypes.length; i++){
               Class<?> paramType = paramsTypes[i];
               //参数为request直接返回
               if(paramType == HttpServletRequest.class){
                   resultArray[i] = req;
                   continue;
               //参数为response直接返回
               }else if (paramType == HttpServletResponse.class){
                   resultArray[i] = resp;
                   continue;
               //参数为string类型处理
               } else if (paramType == String.class) {
                   //获取参数对象
                   Parameter parameter = method.getParameters()[i];
                   //参数是否有PWBRequestParam注解
                   if(parameter.isAnnotationPresent(PWBRequestParam.class)){
                       String annoParamName = parameter.getAnnotation(PWBRequestParam.class).value();
                       resultArray[i] = Arrays.toString(params.get(annoParamName));
                   }else{
                       String paramName = method.getParameters()[i].getName();
                       resultArray[i] = Arrays.toString(params.get(paramName));
                   }
               }
           }
           //获取方法对应的类对象
           Object obj = (iocMap.get(method.getDeclaringClass().getName()));
           //反射
           method.invoke(obj, resultArray);
       }  catch (IOException e) {
           e.printStackTrace();
       }catch (IllegalAccessException e) {
           e.printStackTrace();
       } catch (InvocationTargetException e) {
           e.printStackTrace();
       }
   }
   ```

创建一个对应的请求Controller

```java
@PWBController
@PWBRequestMapping("/v1")
public class IndexController {
    @PWBAutowired
    private IndexService indexService;

    @PWBRequestMapping("/query")
    public void queryString(HttpServletRequest request, HttpServletResponse response, String name){
        String msg = indexService.queryString(name);
        try {
            response.setContentType("text/html;charset=UTF-8");
            response.getWriter().write(msg);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}

@PWBService
public class IndexService {
    public String queryString(String msg){
        return "service返回信息:"+msg+"=====";
    }
}
```

启动项目，访问http://localhost/v1/query

![image-20200702170626408](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103308.png)



#### 3.springMVC的源码解析

在上述流程中，完成整个url访问流程主要有两个阶段：构建url和method的映射关系阶段、映射访问Controller方法阶段；在spring中前者是在bean初始化阶段完成，后置在用户发起请求后完成。

##### 构建url和method的映射关系

```java
//WebMvcConfigurationSupport#requestMappingHandlerMapping
@Bean
public RequestMappingHandlerMapping requestMappingHandlerMapping() {
   RequestMappingHandlerMapping mapping = createRequestMappingHandlerMapping();
   //省略.... 
   return mapping;
}
@Bean
public RequestMappingHandlerAdapter requestMappingHandlerAdapter() {
	RequestMappingHandlerAdapter adapter = createRequestMappingHandlerAdapter();
    //省略.... 
    return mapping;
}
```

在spring的mvc模块中有个@Configuration配置类：DelegatingWebMvcConfiguration，他(父类)注册了MVC用到的核心组件：**RequestMappingHandlerMapping**和**RequestMappingHandlerAdapter**等等，前者就是构建url和method的映射关系的bean，后者是回调执行Controller方法的bean，这里只看**RequestMappingHandlerMapping**。

**RequestMappingHandlerMapping**实现了InitializingBean接口，在初始化时会执行afterPropertiesSet方法，这里就是构建url和method的映射关系的地方：

```java
//AbstractHandlerMethodMapping#afterPropertiesSet
@Override
public void afterPropertiesSet() {
   initHandlerMethods();
}

protected void initHandlerMethods() {
   for (String beanName : getCandidateBeanNames()) {
      if (!beanName.startsWith(SCOPED_TARGET_NAME_PREFIX)) {
         processCandidateBean(beanName);
      }
   }
   handlerMethodsInitialized(getHandlerMethods());
}

protected void processCandidateBean(String beanName) {
	Class<?> beanType = null;
	try {
		beanType = obtainApplicationContext().getType(beanName);
	}
	catch (Throwable ex) {
		// An unresolvable bean type, probably from a lazy bean - let's ignore it.
		if (logger.isTraceEnabled()) {
			logger.trace("Could not resolve type for bean '" + beanName + "'", ex);
		}
	}
	if (beanType != null && isHandler(beanType)) {
		detectHandlerMethods(beanName);
	}
}

//RequestMappingHandlerMapping#isHandler
  @Override
protected boolean isHandler(Class<?> beanType) {
  	return (AnnotatedElementUtils.hasAnnotation(beanType, Controller.class) ||
			AnnotatedElementUtils.hasAnnotation(beanType, RequestMapping.class));
  }
```

我们可以看到上述代码的逻辑是循环spring bean名称列表，根据class对象判断是否存在**Controller.class**或**RequestMapping.class**，之后进一步执行detectHandlerMethods(beanName)

```java
//AbstractHandlerMethodMapping#detectHandlerMethods
protected void detectHandlerMethods(Object handler) {
   Class<?> handlerType = (handler instanceof String ?
         obtainApplicationContext().getType((String) handler) : handler.getClass());

   if (handlerType != null) {
      Class<?> userType = ClassUtils.getUserClass(handlerType);
      Map<Method, T> methods = MethodIntrospector.selectMethods(userType,
            (MethodIntrospector.MetadataLookup<T>) method -> {
               try {
                   //创建RequestMappingInfo对象，对应Map的T
                  return getMappingForMethod(method, userType);
               }
               catch (Throwable ex) {
                  throw new IllegalStateException("Invalid mapping on handler class [" +
                        userType.getName() + "]: " + method, ex);
               }
            });
      if (logger.isTraceEnabled()) {
         logger.trace(formatMappings(userType, methods));
      }
      methods.forEach((method, mapping) -> {
         Method invocableMethod = AopUtils.selectInvocableMethod(method, userType);
         //创建urlLookup和mappingLookup列表
         registerHandlerMethod(handler, invocableMethod, mapping);
      });
   }
}

//RequestMappingHandlerMapping#getMappingForMethod
@Override
@Nullable
protected RequestMappingInfo getMappingForMethod(Method method, Class<?> handlerType) {
    //获取method上的RequestMapping注解信息
	RequestMappingInfo info = createRequestMappingInfo(method);
	if (info != null) {
        //获取class上的RequestMapping注解信息
		RequestMappingInfo typeInfo = createRequestMappingInfo(handlerType);
		if (typeInfo != null) {
            //拼接两端url信息
			info = typeInfo.combine(info);
		}
		String prefix = getPathPrefix(handlerType);
		if (prefix != null) {
			info = RequestMappingInfo.paths(prefix).build().combine(info);
		}
	}
	return info;
}

@Nullable
private RequestMappingInfo createRequestMappingInfo(AnnotatedElement element) {
	RequestMapping requestMapping = AnnotatedElementUtils.findMergedAnnotation(element, RequestMapping.class);
	RequestCondition<?> condition = (element instanceof Class ?
			getCustomTypeCondition((Class<?>) element) : getCustomMethodCondition((Method) element));
	return (requestMapping != null ? createRequestMappingInfo(requestMapping, condition) : null);
}
```

  这里是构建url映射关系的核心类，先获取class对象，根据class遍历method列表，每个method执行一次getMappingForMethod方法，getMappingForMethod方法会获取class和method上的RequestMapping注解值，并拼接成一个对象，循环完后形了Map对象methods；之后，再循环methods，根据key(Method)和value(RequestMappingInfo),循环执行registerHandlerMethod方法

```java
  //AbstractHandlerMethodMapping#registerHandlerMethod
  protected void registerHandlerMethod(Object handler, Method method, T mapping) {
     this.mappingRegistry.register(mapping, handler, method);
  }
  
  //mapping为RequestMappingInfo，handler为类名，method为方法对象
  public void register(T mapping, Object handler, Method method) {
  	this.readWriteLock.writeLock().lock();
  	try {
  		HandlerMethod handlerMethod = createHandlerMethod(handler, method);
  		assertUniqueMethodMapping(handlerMethod, mapping);
  		this.mappingLookup.put(mapping, handlerMethod);
  
  		List<String> directUrls = getDirectUrls(mapping);
  		for (String url : directUrls) {
  			this.urlLookup.add(url, mapping);
  		}
  
  		String name = null;
  		if (getNamingStrategy() != null) {
  			name = getNamingStrategy().getName(handlerMethod, mapping);
  			addMappingName(name, handlerMethod);
  		}
  
  		CorsConfiguration corsConfig = initCorsConfiguration(handler, method, mapping);
  		if (corsConfig != null) {
  			this.corsLookup.put(handlerMethod, corsConfig);
  		}
  
  		this.registry.put(mapping, new MappingRegistration<>(mapping, handlerMethod, directUrls, name));
  	}
  	finally {
  		this.readWriteLock.writeLock().unlock();
  	}
  }
```

这里就很好明白了，根据mapping(RequestMappingInfo)，handler(类名)，method(方法对象)三个参数构建两个map：urlLookup<url, RequestMappingInfo>和mappingLookup<RequestMappingInfo, HandlerMethod>。之后的servlet请求就是依据请求url从这两个map中获取到HandlerMethod对象的。

------

  ##### url请求DispatcherServlet

  DispatcherServlet就是springMVC中构建的通用servlet处理器，我们通过发起请求来了解DispatcherServlet的init方法和service方法的处理逻辑。

  先看DispatcherServlet的initStrategies方法，这是servlet的的init方法最后执行的逻辑(顺着继承链往上可以找到init方法)

  ```java
  @Override
  protected void onRefresh(ApplicationContext context) {
     initStrategies(context);
  }
  
  //完成初始化工作，从IOC容器中获取MVC需要用到的九大组件
  protected void initStrategies(ApplicationContext context) {
     initMultipartResolver(context);
     initLocaleResolver(context);
     initThemeResolver(context);
     initHandlerMappings(context);
     initHandlerAdapters(context);
     initHandlerExceptionResolvers(context);
     initRequestToViewNameTranslator(context);
     initViewResolvers(context);
     initFlashMapManager(context);
  }
  ```

此处的初始化逻辑是从IOC容器中或创建MVC要用到的九大组件，详细逻辑参考下图：

![springMVC-init](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103317.png)

初始化完成后，直接找到DispatcherServlet的doDispatch()，这是请求跳转方法的核心方法(顺着继承链往上可以找到service方法)

  ```java
  //DispatcherServlet#doDispatch
  protected void doDispatch(HttpServletRequest request, HttpServletResponse response) throws Exception {
     HttpServletRequest processedRequest = request;
     HandlerExecutionChain mappedHandler = null;
     boolean multipartRequestParsed = false;
  
     WebAsyncManager asyncManager = WebAsyncUtils.getAsyncManager(request);
  
     try {
        ModelAndView mv = null;
        Exception dispatchException = null;
  
        try {
           processedRequest = checkMultipart(request);
           multipartRequestParsed = (processedRequest != request);
  
           //根据request从RequestMappingHandlerMapping中找到HandlerMethod，将HandlerMethod封装成
           //HandlerExecutionChain，之后将adaptedInterceptors拦截器对象，加入HandlerExecutionChain中
           mappedHandler = getHandler(processedRequest);
           if (mappedHandler == null) {
              noHandlerFound(processedRequest, response);
              return;
           }
  
           //根据HandlerMethod获取RequestMappingHandlerAdapter对象
           HandlerAdapter ha = getHandlerAdapter(mappedHandler.getHandler());
  
           // Process last-modified header, if supported by the handler.
           String method = request.getMethod();
           boolean isGet = "GET".equals(method);
           if (isGet || "HEAD".equals(method)) {
              long lastModified = ha.getLastModified(request, mappedHandler.getHandler());
              if (new ServletWebRequest(request, response).checkNotModified(lastModified) && isGet) {
                 return;
              }
           }
  
            //Interceptor接口对象前置方法
           if (!mappedHandler.applyPreHandle(processedRequest, response)) {
              return;
           }
  
           //通过RequestMappingHandlerAdapter对象回调中的方法HandlerMethod
           mv = ha.handle(processedRequest, response, mappedHandler.getHandler());
  
           if (asyncManager.isConcurrentHandlingStarted()) {
              return;
           }
  
           applyDefaultViewName(processedRequest, mv);
            //Interceptor接口对象处理方法
           mappedHandler.applyPostHandle(processedRequest, response, mv);
        }
        catch (Exception ex) {
           dispatchException = ex;
        }
        catch (Throwable err) {
           // As of 4.3, we're processing Errors thrown from handler methods as well,
           // making them available for @ExceptionHandler methods and other scenarios.
           dispatchException = new NestedServletException("Handler dispatch failed", err);
        }
        processDispatchResult(processedRequest, response, mappedHandler, mv, dispatchException);
     }
     catch (Exception ex) {
        triggerAfterCompletion(processedRequest, response, mappedHandler, ex);
     }
     catch (Throwable err) {
        triggerAfterCompletion(processedRequest, response, mappedHandler,
              new NestedServletException("Handler processing failed", err));
     }
     finally {
        if (asyncManager.isConcurrentHandlingStarted()) {
           // Instead of postHandle and afterCompletion
           if (mappedHandler != null) {
              mappedHandler.applyAfterConcurrentHandlingStarted(processedRequest, response);
           }
        }
        else {
           // Clean up any resources used by a multipart request.
           if (multipartRequestParsed) {
              cleanupMultipart(processedRequest);
           }
        }
     }
  }
  ```

 主要逻辑在getHandler、getHandlerAdapter、ha.handle中，通过这三个步骤，就完成了@RequestMapping方法的回调，并将结果写入response中。下面从getHandler开始看起：

```java
//DispatcherServlet#getHandler
protected HandlerExecutionChain getHandler(HttpServletRequest request) throws Exception {
   if (this.handlerMappings != null) {
      for (HandlerMapping mapping : this.handlerMappings) {
          //循环handlerMappings，返回非null的HandlerExecutionChain对象(一般指RequestMappingHandlerMapping)
         HandlerExecutionChain handler = mapping.getHandler(request);
         if (handler != null) {
            return handler;
         }
      }
   }
   return null;
}

//AbstractHandlerMapping#getHandler
public final HandlerExecutionChain getHandler(HttpServletRequest request) throws Exception {
    //获取handlerMethod对象
    Object handler = this.getHandlerInternal(request);
    if (handler == null) {
        handler = this.getDefaultHandler();
    }

    if (handler == null) {
        return null;
    } else {
        if (handler instanceof String) {
            String handlerName = (String)handler;
            handler = this.obtainApplicationContext().getBean(handlerName);
        }
		//将handlerMethod和request封装成HandlerExecutionChain
        HandlerExecutionChain executionChain = this.getHandlerExecutionChain(handler, request);
		//省略...
        return executionChain;
    }
}

//AbstractHandlerMethodMapping#getHandlerInternal
protected HandlerMethod getHandlerInternal(HttpServletRequest request) throws Exception {
    //从request中截取请求url
    String lookupPath = this.getUrlPathHelper().getLookupPathForRequest(request);
    this.mappingRegistry.acquireReadLock();

    HandlerMethod var4;
    try {
        //根据lookupPath从RequestMappingHandlerMapping中的urlLookup和mappingLookup获取到HandlerMethod
        HandlerMethod handlerMethod = this.lookupHandlerMethod(lookupPath, request);
        var4 = handlerMethod != null ? handlerMethod.createWithResolvedBean() : null;
    } finally {
        this.mappingRegistry.releaseReadLock();
    }

    return var4;
}

//AbstractHandlerMapping#getHandlerExecutionChain
protected HandlerExecutionChain getHandlerExecutionChain(Object handler, HttpServletRequest request) {
    //将HandlerMethod封装成HandlerExecutionChain
    HandlerExecutionChain chain = handler instanceof HandlerExecutionChain ? (HandlerExecutionChain)handler : new HandlerExecutionChain(handler);
    String lookupPath = this.urlPathHelper.getLookupPathForRequest(request);
    Iterator var5 = this.adaptedInterceptors.iterator();
	//将adaptedInterceptors拦截对象写入到chain中
    while(var5.hasNext()) {
        HandlerInterceptor interceptor = (HandlerInterceptor)var5.next();
        if (interceptor instanceof MappedInterceptor) {
            MappedInterceptor mappedInterceptor = (MappedInterceptor)interceptor;
            if (mappedInterceptor.matches(lookupPath, this.pathMatcher)) {
                chain.addInterceptor(mappedInterceptor.getInterceptor());
            }
        } else {
            chain.addInterceptor(interceptor);
        }
    }

    return chain;
}
```

getHandler的工作是返回一个HandlerExecutionChain对象，通过循环handlerMappings列表，获取非null的Mapping映射对象返回chain，这个对象一般是RequestMappingHandlerMapping，我们继续跟进找到对应的方法getHandlerInternal，发现他是通过获取resquest中的url，来匹配RequestMappingHandlerMapping中的urlLookup和mappingLookup获取到HandlerMethod对象，拿到HandlerMethod后，经过getHandlerExecutionChain的处理将其封装成HandlerExecutionChain后写入adaptedInterceptors拦截器列表后返回HandlerExecutionChain对象。(总结：RequestMappingHandlerMapping用于使请求url成功匹配到要回调的Controller方法)

------

拿到HandlerExecutionChain对象后，来看getHandlerAdapter的逻辑：

```java
//DispatcherServlet#getHandlerAdapter
protected HandlerAdapter getHandlerAdapter(Object handler) throws ServletException {
    if (this.handlerAdapters != null) {
        Iterator var2 = this.handlerAdapters.iterator();
		//返回能支持匹配HandlerMethod对象的
        while(var2.hasNext()) {
            HandlerAdapter adapter = (HandlerAdapter)var2.next();
            if (adapter.supports(handler)) {
                return adapter;
            }
        }
    }
}
```

逻辑和之前的getHandler类似，从handlerAdapters列表中返回一个支持匹配HandlerMethod的对象，这个对象一般是RequestMappingHandlerAdapter

------

拿到HandlerExecutionChain和RequestMappingHandlerAdapter后，就要用RequestMappingHandlerAdapter来回调HandlerMethod的对象了，来看ha.handle的逻辑：

```java
//AbstractHandlerMethodAdapter#handle
public final ModelAndView handle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
    return this.handleInternal(request, response, (HandlerMethod)handler);
}

//RequestMappingHandlerAdapter#handleInternal
protected ModelAndView handleInternal(HttpServletRequest request, HttpServletResponse response, HandlerMethod handlerMethod) throws Exception {
    this.checkRequest(request);
    ModelAndView mav;
    if (this.synchronizeOnSession) {
        HttpSession session = request.getSession(false);
        if (session != null) {
            Object mutex = WebUtils.getSessionMutex(session);
            synchronized(mutex) {
                mav = this.invokeHandlerMethod(request, response, handlerMethod);
            }
        } else {
            mav = this.invokeHandlerMethod(request, response, handlerMethod);
        }
    } else {
        //解析request请求参数，调用handlerMethod
        mav = this.invokeHandlerMethod(request, response, handlerMethod);
    }

    if (!response.containsHeader("Cache-Control")) {
        if (this.getSessionAttributesHandler(handlerMethod).hasSessionAttributes()) {
            this.applyCacheSeconds(response, this.cacheSecondsForSessionAttributeHandlers);
        } else {
            this.prepareResponse(response);
        }
    }

    return mav;
}

//RequestMappingHandlerAdapter#invokeHandlerMethod
protected ModelAndView invokeHandlerMethod(HttpServletRequest request, HttpServletResponse response, HandlerMethod handlerMethod) throws Exception {
    ServletWebRequest webRequest = new ServletWebRequest(request, response);

    Object result;
    try {
        //创建数据绑定工厂
        WebDataBinderFactory binderFactory = this.getDataBinderFactory(handlerMethod);
        ModelFactory modelFactory = this.getModelFactory(handlerMethod, binderFactory);
        //ServletInvocableHandlerMethod是处理调用handlerMethod的真正对象
        ServletInvocableHandlerMethod invocableMethod = this.createInvocableHandlerMethod(handlerMethod);
        if (this.argumentResolvers != null) {
            //写入参数解析对象
            invocableMethod.setHandlerMethodArgumentResolvers(this.argumentResolvers);
        }

        if (this.returnValueHandlers != null) {
            //写入返回值解析对象
            invocableMethod.setHandlerMethodReturnValueHandlers(this.returnValueHandlers);
        }
		//写入数据绑定工厂对象
        invocableMethod.setDataBinderFactory(binderFactory);
        invocableMethod.setParameterNameDiscoverer(this.parameterNameDiscoverer);
        //创建视图对象
        ModelAndViewContainer mavContainer = new ModelAndViewContainer();
        //视图写入request参数
        mavContainer.addAllAttributes(RequestContextUtils.getInputFlashMap(request));
        modelFactory.initModel(webRequest, mavContainer, invocableMethod);
        mavContainer.setIgnoreDefaultModelOnRedirect(this.ignoreDefaultModelOnRedirect);
        
		//省略...
		//进一步处理
        invocableMethod.invokeAndHandle(webRequest, mavContainer, new Object[0]);
        if (!asyncManager.isConcurrentHandlingStarted()) {
            ModelAndView var15 = this.getModelAndView(mavContainer, modelFactory, webRequest);
            return var15;
        }

        result = null;
    } finally {
        webRequest.requestCompleted();
    }

    return (ModelAndView)result;
}

//ServletInvocableHandlerMethod#invokeAndHandle
public void invokeAndHandle(ServletWebRequest webRequest, ModelAndViewContainer mavContainer, Object... providedArgs) throws Exception {
    //进一步回调
    Object returnValue = this.invokeForRequest(webRequest, mavContainer, providedArgs);
    this.setResponseStatus(webRequest);
    //处理回调视图
    if (returnValue == null) {
        if (this.isRequestNotModified(webRequest) || this.getResponseStatus() != null || mavContainer.isRequestHandled()) {
            this.disableContentCachingIfNecessary(webRequest);
            mavContainer.setRequestHandled(true);
            return;
        }
    } else if (StringUtils.hasText(this.getResponseStatusReason())) {
        mavContainer.setRequestHandled(true);
        return;
    }

    mavContainer.setRequestHandled(false);
    Assert.state(this.returnValueHandlers != null, "No return value handlers");

    try {
        //根据返回值和类型及其注解获取HandlerMethodReturnValueHandler对象，完成处理返回值的工作，包括是否返回视图还是数据
        this.returnValueHandlers.handleReturnValue(returnValue, this.getReturnValueType(returnValue), mavContainer, webRequest);
    } catch (Exception var6) {
        if (this.logger.isTraceEnabled()) {
            this.logger.trace(this.formatErrorForReturnValue(returnValue), var6);
        }

        throw var6;
    }
}

//InvocableHandlerMethod#invokeForRequest
public Object invokeForRequest(NativeWebRequest request, @Nullable ModelAndViewContainer mavContainer, Object... providedArgs) throws Exception {
    //处理request获取参数列表
    Object[] args = this.getMethodArgumentValues(request, mavContainer, providedArgs);
    //回调方法
    return this.doInvoke(args);
}

//InvocableHandlerMethod#getMethodArgumentValues
protected Object[] getMethodArgumentValues(NativeWebRequest request, @Nullable ModelAndViewContainer mavContainer, Object... providedArgs) throws Exception {
    //获取request中的参数列表
    MethodParameter[] parameters = this.getMethodParameters();
    if (ObjectUtils.isEmpty(parameters)) {
        return EMPTY_ARGS;
    } else {
        Object[] args = new Object[parameters.length];

        for(int i = 0; i < parameters.length; ++i) {
            MethodParameter parameter = parameters[i];
            parameter.initParameterNameDiscovery(this.parameterNameDiscoverer);
            //通过providedArgs获取参数值，一般是null
            args[i] = findProvidedArgument(parameter, providedArgs);
            if (args[i] == null) {
                if (!this.resolvers.supportsParameter(parameter)) {
                    throw new IllegalStateException(formatArgumentError(parameter, "No suitable resolver"));
                }

                try {
                    //通过HandlerMethodArgumentResolverComposite对象处理参数
                    //主要是通过参数及参数上的注解获取对应的HandlerMethodArgumentResolver对象，之后调用
                    //resolveArgument方法，方法中创建了WebDataBinder对象获取spring中ConversionService对象
                    //通过当前参数类型和目标参数类型的对应关系匹配ConversionService中的类型转换列表，来获取类型转换对象
                    //之后调用类型转换对象的convert方法完成类型的转换
                    //(ConversionService中的类型转换列表可以认为是spring内部的N多个实现了Converter<>接口的对象集合)
                    args[i] = this.resolvers.resolveArgument(parameter, mavContainer, request, this.dataBinderFactory);
                } catch (Exception var10) {
                    if (this.logger.isDebugEnabled()) {
                        String exMsg = var10.getMessage();
                        if (exMsg != null && !exMsg.contains(parameter.getExecutable().toGenericString())) {
                            this.logger.debug(formatArgumentError(parameter, exMsg));
                        }
                    }

                    throw var10;
                }
            }
        }

        return args;
    }
}

//InvocableHandlerMethod#doInvoke
protected Object doInvoke(Object... args) throws Exception {
    ReflectionUtils.makeAccessible(this.getBridgedMethod());
	//回调Controller方法
    return this.getBridgedMethod().invoke(this.getBean(), args);
}
```

ha.handle的逻辑比较的复杂，主要逻辑涉及参数类型的转换问题和是否返回视图数据对象。在RequestMappingHandlerAdapter组件中，经过层层调用，组织了一个真正的处理对象ServletInvocableHandlerMethod，并将初始化阶段创建的参数解析对象、返回值解析对象、数据绑定对象写入其中；使用参数解析对象通过数据绑定对象获取spring中ConversionService对象，借助ConversionService完成类型转换工作，之后将参数组织成数组回调Controller方法；之后获取回调值和返回类型，根据返回值解析对象获取对应的HandlerMethodReturnValueHandler对象，通过执行handleReturnValue方法完成返回值和视图的处理。(总结：RequestMappingHandlerAdapter主要用于处理参数，回调的Controller方法，及之后的返回视图数据问题)

------

整个DispatcherServlet的处理逻辑如下图所示：
![springMVCDispatcherServlet](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103330.png)



#####   总结

  1. 在spring实例化内部对象**RequestMappingHandlerMapping.class**时，会执行InitalizBean接口方法进行bean的class列表遍历，判断bean是否包含**@Controller.class**和**@RequestMapping.class**注解。
  2. 不包含则跳过，包含则进一步获取bean的全部Method列表进行遍历，若方法有**@RequestMapping.class**注解则尝试获取类上的**@RequestMapping.class**注解，将两段注解值进行拼接获取请求url和Method的对象关系，之后对获取的请求信息进行缓存，主要组成一个MappingRegistry对象存储所有的映射关系，MappingRegistry对象主要有两个重要的Map对象 ：**urlLookup(Map<url, RequestMappingInfo>)**和**mappingLookup(RequestMappingInfo, HandlerMethod)**。(HandlerMethod包含方法的参数信息)
  3. 这样在后面的servlet请求中就可以根据requset中的url地址对MappingRegistry进行匹配：**url** ->匹配到**urlLookup**信息获取**RequestMappingInfo**对象，又可以根据**RequestMappingInfo**->匹配**mappingLookup**获取**HandlerMethod**对象。(具体逻辑在方法org.springframework.web.servlet.DispatcherServlet#getHandler中)。
  4. 之后根据HandlerMethod获取对应的HandlerAdapter对象(默认是**RequestMappingHandlerAdapter**可解析**@RequestMapping.class**)，使用适配器对象去反射回调HandlerMethod中的method(回调之前会使用HandlerMethod包含的方法参数匹配request中的参数列表返回一个参数数组)。



