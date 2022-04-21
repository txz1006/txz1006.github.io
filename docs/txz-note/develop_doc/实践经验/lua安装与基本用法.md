lua安装与基本用法

#### 前言

弱类型语言，语法和javascript类似，可以用于redis脚本语言的开发

#### 1.lua安装

下载tar.gz压缩包

```sh
# 解压
tar -zxvf  lua-5.3.0.tar.gz
#进入解压目录
cd lua-5.3.0
#编译
make linux
#安装
make install
```

lua命令行操作

```sh
#进入lua
~: lua
#执行lua脚本
~: lua ./demo.lua
```

#### 2.基本语法

**变量:**

全局变量：直接声明

例如： x = "hello world"

局部变量：使用local声明

例如：local y = "thanks"

**算术运算符：**

加减乘除：[+ - * /]

取余： %

**逻辑运算符：**

与逻辑：and 

或逻辑：or

非逻辑： not

**判断逻辑：**

if ([expression]) then

[body]

else if  [expression] then

[body]

end

**循环逻辑：**

while ([expression]) do

[body]

end

===========

for i = [exp1],[exp2],[exp3] do

[body]

end

说明：exp1代表循环开始值，exp2代表循环结束值，exp3代表循环步长，默认为1

===========

超级循环

for i, v in ipairs(x) do

[body]

end

说明：x是可循环对象(数组集合)，i是循环项的索引值，v是循环项的值

例子：

x = {'aaa', "2",  3}

for i,v in ipairs(x) do

print(i ,v)

end

**函数：**

function name(args...)

[body]

end

#### 3.lua在redis中使用

**lua脚本中执行redis命令：**

redis.call('set', 'key', 'val')

redis.call('get', 'key')

**redis执行lua脚本(逗号前后都要有空格)：**

./redis-cli --eval "lua脚本命令.lua" keys ,  args1 args2 

或者进入redis命令行：

127.0.0.1:6379>eval "return redis.call('set', KEYS[1], ARGV[1])" 1 hello world

说明：   KEYS[1], ARGV[1]为入参占位符，1代表一个入参，  KEYS[1]为hello， ARGV[1]为world

命令：redis-cli --eval "demo.lua"  KEYS...  ,  ARGS...

参考：https://www.cnblogs.com/yanghuahui/p/3697996.html

 