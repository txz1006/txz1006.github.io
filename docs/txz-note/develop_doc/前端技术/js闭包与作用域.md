js闭包与作用域

### 一、JS闭包的理解与分析

#### 1. 什么是闭包

闭包的定义比较抽象难懂，在MDN中下的定义是：函数和对其周围状态的引用捆绑在一起便形成了闭包。对于不了解闭包的同学多半会十分的懵逼，啥是周围状态啊？啥是周围状态的引用啊？咋给函数捆绑一起啊？每个字你都认识，但是连在一起就一脸迷茫了Σ_(꒪ཀ꒪」∠)

下就个人理解来分析下闭包这个玩意，将上面的定义翻译成看得懂的人话(如有问题，欢迎指正讨论)：

首先，闭包单就词义来讲就是一个封闭的模块或对象，所以闭包是需要在一个独立的范围内才能形成；换成程序语言来说，就是在一个局部的作用域中才可以形成闭包，那么类比于上面的定义，可以认为'周围状态'就是一个局部的作用域(通常指函数的函数体)，'周围状态的引用'就是这个作用域中定义的变量，而'给函数捆绑'则是这个作用域要对外返回一个函数，这个函数会绑定记录下在函数体中调用外部作用域的变量（简单的说就是在一个函数A中return另一个函数B，如果函数B中调用了函数A的变量，那么就会记录下这些变量和函数B一起被return出去)。

下面写一个简单的闭包例子：

```js
function test(){
	let msg = "Hello";
	let arr = [];
	arr[0] = function(){console.log(msg);}
    return arr;
}
var res = test();  
res[0]();  //打印Hello
```

我们来分析下这个例子：

1. test函数形成了一个局部的作用域
2. 在函数体中定义了两个变量，一个msg字符串，一个arr数组(仅在函数中有用)
3. 给arr[0]赋值一个函数，这个函数使用t了est函数中的变量msg，将arr数组对外return
4. 调用函数获取返回的函数数组赋值给res，再调用返回函数打印得到msg的值Hello

上述例子的return函数记录下了test函数的msg变量，而msg在外部被res调用时只能作为私有值被访问，所以这里形成了一个封闭的对象，也就是闭包。相信到这里，各位对于闭包多少有一些理解了。

如果我们在浏览器的控制栏中查看res对象的话，会更清晰的理解arr[0]函数记录了变量msg(注意在test函数执行完后，因为形成了闭包，变量msg并没有释放空间)：

![image-20200610205157946](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103104.png)

这里明确下个人对闭包的理解：在局部作用域下，返回一个函数对象，且此对象依然可以调用到父作用域中的变量，就可认为形成了闭包；而闭包常见的存在形式就是函数的嵌套。

#### 2. 闭包特性详解

- 闭包中var和let变量作用域问题

  来看一个闭包的例子：

  ```js
  function test(){
  	var arr = [];
      for(var i=0; i<3; i++){
          arr.push(function(){console.log(i);});
      }
      return arr;
  }
  var res = test();
  res[0]();  //3
  res[1]();  //3
  res[2]();  //3
  ```

  思考一下为什么这个结果不是0、1、2，而是3、3、3。原因也不复杂，在形成闭包后，arr数组中的函数会绑定test函数中的变量i(三个函数绑定的同一个变量)，而i在循环中一直是变化的，所以arr中的三个函数绑定的i的值就都变成了循环后i的值，也就是3。

  如果我们想要得到0，1，2的结果应该如何修改？这里给出两种方式：

  1. 将声明循环变量的关键字改为let，让i只能在当前循环中才有效（每次循环都创建一个作用域）

     ```js
     function test(){
     	var arr = [];
         for(let i=0; i<3; i++){
             arr.push(function(){console.log(i);});
         }
         return arr;
     }
     var res = test();
     res[0]();  //0
     res[1]();  //1
     res[2]();  //2
     ```

     这里可以认为每一次for循环都是一个独立的作用域，而每次循环中i的值都不同，arr数组中的函数只绑定当前作用域中的i。

  2. 在变量i和闭包函数之间再嵌套一个函数，形成一个新的闭包

     ```js
     function test(){
     	var arr = [];
         for(var i=0; i<3; i++){
             arr.push((function(i){
             	return function(){console.log(i);}
             })(i));
         }
         return arr;
     }
     var res = test();
     res[0]();  //0
     res[1]();  //1
     res[2]();  //2
     ```

     在循环中加入了一个立即执行函数，立即执行函数和返回函数形成了一个新的闭包，返回函数只会绑定立即执行函数的参数i，而每次循环中i的值都不同。

- 闭包中this的指向问题

来看另一个闭包例子：

```js
var msg = "hello";
var obj = {
    msg: "world",
    fun: function(){
        return function(){
            console.log(this.msg);
        }
    }
}
obj.fun()(); //打印hello
//=============================
var msg = "hello";
var obj = {
    msg: "world",
    fun: function(){
        var that = this;
        return function(){
            console.log(that.msg);
        }
    }
}
obj.fun()(); //打印world
```

如何理解上文中的this指向？

一般对于函数来说，this指向调用者的上下文对象；在第一个例子中，执行`obj.fun()`时，我们得到了一个打印`this.msg`的匿名函数，这时匿名函数处于全局环境中，而全局环境的上下文对象是`Window`,所以`this.msg`指代`window.msg`打印全局msg的值。

而在第二个例子中，在obj对象的fun函数中多加了一句`var that = this;`就改变了结果；我们知道在一个对象中，this通常指向当前对象本身，在执行`obj.fun()`时，函数中的this是指向obj对象的，执行`var that = this;`就是将obj对象保存到了匿名函数中，所以打印`this.msg`就变成了`obj.msg`。

#### 3.闭包应用场景

这里简单介绍几种：

- 减少参数数量

  ```js
  function pow(x){
  	return function(i){
  		//打印i的x次方
  		console.log(Math.pow(i,x));
  	}
  }
  var a = new pow(3);
  a(2);  //2的三次方为8
  a(5);  //5的三次方为125
  ```

- 保存函数的私有变量

  ```js
  function getIndex(){
  	var index = 0;
  	return function(){
  		return index++;
  	}
  }
  var a = new getIndex();  
  a();  //0
  a();  //1
  a();  //2
  ```
