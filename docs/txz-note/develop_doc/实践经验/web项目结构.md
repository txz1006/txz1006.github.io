web项目结构

开发中的web项目结构

![image-20201208180810986](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201208180830.png)

打包后的项目结构

![image-20201208181522329](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201208181522.png)

WEB-INF下的结构

![image-20201208181846415](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201208181846.png)

idea下配置项目编译结构：

在Project Structure中的Modules下可以设置项目编译的内容范围，编译后的内容会写入到WEB-INF/classes文件下，不需要编译的可以排除在外(黄色的)

![image-20201208182043466](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201208182043.png)

设置编译后的项目文件位置，一般指向WebRoot下的WEB-INF/classes文件夹

![image-20201208182255404](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201208182255.png)

设置编译后输出的web结构，选择web application:exploded,若要输出war包，则要选择web application:Archive下的exploded包名

![image-20201208182735310](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201208182735.png)