1、用ps -ef | [grep](https://so.csdn.net/so/search?q=grep&spm=1001.2101.3001.7020) tomcat-v3 查出tomcat运行的进程id

![image-20220811160435345](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208111604411.png)

2、用top -Hp pid 查询进程下所有线程的运行情况（shift+p 按cpu排序，shift+m 按内存排序）  
top -Hp 30316  

![image-20220811160451514](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208111604557.png)

3、找到cpu最高的pid，用printf ‘%x\n’ pid 转换为[16进制](https://so.csdn.net/so/search?q=16%E8%BF%9B%E5%88%B6&spm=1001.2101.3001.7020)  
printf ‘%x\n’ 30506  

![image-20220811160507815](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208111605848.png)

4、用jstack 进程id | grep 16进制线程id 找到线程信息  
jstack 30316 | grep -A 20 772a  

![image-20220811160531547](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora-wm/202208111605586.png)

这里说不定能看到一些有用的信息(准备定位我也还没弄明白)  
我知道的好像只能解决线程死锁之类的问题，网上没有查到准备定位cpu高的代码的例子
