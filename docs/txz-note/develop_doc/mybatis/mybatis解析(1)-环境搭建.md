mybatis解析(1)-环境搭建

### 一、mybatis解析

#### **1\. 项目下载**

到github中下载mybatis相关源码项目

mybatis源码：https://github.com/mybatis/mybatis-3

mybatis parent： https://github.com/mybatis/parent

#### 2\. 项目配置

(本人项目jdk和特性配置为：jdk11)

在idea中导入mybatis源码项目，更新maven下载相关依赖jar包，发现mybatis-parent父依赖无法下载

```xml
<parent>
  <groupId>org.mybatis</groupId>
  <artifactId>mybatis-parent</artifactId>
  <version>32-SNAPSHOT</version>
  <relativePath />
</parent>
```

通过查询得知解决办法：将mybatis parent项目导入idea，执行maven命令install，将parent依赖写入本地maven仓库。之后再回到mybatis源码项目中更新依赖，发现问题得到解决。

#### 3\. 项目测试

测试执行test中的集成测试类，如org.apache.ibatis.submitted.maptypehandler.MapTypeHandlerTest。

执行后发现无报错现象，即项目可正常运行。

常见的查询操作如下所示：

```java
//创建sqlSessionFactory对象，解析存储mapper信息
SqlSessionFactory sqlSessionFactory = new SqlSessionFactoryBuilder().build(reader);
//通过sqlSessionFactory创建sqlSession对象，该对象存有mapper信息、事务配置、数据库连接信息、sql执行对象executor等等
SqlSession sqlSession = sqlSessionFactory.openSession();
//通过sqlSession创建Mapper接口类的代理对象(通过MapperProxyFactory创建MapperProxy)
Mapper mapper = sqlSession.getMapper(Mapper.class);
//调用代理对象方法执行代理对象的invoke方法，invoke方法会通过当前方法路径名称匹配sqlSessionFactory中解析的mapperStatement对象(获取sql)，之后将参数设置到sql中进行查询(最底层还是jdbc的基础操作逻辑)，查询完成将查询结果转换成resultMap类型返回给上层逻辑
User user = mapper.getUser(1, "User1");
```

#### 4\. 操作逻辑

1.  sqlSessionFactory = new SqlSessionFactoryBuilder().build(reader)是创建mybatis的核心操作对象configuration，创建过程会将mapper中的sql信息封装成mapperStatement对象，供之后curd使用，同时每个mapper会创建代理对象MapperProxyFactory
2.  sqlSession = sqlSessionFactory.openSession()主要创建了sqlsession对象，该对象包括了configuration、executor、事务、数据库连接信息等
3.  使用mappe = sqlSession.getMapper(Mapper.class)会获取到mapper接口的实际代理对象mapperProxy（由mapperProxyFactory.newInstance(sqlSession)创建）
4.  User user = mapper.getUser(1, "User1")执行mapper的方法，触发mapperProxy代理对象的invoke方法，invoke方法通过当前方法的路径信息、返回类型从configuration中匹配mapperStatement对象和resultMap对象信息，之后根据数据库连接信息创建sql环境，将getUser方法的参数进行封装并执行mapperStatement中的sql，得到结果转换为resultMap对象返回。

#### 5.springboot整合mybatis原理

在springboot项目中整合mybatis中间件需要引入依赖：

```xml
<dependency>
    <groupId>org.mybatis.spring.boot</groupId>
    <artifactId>mybatis-spring-boot-starter</artifactId>
    <version>1.3.1</version>
</dependency>
```

整合mybatis中间件，主要的工作有两个：一是让spring来创建管理SqlSessionFactory对象，二是将Mapper接口的代理对象注册到IOC容器中用于自动注入。

**1.来看第一个spring来创建管理SqlSessionFactory的原理：**

在mybatis-spring-boot-starter启动组件中，从org.mybatis.spring.boot.autoconfigure.MybatisAutoConfiguration配置类开启整合工作，sqlSessionFactory对象通过@Bean进行注册创建

```java
//org.mybatis.spring.boot.autoconfigure.MybatisAutoConfiguration#sqlSessionFactory
@Bean
@ConditionalOnMissingBean
public SqlSessionFactory sqlSessionFactory(DataSource dataSource) throws Exception {
    //创建SqlSessionFactoryBean对象
    SqlSessionFactoryBean factory = new SqlSessionFactoryBean();
    factory.setDataSource(dataSource);
    factory.setVfs(SpringBootVFS.class);
    if (StringUtils.hasText(this.properties.getConfigLocation())) {
        factory.setConfigLocation(this.resourceLoader.getResource(this.properties.getConfigLocation()));
    }

    org.apache.ibatis.session.Configuration configuration = this.properties.getConfiguration();
    if (configuration == null && !StringUtils.hasText(this.properties.getConfigLocation())) {
        configuration = new org.apache.ibatis.session.Configuration();
    }
    //...

    if (!ObjectUtils.isEmpty(this.properties.resolveMapperLocations())) {
        factory.setMapperLocations(this.properties.resolveMapperLocations());
    }

    return factory.getObject();
}
```

spring中创建SqlSessionFactoryBean时，会执行InitializingBean接口的afterPropertiesSet()方法，

```java
public void afterPropertiesSet() throws Exception {
    //解析配置信息mybatis.mapper-locations=classpath*:com/plaz/mapping/*Mapper.xml
    //解析所有mapper.xml为MapperStatement对象，并赋值到sqlSessionFactory的列表中
    this.sqlSessionFactory = this.buildSqlSessionFactory();
}
```

**2.将Mapper接口的代理对象注册到IOC容器中原理**

在springboot启动类上加`@MapperScan(basePackages = {"com.plaz.dao"})`注解，注解包含了注册器`@Import({MapperScannerRegistrar.class})`，注册器会在spring启动时执行registerBeanDefinitions()方法。

```java
//org.mybatis.spring.annotation.MapperScannerRegistrar#registerBeanDefinitions
public void registerBeanDefinitions(AnnotationMetadata importingClassMetadata, BeanDefinitionRegistry registry) {
    AnnotationAttributes annoAttrs = AnnotationAttributes.fromMap(importingClassMetadata.getAnnotationAttributes(MapperScan.class.getName()));
    ClassPathMapperScanner scanner = new ClassPathMapperScanner(registry);

    //。。。
    scanner.registerFilters();
    //将@MapperScan注解路径下的mapper接口类注册成beanDefinition对象(设置其实例化class为MapperFactoryBean.getClass(),实例化使用单参构造创建，参数为mpper类路径)
    scanner.doScan(StringUtils.toStringArray(basePackages));
}
```

这些Mapper的beanDefinition对象会在之后，全部实例化成MapperFactoryBean代理对象，所以我们在service层注入的Mapper接口实例，实际上是MapperFactoryBean代理对象。来看下MapperFactoryBean的逻辑：

```java
public class MapperFactoryBean<T> extends SqlSessionDaoSupport implements FactoryBean<T> {
    //mapperInterface是实际的mapper接口类class
    private Class<T> mapperInterface;
    private boolean addToConfig = true;
    public MapperFactoryBean() {
    }

    public MapperFactoryBean(Class<T> mapperInterface) {
        this.mapperInterface = mapperInterface;
    }

    public T getObject() throws Exception {
        //注入时返回mapper的代理对象(this.getSqlSession()在父类中，创建时为null，只有在被注入时通过set方法赋值)
        return this.getSqlSession().getMapper(this.mapperInterface);
    }
    //...
}


public <T> T getMapper(Class<T> type, SqlSession sqlSession) {
    final MapperProxyFactory<T> mapperProxyFactory = (MapperProxyFactory<T>) knownMappers.get(type);
    if (mapperProxyFactory == null) {
      throw new BindingException("Type " + type + " is not known to the MapperRegistry.");
    }
    try {
      return mapperProxyFactory.newInstance(sqlSession);
    } catch (Exception e) {
      throw new BindingException("Error getting mapper instance. Cause: " + e, e);
    }
  }

public class MapperProxyFactory<T> {

  private final Class<T> mapperInterface;
  private final Map<Method, MapperMethodInvoker> methodCache = new ConcurrentHashMap<>();

  public MapperProxyFactory(Class<T> mapperInterface) {
    this.mapperInterface = mapperInterface;
  }

  public Class<T> getMapperInterface() {
    return mapperInterface;
  }

  public Map<Method, MapperMethodInvoker> getMethodCache() {
    return methodCache;
  }

  @SuppressWarnings("unchecked")
  protected T newInstance(MapperProxy<T> mapperProxy) {
    return (T) Proxy.newProxyInstance(mapperInterface.getClassLoader(), new Class[] { mapperInterface }, mapperProxy);
  }

  public T newInstance(SqlSession sqlSession) {
  //MapperProxy是一个实践InvocationHandler接口的中间类
    final MapperProxy<T> mapperProxy = new MapperProxy<>(sqlSession, mapperInterface, methodCache);
    return newInstance(mapperProxy);
  }

}
```

#### 3.其他

在测试代码中使用了sqlSessionFactory.openSession()来创建sqlSession对象(DefaultSqlSession)，而在整合到spring中后，可以省略此操作，直接使用sqlSessionTemplate来代理实例化sqlSession对象

```java
//org.mybatis.spring.boot.autoconfigure.MybatisAutoConfiguration
@Bean
@ConditionalOnMissingBean
public SqlSessionTemplate sqlSessionTemplate(SqlSessionFactory sqlSessionFactory) {
    ExecutorType executorType = this.properties.getExecutorType();
    return executorType != null ? new SqlSessionTemplate(sqlSessionFactory, executorType) : new SqlSessionTemplate(sqlSessionFactory);
}

//org.mybatis.spring.SqlSessionTemplate#SqlSessionTemplate(...)
public SqlSessionTemplate(SqlSessionFactory sqlSessionFactory, ExecutorType executorType, PersistenceExceptionTranslator exceptionTranslator) {
    Assert.notNull(sqlSessionFactory, "Property 'sqlSessionFactory' is required");
    Assert.notNull(executorType, "Property 'executorType' is required");
    this.sqlSessionFactory = sqlSessionFactory;
    this.executorType = executorType;
    this.exceptionTranslator = exceptionTranslator;
    this.sqlSessionProxy = (SqlSession)Proxy.newProxyInstance(SqlSessionFactory.class.getClassLoader(), new Class[]{SqlSession.class}, new SqlSessionTemplate.SqlSessionInterceptor());
}
```

sqlSessionTemplate实际上是对sqlSession对象一次封装，我们通过sqlSessionTemplate来

```java
public class SqlSessionTemplate implements SqlSession {
        public SqlSessionTemplate(SqlSessionFactory sqlSessionFactory, ExecutorType executorType, PersistenceExceptionTranslator exceptionTranslator) {
        //...
        //sqlSessionProxy对象是一个动态代理类，中间对象是SqlSessionInterceptor()方法
        //SqlSessionInterceptor是当前类的一个内部类
        this.sqlSessionProxy = (SqlSession)Proxy.newProxyInstance(SqlSessionFactory.class.getClassLoader(), new Class[]{SqlSession.class}, new SqlSessionTemplate.SqlSessionInterceptor());
    }

    //方法都通过sqlSessionProxy来执行
    public <T> T selectOne(String statement, Object parameter) {
        return this.sqlSessionProxy.selectOne(statement, parameter);
    }

    public <K, V> Map<K, V> selectMap(String statement, String mapKey) {
        return this.sqlSessionProxy.selectMap(statement, mapKey);
    }
}
```