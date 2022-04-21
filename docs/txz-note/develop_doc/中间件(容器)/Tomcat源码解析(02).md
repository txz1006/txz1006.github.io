Tomcat源码解析(02)

### Tomcat启动逻辑总览

我们通常可以通过startup.sh/startup.bat来启动tomcat(这里是windows环境所以使用startup.bat)，通过startup.bat的启动代码(跳转到catalina.bat的start逻辑，找到Bootstrap的main方法)，我们知道Bootstrap的main方法就是tomact的启动方法。

在Bootstrap的main方法中，主要逻辑是创建了一个Bootstrap对象作为操作的主体对象，之后init创建了catalina对象，又分别执行了load方法和start方法，所以tomcat实际上就是一个Bootstrap实例，而Bootstrap实例实际操作的是Catalina实例。

#### 一、tomcat组件一览

通过Bootstrap的main方法，可以知道tomcat的主要启动逻辑都在daemon.load()和daemon.start()中，而Bootstrap的load和start方法实际上调用的是Catalina实例中的load()和start()。

![image-20200727120408626](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103701.png)

在catalina.load)()中有三个关键点：

- catalina创建了digester对象，digester实例同时是一个自定义xml解析对象，会使用sax方式读取server.xml，在此期间会依次实例化server、service、engine、host等组件对象。

- disester对象完成各组件的实例化后，执行了server的init方法完成组件的初始化工作，该方法会依次嵌套执行service、engine、Connetor的init方法

- 在init初始化方法执行完成后，会执行server的start方法，该方法会依次嵌套执行service、engine、connetor的start方法。启动端口监听和servlet文件部署以及url和servlet路径的映射。

  ![image-20200727155823141](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103704.png)



#### 二、tomcat执行套路

**套路一**：digester实例通过遍历server.xml依次实例化子组件对象并为组件设置监听对象

```java
//org.apache.tomcat.util.digester.Digester#parse(org.xml.sax.InputSource)
public Object parse(InputSource input) throws IOException, SAXException {
    configure();
    getXMLReader().parse(input);
    return root;
}
```

digester实例有个Rules属性列表，在创建digester实例时会将各种Rule加入Rules列表中，并按照pattern字段进行分类。

```java
//示例：org.apache.catalina.startup.Catalina#createStartDigester
digester.addObjectCreate(prefix + "Host","org.apache.catalina.core.StandardHost","className");
//↑添加创建组件规则(实例化组件,并压入digester.stack栈顶)addRule(pattern, new ObjectCreateRule(className, attributeName));
digester.addSetProperties(prefix + "Host");
//↑添加设置组件属性规则(将属性设置到digester.stack栈顶组件中)addRule(pattern, new SetPropertiesRule());
digester.addRule(prefix + "Host",new CopyParentClassLoaderRule());
digester.addRule(prefix + "Host",new LifecycleListenerRule("org.apache.catalina.startup.HostConfig",
                  "hostConfigClass"));
//↑直接加Rule(LifecycleListenerRule.begin()会给digester.stack栈顶组件添加监听对象)

digester.addSetNext(prefix + "Host","addChild","org.apache.catalina.Container");
//↑添加组件关联规则(取digester.stack栈顶前两个组件,将栈顶组件添加到次栈顶组件中)addRule(pattern, new SetNextRule(methodName, paramType));
digester.addCallMethod(prefix + "Host/Alias","addAlias", 0);
//↑添加方法触发规则addRule(pattern, new CallMethodRule(methodName, paramCount));

//========================
//org.apache.tomcat.util.digester.Digester#addRule
public void addRule(String pattern, Rule rule) {
    rule.setDigester(this);
    getRules().add(pattern, rule);
}

//RulesBase为Digester属性(org.apache.tomcat.util.digester.RulesBase#add
public void add(String pattern, Rule rule) {
    // to help users who accidentally add '/' to the end of their patterns
    int patternLength = pattern.length();
    if (patternLength>1 && pattern.endsWith("/")) {
        pattern = pattern.substring(0, patternLength-1);
    }

    List<Rule> list = cache.get(pattern);
    if (list == null) {
        list = new ArrayList<>();
        //按照pattern进行分类
        cache.put(pattern, list);
    }
    //添加到list列表中
    list.add(rule);
    //添加到rules列表中
    rules.add(rule);
    if (this.digester != null) {
        rule.setDigester(this.digester);
    }
    if (this.namespaceURI != null) {
        rule.setNamespaceURI(this.namespaceURI);
    }
}
```

对象在每次遍历xml元素时，根据xml元素名称去匹配Rules的pattern字段，得到匹配到的Rules列表，在startElement中依次执行Rule.begin()、在endElement中依次执行Rule.body()和Rule.end()完成组件的实例化和设置监听事件。(如ObjectCreateRule一般是第一个执行的Rule，begin()会实例化组件对象，end()会将组件对象从digester.stack中弹出。LifecycleListenerRule.begin()会将监听对象加入到组件中)

```java
public void startElement(String namespaceURI, String localName, String qName, Attributes list)
        throws SAXException {
    boolean debug = log.isDebugEnabled();
    // Parse system properties
    list = updateAttributes(list);
    // Save the body text accumulated for our surrounding element
    bodyTexts.push(bodyText);
    bodyText = new StringBuilder();
    // the actual element name is either in localName or qName, depending
    // on whether the parser is namespace aware
    String name = localName;
    if ((name == null) || (name.length() < 1)) {
        name = qName;
    }

    // Compute the current matching rule
    StringBuilder sb = new StringBuilder(match);
    if (match.length() > 0) {
        sb.append('/');
    }
    sb.append(name); //根据每次xml节点的名称拼接成匹配url
    match = sb.toString();

    // Fire "begin" events for all relevant rules(根据namespaceURI匹配获取的Rule规则列表，有顺序规则)
    List<Rule> rules = getRules().match(namespaceURI, match);
    matches.push(rules);
    if ((rules != null) && (rules.size() > 0)) {
        for (Rule value : rules) {
            try {
                Rule rule = value;
                if (debug) {
                    log.debug("  Fire begin() for " + rule);
                }
                //依次执行begin方法
                rule.begin(namespaceURI, name, list);
            } catch (Exception e) {
                log.error("Begin event threw exception", e);
                throw createSAXException(e);
            } catch (Error e) {
                log.error("Begin event threw error", e);
                throw e;
            }
        }
    } else {
        if (debug) {
            log.debug("  No rules found matching '" + match + "'.");
        }
    }

}

//=========================
//org.apache.tomcat.util.digester.ObjectCreateRule#begin
public void begin(String namespace, String name, Attributes attributes)
        throws Exception {
    // Identify the name of the class to instantiate
    String realClassName = className;
    if (attributeName != null) {
        String value = attributes.getValue(attributeName);
        if (value != null) {
            realClassName = value;
        }
    }
    // Instantiate the new object and push it on the context stack(实例化Rule中的实际对象)
    Class<?> clazz = digester.getClassLoader().loadClass(realClassName);
    Object instance = clazz.getConstructor().newInstance();
    //将创建组件压入digester的stack栈中
    digester.push(instance);
}

//endElement()中执行org.apache.tomcat.util.digester.ObjectCreateRule#end
public void end(String namespace, String name) throws Exception {
    Object top = digester.pop(); //将digester的stack栈顶元素出栈
}


//org.apache.catalina.startup.LifecycleListenerRule#begin
public void begin(String namespace, String name, Attributes attributes)
    throws Exception {
    //从digester的stack栈对象中获取栈顶对象
    Container c = (Container) digester.peek();
    Container p = null;
    Object obj = digester.peek(1);
    if (obj instanceof Container) {
        p = (Container) obj;
    }
    String className = null;
    // Check the container for the specified attribute
    if (attributeName != null) {
        String value = attributes.getValue(attributeName);
        if (value != null)
            className = value;
    }
    // Check the container's parent for the specified attribute
    if (p != null && className == null) {
        String configClass =
            (String) IntrospectionUtils.getProperty(p, attributeName);
        if (configClass != null && configClass.length() > 0) {
            className = configClass;
        }
    }
    // Use the default
    if (className == null) {
        className = listenerClass;
    }
    // Instantiate a new LifecycleListener implementation object
    //(将LifecycleListenerRule中的监听对象实例化，并赋值到对应组件中)
    Class<?> clazz = Class.forName(className);
    LifecycleListener listener = (LifecycleListener) clazz.getConstructor().newInstance();

    // Add this LifecycleListener to our associated component
    c.addLifecycleListener(listener);
}
```

在server.xml解析完成后server、service、engine、connector等组件均完成实例化，且依次嵌套到父组件中。在之后的逻辑中会操作最外层的server组件并依次执行init方法和start方法。

**套路二**：server各组件共同实现一套LifeCycle接口，一方面实现各组件生命周期的统一管理，另一方面实现了初始化和容器启动逻辑的同一管理(执行init方法、start方法和监听对象的触发)

![image-20200730211341818](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103712.png)

在`org.apache.catalina.startup.Catalina#load()`中执行`getServer().init();`开启组件的初始化流程，大概逻辑是父组件执行init方法后回调到initInternal()方法中，在initInternal()方法中调用子组件的init方法，再次回调到子组件的initInternal()方法中。这样依次初始化所有的组件，详细逻辑如下图所示。

![tomcat源码-init初始化逻辑](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103715.jpg)



除了共用LifeCycle接口外，engine、host、context、Wrapper组件还共用了Container接口，作为存储项目servlet的容器，都继承了`org.apache.catalina.core.ContainerBase`作为基础父类。



#### 三、servlet请求解析

tomcat使用NioEndpoint作为端口请求监听对象，而实际的socket接受对象为NioEndpoint类中的org.apache.tomcat.util.net.NioEndpoint.SocketProcessor。当监听端口发现请求时会执行doRun()方法来处理请求数据。

```java
protected class SocketProcessor extends SocketProcessorBase<NioChannel> {

    public SocketProcessor(SocketWrapperBase<NioChannel> socketWrapper, SocketEvent event) {
        super(socketWrapper, event);
    }

    @Override
    protected void doRun() {
        //从Wrapper拿到socket连接对象(通道对象)
        NioChannel socket = socketWrapper.getSocket();
		//...
        //通过AbstractProtocol.ConnectionHandler来处理socket中的请求
        state = getHandler().process(socketWrapper, event);
        //...
    }
}
```

在AbstractProtocol.ConnectionHandler中，创建了Http11Processor应用对象，来进一步处理socket请求：

```java
@Override
public SocketState process(SocketWrapperBase<S> wrapper, SocketEvent status) {
    if (getLog().isDebugEnabled()) {
        getLog().debug(sm.getString("abstractConnectionHandler.process",
                wrapper.getSocket(), status));
    }
    //wrapper为空则关闭连接
    if (wrapper == null) {
        // Nothing to do. Socket has been closed.
        return SocketState.CLOSED;
    }
    //取出socket对象
    S socket = wrapper.getSocket();

    ContainerThreadMarker.set();

    //创建Http11Processor
        if (processor == null) {
            processor = getProtocol().createProcessor();
            register(processor);
            if (getLog().isDebugEnabled()) {
                getLog().debug(sm.getString("abstractConnectionHandler.processorCreate", processor));
            }
        }

        processor.setSslSupport(
                wrapper.getSslSupport(getProtocol().getClientCertProvider()));

        // Associate the processor with the connection
        connections.put(socket, processor);

        SocketState state = SocketState.CLOSED;
        do {//使用应用层processor处理socket(如http11processor)
            //...
            state = processor.process(wrapper, status);
            //...
        }while(state == SocketState.UPGRADING);
    //...
}
```

Http11Processor就是将请求初步封装成request和response的处理类，这里会创建org.apache.coyote.Request和response，将请求数据置入其中，之后会将requset和response交给CoyoteAdapter解析。

```java
@Override
public SocketState service(SocketWrapperBase<?> socketWrapper)
    throws IOException {
    RequestInfo rp = request.getRequestProcessor();
    rp.setStage(org.apache.coyote.Constants.STAGE_PARSE);

    // Setting up the I/O
    setSocketWrapper(socketWrapper);

    // Flags
    keepAlive = true;
    openSocket = false;
    readComplete = true;
    boolean keptAlive = false;
    SendfileState sendfileState = SendfileState.DONE;

    //start========解析封装原生request对象和初步的response对象，之后会传入adapter适配
    while (!getErrorState().isError() && keepAlive && !isAsync() && upgradeToken == null &&
            sendfileState == SendfileState.DONE && !endpoint.isPaused()) {

        //处理response
        if (isConnectionToken(request.getMimeHeaders(), "upgrade")) {
            // Check the protocol
            String requestedProtocol = request.getHeader("Upgrade");

            UpgradeProtocol upgradeProtocol = protocol.getUpgradeProtocol(requestedProtocol);
            if (upgradeProtocol != null) {
                if (upgradeProtocol.accept(request)) {
                    // TODO Figure out how to handle request bodies at this
                    // point.
                    response.setStatus(HttpServletResponse.SC_SWITCHING_PROTOCOLS);
                    response.setHeader("Connection", "Upgrade");
                    response.setHeader("Upgrade", requestedProtocol);
                    action(ActionCode.CLOSE,  null);
                    getAdapter().log(request, response, 0);

                    InternalHttpUpgradeHandler upgradeHandler =
                            upgradeProtocol.getInternalUpgradeHandler(
                                    getAdapter(), cloneRequest(request));
                    UpgradeToken upgradeToken = new UpgradeToken(upgradeHandler, null, null);
                    action(ActionCode.UPGRADE, upgradeToken);
                    return SocketState.UPGRADING;
                }
            }
        }
		//处理request
        if (getErrorState().isIoAllowed()) {
            // Setting up filters, and parse some request headers
            rp.setStage(org.apache.coyote.Constants.STAGE_PREPARE);
            try {
                prepareRequest();
            } catch (Throwable t) {
                ExceptionUtils.handleThrowable(t);
                if (log.isDebugEnabled()) {
                    log.debug(sm.getString("http11processor.request.prepare"), t);
                }
                // 500 - Internal Server Error
                response.setStatus(500);
                setErrorState(ErrorState.CLOSE_CLEAN, t);
            }
        }

        if (maxKeepAliveRequests == 1) {
            keepAlive = false;
        } else if (maxKeepAliveRequests > 0 &&
                socketWrapper.decrementKeepAlive() <= 0) {
            keepAlive = false;
        }

        //end========解析封装原生request对象和初步的response对象，之后会传入adapter适配

        rp.setStage(org.apache.coyote.Constants.STAGE_SERVICE);
        //将request和response交给CoyoteAdapter进一步封装成servletRequest和serlvetResponse
        getAdapter().service(request, response);
        //...
}
```

CoyoteAdapter是处理request最核心的逻辑类，它完成了将org.apache.coyote.Request和response转变为org.apache.catalina.connector.Request和response对象，并通过mapElememt机制将请求url关联映射到standardWrapper(servlet)，之后执行standardWrapper的service方法来完成servlet的执行。

```java
@Override
public void service(org.apache.coyote.Request req, org.apache.coyote.Response res)
        throws Exception {

    //这个resquest和response是HttpServletRequest和HttpServletResponse
    Request request = (Request) req.getNote(ADAPTER_NOTES);
    Response response = (Response) res.getNote(ADAPTER_NOTES);

    if (request == null) {
        // Create objects(封装原生请求对象)
        request = connector.createRequest();
        request.setCoyoteRequest(req);
        response = connector.createResponse();
        response.setCoyoteResponse(res);

        // Link objects
        request.setResponse(response);
        response.setRequest(request);

        // Set as notes
        req.setNote(ADAPTER_NOTES, request);
        res.setNote(ADAPTER_NOTES, response);

        // Set query string encoding
        req.getParameters().setQueryStringCharset(connector.getURICharset());
    }

    if (connector.getXpoweredBy()) {
        response.addHeader("X-Powered-By", POWERED_BY);
    }

    boolean async = false;
    boolean postParseSuccess = false;

    req.getRequestProcessor().setWorkerThreadName(THREAD_NAME.get());

    try {
        // Parse and set Catalina and configuration specific
        // request parameters
        //postParseRequest会根据请求url相关信息处理请求数据(host->context->wrapper(servlet))
        postParseSuccess = postParseRequest(req, request, res, response);
        if (postParseSuccess) {
            //check valves if we support async
            request.setAsyncSupported(
                    connector.getService().getContainer().getPipeline().isAsyncSupported());
            // Calling the container
            //根据上述的postParseSuccess容器找到servlet进行回调service方法
            connector.getService().getContainer().getPipeline().getFirst().invoke(
                    request, response);
        }
    }
}
```

整体逻辑图如下：

![tomcat源码-url请求servlet](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103723.jpg)