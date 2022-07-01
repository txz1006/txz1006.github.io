常用注解

#### @SpringbootApplication

该注解是Springboot的启动注解，其中嵌套使用了@EnableAutoConfiguration注解来开启自动装配功能，@EnableAutoConfiguration会创建ConfigurationClassPostProcessor处理器，并通过AutoConfigurationImportSelector对象来扫描各个Starter中MATE-INF下的spring.factories配置文件，将文件中的配置Bean加载到IOC容器中。

#### @ConfigurationProperties

该注解的作用是将被标注类中的成员变量和配置文件(properties/yml)中的属性一一绑定起来，当配置类被创建成bean时，会用配置文件中的属性注入到bean中。

#### @EnableConfigurationProperties

该注解的作用是将参数列表中被 @ConfigurationProperties标注的类创建成bean