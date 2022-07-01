javaFx解决的问题：

1. 项目无法编译，显示申请内存不足
   解决：更换jdk11的版本

2. 项目启动失败，显示没有添加模块
   解决：在module-info.java中添加对接的java路径，如：
   ![image-20220606161049162](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202206061610436.png)

3. 去掉windows自带的菜单栏，自己定义
   给stage设置style样式为StageStyle.TRANSPARENT

   ![image-20220606161618889](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202206061616934.png)

4. 图片信息加载不出来

   解决：使用相对路径![image-20220606161822931](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202206061618011.png)

5. 使用spring接管javafx对接

   在pom中引入springboot依赖：

   ```xml
           <dependency>
               <groupId>org.springframework.boot</groupId>
               <artifactId>spring-boot-starter</artifactId>
           </dependency>
           <dependency>
               <groupId>org.springframework.boot</groupId>
               <artifactId>spring-boot-starter-test</artifactId>
               <scope>test</scope>
           </dependency>
   ```

   在javafx的启动类中创建spring对象，并从spring中获取javafx的首页对象

   ![image-20220607182156346](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202206071822840.png)

   

6. 