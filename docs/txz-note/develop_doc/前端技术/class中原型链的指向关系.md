class中原型链的指向关系

### 一、函数、函数实例、函数原型的关系

在学习class继承过程中对于函数实例、函数对象和原型的关系有些困惑，分不清之间的从属关系，下面是参考很多资料后对这一块的分析理解，如有问题，欢迎指正讨论。

#### 1. 函数对象

函数是执行某个行为动作的代码集合，格式为`function XXX(...args){...}`，一般可以将该函数称为普通函数或构造函数(以下都称构造函数)。在函数创建的时候会为函数对象添加两个属性，一个是`prototype`指向本函数的原型对象，一个是`__proto__`指向Function.prototype(Function的原型)

```javascript
//以Foo函数为例
function Foo(){}
Foo.prototype; //{constructor: Foo(), __proto__: Object}
Foo.__proto__ === Function.prototype; //true
```

- ​	普通函数与构造函数的区别

  ```javascript
  普通函数和构造函数并没有太明显的区别，主要靠使用者编码规范来维护区分
  区别1：构造函数的函数名首字母要大写
  区别2：构造函数的实例化要使用new关键字
  区别3：构造函数的this指向实例化的对象，普通函数的this指向window对象
  function Foo(){}  //构造函数(Foo为函数本身)
  //在函数的原型对象里加上getThis方法
  Foo.prototype.getThis = function(){console.log(this)}
  let a = new Foo();
  a.getThis(); //打印Foo {}实例化对象
  
  function foo(){console.log(this)}  //普通函数
  foo();  //打印Window对象
  ```

#### 2. 函数实例

一般指使用new关键字通过`new XXX()`格式创建一个构造函数的实例化对象，创建时会给实例化对象添加`__proto__`属性，指向函数的原型对象

```javascript
//以上文Foo函数为例
function Foo(){}
var a = new Foo();  //创建函数实例
a.__proto__ === Foo.prototype; //true
```

#### 3. 函数原型

函数创建时产生的对象，原型对象中有两个属性，一个是`constructor`指向所属函数的构造函数本身，还有一个是`__proto__`属性指向Object.prototype(Object的原型)

```javascript
//以上文Foo为例
//获取原型方式
Foo.prototype(通过函数对象获取原型)
new Foo().__proto__(通过函数实例的__proto__属性获取)
Object.getPrototypeOf(new Foo())(通过Object对象获取)
//Object.getPrototypeOf函数本质为返回参数的__proto__属性

//通过constructor与所属函数建立联系
Foo.prototype.constructor === Foo //true

//函数原型的__proto__属性
Foo.prototype.__proto__ === Object.prototype //true
```

#### 4. 函数、函数实例、函数原型三者关系总结

关系如下图所示，以构造函数和函数原型为基础，下可以创建函数的实例化对象，上可以根据`__proto__`属性获取原型链上的数据。

![image-20200529140443362](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103812.png)

在实例应用中，一个函数实例在调用属性时，会先在当前对象中查找，若找不到对象，则会顺着原型链(`__proto__`属性)到对应的原型对象中查找；一个函数的多个实例对共享当前函数的原型对象。

```javascript
function Foo(){}
var a = new Foo();
Foo.prototype.msg = "Hello!";//(msg在原型对象上)
a.msg; //返回Hello!
a.msg = "world!";  //在实例中创建一个msg赋值world!(没有改变原型中的msg)

var b = new Foo();
b.msg;  //返回Hello!
```

### 二、class中继承的原型链的改变

js中class的本质相当于一个构造函数，而class的使用相当于规范了构造函数的使用(必须使用new实例化，类属性都写入原型中等等)，当class之间加入继承关系时，实际上就是改变了构造函数之间原型指向。

```javascript
class A{}
class B extends A{}  //B继承A

typeof A == 'function' //true(实质为一个构造函数)
B.__proto__ === A  //true(B的__proto__属性变为指向A构造函数)
B.prototype.__proto__ === A.prototype //true(B原型的__proto__属性变为指向A的原型)
let b = new B()
b.__proto__.__proto__ === A.prototype //true
b.__proto__.__proto__.__proto__ === Object.prototype //true

//不使用extends实现继承关系
class A{}
class B{}
Object.setPrototypeOf(B, A); //实际为B.__proto__ = A
Object.setPrototypeOf(B.prototype, A.prototype); //类似同上
B.__proto__ === A  //true
B.prototype.__proto__ === A.prototype //true
```

继承关系图如下：

![image-20200529152327926](https://alex-img-1253982387.cos.ap-nanjing.myqcloud.com/Typora/20201102103816.png)

- class对象中this与super的指向问题

  ```javascript
  //若this在普通方法中使用则默认指向类的实例,super默认指向父类的原型
  class A{
      constructor(){
          this.x = 1; 
      }
  	getMsg(){return this.x}
      getNum(){return 9}
  }
  class B extends A{
      constructor(){
          super();
          this.x = 2;
          //这里不是直接执行的A.prototype.x = 3,而是A.prototype.x绑定实例对象B的this，this实际为实例对象b，所以变为b.x的赋值
          super.x = 3;  
          console.log(super.getMsg());  //3
          console.log(super.getNum());  //9
          console.log(super.x); //undefined
          console.log(this.x);  //3
      }
  }
  let b = new B();
  b.x;  //3
  
  
  //若在静态方法中，this指向类本身，super指向父类本身(这里super要在子类静态方法中使用)
  class A{
  	static name(){
          return this.msg();
      }
      static msg(){console.log("hello")}
      msg(){console.log("world")}
  }
  class B extends A{
      static name(){
          super.name();
      }
  }
  //(同上原因：A.prototype.msg()绑定实例对象B的this，实际this为函数本身B，所以变为B.msg()的调用,而B本身没有静态的msg(),顺着原型链找到了A.msg())
  B.name(); //hello
  B.name() === B.msg(); //true
  let b = new B();
  b.msg(); //world
  ```

  

