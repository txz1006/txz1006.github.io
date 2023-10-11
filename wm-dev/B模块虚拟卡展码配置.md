前提：新开虚拟卡展码单页面最好新配置一个同类型宿主，不能和标卡复用同一个外嵌地址

使用范围：80%的宿主可以增加fastUrl、xCode、fastParams就可以使用了

目前已经上线单页面系统的应用：shanxizyyFast_njgydx-qywx-bk（南京工业大学）、supwisdomapp_fjxxswjxnk（福建信息职业技术学院）

### 树维宿主

配置好如下参数即可，这几个参数一般默认不需要改动

![image-20230911105133903](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202309111051943.png)

参数解释：

**swClaimsParams**：树维用户传参，需要给虚拟卡单页面系统传递的树维token中的参数名称，这里默认将用户的类型名称和类型编号传给单页面系统，传给单页面的参数名称不带ATTR_前缀

**fastUrl**：虚拟卡单页面入口地址

**xCode**：加解密秘钥，传递给单页面系统的的参数需要进行加密，用这个参数加解密

**fastParams**：需要给单页面系统加密传递哪些参数

### 企业微信宿主

![image-20230911105417708](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202309111054776.png)

配置完成后可以在宿主日志中看到访问单页面系统的地址：

![image-20230911105515593](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202309111055643.png)