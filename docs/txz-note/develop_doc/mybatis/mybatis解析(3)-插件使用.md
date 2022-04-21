mybatis解析(3)-插件使用

#### 一、mybatis插件介绍

mybatis在设计时预留了一套插件扩展机制，方便开发者在mapper对象进行sql操作时可以对curd过程进行业务扩展。



#### 二、如何使用

这里业务扩展的实质就是一个拦截器，先来看一个插件实例：

```java
//说明拦截位置是Executor类中方法为update(StatementHandler s， Object o)
//拦截对象type共有四个：
//ParameterHandler
//ResultSetHandler
//StatementHandler
//Executor
//以上对象的方法均可拦截
@Intercepts({
        @Signature(type = Executor.class, method = "update", args = {MappedStatement.class, Object.class})
})
//使用@Component将拦截器注册为bean
@Component
public class TestInterceptor implements Interceptor {

    //invocation为被拦截方法对象的集合有三个参数
    //参数一target为被拦截方法所在的对象或下个拦截器对象
    //参数二method为被拦截方法
    //参数三args为被拦截方法的入参
    @Override
    public Object intercept(Invocation invocation) throws Throwable {
        System.out.println("被拦截方法执行前执行======");
        Object obj = invocation.proceed();
        System.out.println("被拦截方法执行后执行======");
        return obj;
    }

    @Override
    public Object plugin(Object o) {
        System.out.println("=====生成拦截对象和被拦截对象的的代理对象");
        return Plugin.wrap(o, this);
    }

    @Override
    public void setProperties(Properties properties) {
    }
}
```

加入上述的拦截器后，在使用mapper进行update操作前，会触发intercept方法的执行，

我们可以在这里进行业务扩展，之后执行invocation.proceed()会继续流转update流程(若存在多个Interceptor拦截时，invocation.proceed()执行下个拦截器的intercept方法，直到最后一个拦截器的invocation.proceed()才会继续流转update流程)。



#### 三、原理分析

mybatis的核心对象是org.apache.ibatis.session.Configuration，在项目启动时，会将所有的Interceptor对象实例化添加到Configuration对象中的InterceptorChain：

```java
//示例：实例化Interceptor对象
//org.apache.ibatis.builder.xml.XMLConfigBuilder#pluginElement
private void pluginElement(XNode parent) throws Exception {
  if (parent != null) {
    for (XNode child : parent.getChildren()) {
      String interceptor = child.getStringAttribute("interceptor");
      Properties properties = child.getChildrenAsProperties();
      Interceptor interceptorInstance = (Interceptor) resolveClass(interceptor).getDeclaredConstructor().newInstance();
      interceptorInstance.setProperties(properties);
      configuration.addInterceptor(interceptorInstance); //加入列表
    }
  }
}

//org.apache.ibatis.session.Configuration
public void addInterceptor(Interceptor interceptor) {
  interceptorChain.addInterceptor(interceptor);
}
```

这样我们后期就可以通过Configuration对象到拦截器列表了，但是拦截器之间的是如何形成责任链模式的呢？下面来看下interceptorChain的逻辑：

```java
public class InterceptorChain {

  private final List<Interceptor> interceptors = new ArrayList<>();

  //这里使用责任链模式将interceptors处理成链式结构
  //target参数作为被代理对象，加入到第一个interceptor中。最后返回的target是interceptors列表中最后一个元素创建的代理对象(所以拦截器执行顺序是先进后出的栈结构)
  public Object pluginAll(Object target) {
    for (Interceptor interceptor : interceptors) {
      target = interceptor.plugin(target);
    }
    return target;
  }

  public void addInterceptor(Interceptor interceptor) {
    interceptors.add(interceptor);
  }

  public List<Interceptor> getInterceptors() {
    return Collections.unmodifiableList(interceptors);
  }

}

//org.apache.ibatis.plugin.Interceptor
public interface Interceptor {

  Object intercept(Invocation invocation) throws Throwable;

  default Object plugin(Object target) {
     //这里this(interceptor拦截器对象)和target(被代理对象)会作为参数创建Plugin代理对象
    return Plugin.wrap(target, this);
  }

  default void setProperties(Properties properties) {
    // NOP
  }

}
```

这里的pluginAll方法主要逻辑是创建链式拦截器代理对象，若存在多个拦截器，则被代理对象作为参数加入第一个interceptor中，返回的代理对象作为第二个interceptor的参数继续进行代理对象的创建，最后形成一个栈式结构。

与此同时，pluginAll也是创建被拦截对象的入口，上文中说的拦截对象有四个(ParameterHandler、ResultSetHandler、StatementHandler、Executor)，是因为只有这四个对象使用了pluginAll创建了链式的拦截器代理对象，代码如下：

```java
//org.apache.ibatis.session.Configuration
public ParameterHandler newParameterHandler(MappedStatement mappedStatement, Object parameterObject, BoundSql boundSql) {
  ParameterHandler parameterHandler = mappedStatement.getLang().createParameterHandler(mappedStatement, parameterObject, boundSql);
  parameterHandler = (ParameterHandler) interceptorChain.pluginAll(parameterHandler);  //代理
  return parameterHandler;
}

public ResultSetHandler newResultSetHandler(Executor executor, MappedStatement mappedStatement, RowBounds rowBounds, ParameterHandler parameterHandler,
    ResultHandler resultHandler, BoundSql boundSql) {
  ResultSetHandler resultSetHandler = new DefaultResultSetHandler(executor, mappedStatement, parameterHandler, resultHandler, boundSql, rowBounds);
  resultSetHandler = (ResultSetHandler) interceptorChain.pluginAll(resultSetHandler);//代理
  return resultSetHandler;
}

public StatementHandler newStatementHandler(Executor executor, MappedStatement mappedStatement, Object parameterObject, RowBounds rowBounds, ResultHandler resultHandler, BoundSql boundSql) {
  StatementHandler statementHandler = new RoutingStatementHandler(executor, mappedStatement, parameterObject, rowBounds, resultHandler, boundSql);
  statementHandler = (StatementHandler) interceptorChain.pluginAll(statementHandler);//代理
  return statementHandler;
}

public Executor newExecutor(Transaction transaction, ExecutorType executorType) {
  executorType = executorType == null ? defaultExecutorType : executorType;
  executorType = executorType == null ? ExecutorType.SIMPLE : executorType;
  Executor executor;
  if (ExecutorType.BATCH == executorType) {
    executor = new BatchExecutor(this, transaction);
  } else if (ExecutorType.REUSE == executorType) {
    executor = new ReuseExecutor(this, transaction);
  } else {
    executor = new SimpleExecutor(this, transaction);
  }
  if (cacheEnabled) {
    executor = new CachingExecutor(executor);
  }
  executor = (Executor) interceptorChain.pluginAll(executor);//代理
  return executor;
}
```

链式结构形成了，当执行怎么进行链式调用呢？答案在Plugin中：

```java
public class Plugin implements InvocationHandler {

  private final Object target;
  private final Interceptor interceptor;
  private final Map<Class<?>, Set<Method>> signatureMap;

  private Plugin(Object target, Interceptor interceptor, Map<Class<?>, Set<Method>> signatureMap) {
    this.target = target;
    this.interceptor = interceptor;
    this.signatureMap = signatureMap;
  }
	//将被代理对象target、拦截器对象interceptor和拦截目标信息signatureMap作为参数创建Plugin代理对象并返回
  public static Object wrap(Object target, Interceptor interceptor) {
    Map<Class<?>, Set<Method>> signatureMap = getSignatureMap(interceptor);
    Class<?> type = target.getClass();
    Class<?>[] interfaces = getAllInterfaces(type, signatureMap);
    if (interfaces.length > 0) {
      return Proxy.newProxyInstance(
          type.getClassLoader(),
          interfaces,
          new Plugin(target, interceptor, signatureMap));
    }
    return target;
  }

  @Override
  public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
    try {
      Set<Method> methods = signatureMap.get(method.getDeclaringClass());
      //如果当前方法是拦截目标方法，则进行链式拦截器调用 
      if (methods != null && methods.contains(method)) {
        //执行拦截器的intercept方法
        //参数是Invocation(下一个interceptor或目前方法对象, 当前执行的方法, 入参)
        return interceptor.intercept(new Invocation(target, method, args));
      }
      return method.invoke(target, args);
    } catch (Exception e) {
      throw ExceptionUtil.unwrapThrowable(e);
    }
  }
}

//org.apache.ibatis.plugin.Invocation
public class Invocation {

  private final Object target;
  private final Method method;
  private final Object[] args;

  public Invocation(Object target, Method method, Object[] args) {
    this.target = target;
    this.method = method;
    this.args = args;
  }
	
    //反射调用target的method方法
  public Object proceed() throws InvocationTargetException, IllegalAccessException {
    return method.invoke(target, args);
  }

}
```

如文初实例对于Executor#update(...)方法的拦截，在进行sql更新时实际使用的executor是一个被Plugin包裹的代理对象，当代理对象executor执行update方法时，触发Plugin对象的invoke方法，因为当前方法是拦截器的目标方法，所以执行interceptor.intercept(...)进入拦截器进行业务扩展。

```
executor = (Executor) interceptorChain.pluginAll(executor);
```

拦截器执行invocation.proceed();时，此时的target是下一个拦截器的对象或是拦截目标对象(最后执行)。

#### 四、总结

![image-20210323144825522](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20210323144859.png)



#### 五、PageHelp分页插件

PageHelp.startPage(1, 10);

这句话会在给当前线程创建一个ThreadLocal对象，存储一个Page对象，记录分页信息供分页拦截器使用。

通过Mapper接口查询数据时，会执行PageHelp的拦截器，拦截器判断是否能从ThreadLocal中获取分页信息，能获取，则会改写当前查询语句(增加查询count(1)总页数的逻辑)，并返回一个Page对象(继承Arraylist)，这样可以直接当list用，也可以当Page用(获取total属性)

mybatis-plus也是使用的拦截器实现的分页查询，两者的区别可以参考：

https://www.cnblogs.com/rrong/p/13629550.html

六、Mybatis的一级缓存和二级缓存

**一级缓存**是session内部的的一个map缓存，也就是一个session内部，对同一个sql进行多次数据查询时，仅在第一次查询时会走数据库，之后的查询会直接从缓存中获取，过程中其他的session对象的操作不会影响当前session对象。

**缓存何时清空**：在一个session内执行insert、update、delete命令时，会清空掉当前缓存

**缓存匹配规则**：CacheKey对象相等就认为两次查询相同，可以获取到缓存；具体匹配规则是：

```java
//两次查询的statementID+offset+limit+sql+params相同，就会命中缓存
CacheKey cacheKey = new CacheKey();
cacheKey.update(ms.getId());   //statementID
cacheKey.update(rowBounds.getOffset());  //offset
cacheKey.update(rowBounds.getLimit());    //limit
cacheKey.update(boundSql.getSql());    //查询sql
//后面是update了sql中带的参数
cacheKey.update(value);    //查询参数
```

**缺陷**：若两个session对同一张表进行操作，sessionA进行2次相同的查询，sessionB进行1次数据更新，有可能会出现sessionA首次查询后，cpu切换到sessionB进行了更新操作，又切换sessionA进行第二次查询，此时sessionA会因为缓存，查询的还是旧的数据，无法获取sessionB更新后的新数据

**建议**：一级缓存默认是开启的，建立关闭一级缓存，将localCacheScope设置为STATEMENT

```xml
#默认是SESSION级别
<setting name="localCacheScope" value="STATEMENT"/>
或者
mybatis.configuration.local-cache-scope=statement
或者
在mapper.xml中给查询片段设置flushCache=true
```

**二级缓存**是跨session的共享缓存，也就是多个session对象进行相同的查询时，从二次查询开始，都会从二级缓存中获取到缓存数据。二级缓存是Mapper级别的缓存，所有session都共享这个缓存

**二级缓存和一级缓存关系**：先执行二级缓存后执行一级缓存，因为二级缓存使用了CacheExecutor对象包装了SimpleExecutor基础对象，会在查询先后进行二级缓存的命中和存储。

**缓存何时清空**：任何一个session内执行insert、update、delete命令时，会清空掉当前缓存

**缺陷**：一个sessionA在进行联表查询时，与此同时，某个sessionB对其中的关联表进行了insert、update、delete命令，此时只会清空关联表mapper的二级缓存，原sessionA的主表mapper的二级缓存还是旧数据。(处理：在关联表mapper.xml中使用Cache ref标签关联主表，这样在关联表进行增删改时就会两个mapper二级缓存一起清理，但是这样在联表较多的情况下对缓存影响较大)

**开启方式**：在mybatis中开启配置：

```xml
#开启二级缓存
<setting name="cacheEnabled" value="true"/>

#在mapper.xml中增加缓存标记，表示当前mapper会创建二级缓存
<cache/> 

#二级缓存关联，在进行缓存更新时 ，视为一个整体
<cache-ref namespace="mapper.StudentMapper"/>
```

**建议**：不使用二级缓存

总结，mybatis最好不要开启缓存功能，作为单纯的ORM框架最合适

https://tech.meituan.com/2018/01/19/mybatis-cache.html