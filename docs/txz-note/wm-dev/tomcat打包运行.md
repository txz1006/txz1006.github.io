#### 项目结构

首先我们来看看，项目编译前后的文件结构：

![image-20210926145327541](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202109261453347.png)

从图中我们可以知道，项目的结构是以webapp下的结构为基础的，主要有META-INF、WEB-INF和其他资源文件

```java
在开发中经常会用到classpath：xxx.xml的格式来读取文件，其中的classpath一般指的是WEB-INF文件夹。

如果想要一次性读取多个文件，则可以使用classpath*:context/conf/controller*.xml来批量加载(少用，较)

private static final ResourcePatternResolver resourceResolver = new PathMatchingResourcePatternResolver();
//location为classpath:mapper/**/*.xml
private Resource[] getResources(String location) {
    try {
        return resourceResolver.getResources(location);
    } catch (IOException var3) {
        return new Resource[0];
    }
}
```



而WEB-INF下的内容尤为关键，主要有三个部分：classes文件夹主要用来存储/src/main/java下java文件编译后的class文件和/src/main/resources下的配置资源文件(也可以配置其他main下的其他配置文件夹，如增加一个config文件下的内容，这样在build项目时会将这些资源文件复制到classes下面)；

![image-20210926150009734](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202109261500069.png)

lib文件夹主要存储项目依赖的三方jar包(项目在build时会将这些jar复制到lib文件夹下)；

![image-20210926150327336](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202109261503984.png)

web.xml记录项目的基础配置项目和启动入口。

![image-20210926150412739](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202109261504557.png)

#### 生成项目编译结构

做来配置后我们可以生成项目编译结果：

![image-20210926150738253](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202109261507509.png)

我们选择一个Web Application-exploded结构，指定当前对象的结构输出位置output directory，之后在下面配置具体的文件输出结构了。这个结构和上一节中说明的webapp下的基础结构完全对应：

首先会创建出目标文件夹campus-server，然后将webapp下内容复制过来，这样基础结构就有了，然后找到项目的facets配置，将Source Roots的内容编译或直接复制到classes文件夹下；而lib直接有所有jar包的地址，build时会将所有jar包复制过来。

这样就配置好了。

下面就可以通过build/build artifacts命令来构建这个项目了。

构建的结构代码会生成在output directory指定的路径中，之后我们可以将这个artifacts设置到tomcat等web容器中，来部署运行。

#### Maven打jar包和war包

我们可以使用Maven来进行项目管理，而其中的jar包和war包构建是经常用到的，下面来简单了解下操作流程：

如果我们要打jar包：

首先我们需要指定packaging标签的值为<packaging>jar</packaging>，可以使用在pom文件中增加如maven-jar-plugin等一类maven构建插件，这些插件配置了很多的结构，只要进行简单的配置就可以生成对应的结果文件。

```xml
//在plugins添加
<plugin>
   <groupId>org.apache.maven.plugins</groupId>
   <artifactId>maven-jar-plugin</artifactId>
   <version>2.3.2</version>
   <configuration>
       //编译后的文件所在文件夹
      <classesDirectory>target/classes</classesDirectory>
       //生成jar包名称
      <finalName>${project.artifactId}-${project.version}</finalName>
       //生成文件位置
      <outputDirectory>target</outputDirectory>
      <!--<encoding>UTF-8</encoding>-->
   </configuration>
</plugin>
```

之后执行mvn package或是执行下面的maven命令就行

![image-20210926160713900](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202109261607308.png)

这样可以生成一个jar包了。

jar包一般默认会包含2个部分，src/main/java下java的编译class文件(注意src/main/java路径下的非java文件不会被打入jar包中)和src/main/resources下的配置文件

![image-20210926161208321](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202109261612901.png)

如果想增加其他的文件可通过resource标签进行增加(如上图中jar包的test.sql就是/config文件夹下的内容)：

```xml
//build标签下
<resources>
   <resource>
       //设置要增加的文件夹
      <directory>src/main/config</directory>
       //开启过滤
      <filtering>true</filtering>
       //设置具体要匹配到的文件信息(这里是config下的全部文件都会打入jar包)
      <includes>
         <include>*</include>
      </includes>
   </resource>
</resources>
```

通过resource标签添加的内容会直接添加到jar包根目录中。

==================

如果我们要打war包：

需要将packaging标签的值为<packaging>war</packaging>，需要注意的是war包中所有的配置文件都会放在WEB-INF/classes中。

如果项目是普通web项目有web.xml，可以使用maven-war-plugin插件进行打包：

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-war-plugin</artifactId>
    <version>2.4</version>
    <configuration>
        <!-- 释放将项目的类文件打成jar放到lib目录中。 打成jar的好处是：只修改class时，可以只更新jar。(如果有新增jar包等资源还是需要手动处理，有利有弊) -->
        <archiveClasses>true</archiveClasses>
        <webResources>
            <resource><!-- 打包，打入V3的web工程公共配置文件(将config文件夹内存写入classes中) -->
                <directory>src/main/config</directory>
                <targetPath>WEB-INF/classes</targetPath>
                <filtering>true</filtering>
            </resource>
        </webResources>
    </configuration>
</plugin>
```

这样会将当前项目打成一个jar包，放入lib中，这样之后进行项目升级则可以只打jar包进行升级。

如果项目是springboot项目，则使用spring-boot-maven-plugin插件进行打包：

```xml
<plugin>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-maven-plugin</artifactId>
</plugin>
```

在启动类中继承SpringBootServletInitializer类，重写方法configure：

```java
@Override
protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
   return builder.sources(RenrenApplication.class);
}
```

然后执行package打包命令即可

