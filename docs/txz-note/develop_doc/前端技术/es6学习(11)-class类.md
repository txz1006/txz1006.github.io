es6学习(11)-class类

#### 一、class用法

1. js中从class的实质上就是创建了一个构造函数，只是写法上类似于面向对象。

   ```javascript
   //传统构造函数用法
   functionc fun(x, y){
       this.x = x;
       this.y = y;
   }
   var f = new fun(1,2); //fun {x: 1, y: 2}
   
   //class写法
   class fun2{
       //构造方法
       constructor(x, y){
          this.x = x;
          this.y = y;
       }
   }
   var f = new fun2(1,2); //fun2 {x: 1, y: 2}
   
   //class本质是一个构造函数
   typeof fun2 === 'function' //true
   fun2 === fun2.prototype.constructor //true
   ```

2. class的注意要点

   ```javascript
   //1.class一定有一个constuctor构造函数，若不写，则默认有个空构造函数
   class fun1{} //等同于 class fun1{ constructor(){}}
   
   //2.class对象一定要使用new创建
   class fun1{}
   var a = fun1(); 
   // Class constructor fun1 cannot be invoked without 'new'
   var b = new fun1(); //不报错
   
   //3.class的属性函数都在原型对象上
   class fun1{ tostring(){console.log('aaa')}}
   var b = new fun1();
   b.constructor === fun1.prototype.constructor //true
   b.tostring();  //aaa
   fun1.prototype.tostring(); //aaa
   
   //所以可以通过原型给class对象添加方法
   class fun1{ tostring(){console.log('aaa')}}
   //复制两个方法到fun1的原型中
   Object.assign(fun1.prototype, {read(){console.log('read')}, write(){console.log('write')}})
   var b = new fun1();
   b.read(); //read
   
   //class的方法没法被遍历枚举
   class fun1{ tostring(){console.log('aaa')}}
   Object.keys(fun1.prototype); //[]
   ```

3. class的使用

   ```javascript
   //1.类中使用getter和setter
   class fun{
       get prop(){return this.prop}
       set prop(val){console.log('setter: '+ val) }
   }
   let a = new fun();
   a.prop = 123; //打印setter: 123
   
   //2.属性表达式
   let prop = 'getA';
   class fun{
       //属性的名称从prop获取
       [prop](){}
   }
   
   //3.class表达式
   let a = class fun{
       //fun.指当前类对象，在内部使用
       //若没用到这个内部对象，则fun都可以省略掉(let a = class{...})
       getName(){return fun.name;}
   };
   //外部使用a代指类对象
   let obj = new a();
   obj.getName(); //fun
   let obj2 = new fun(); //fun is not defined
   
   //直接返回一个class对象
   let p = new class(...)
   
   //4.静态方法
   //若在class中定义静态方法，则可以不创建对象，直接调用
   class foo{
   	static getName(){return this.name};
   }
   foo.getName(); //foo
   
   //注意在静态方法中this指当前类，而不是类的实例对象
   class foo{
       static bar(){this.baz();}
       static baz(){consle.log("1111")}
       baz(){console.log("2222")}
   }
   foo.bar()  //1111
   ```

#### 二、class的继承

1. class可以使用extends关键字表示class的继承关系，子类可以共享父类的属性和方法，实质上就是将子类的原型指向了父类

   ```javascript
   //简单实例
   class A{
       username="123";
   	getUserName(){
           return this.username;
       }
       static getPwb(){
           return 'pwd';
       }
   }
   class B extends A{
       constructor(){
           super();
       }
   }
   let b = new B();
   b.username;  //123
   b.getUserName(); //123
   
   //要点1：继承子类可以调用父类的属性和方法，包括静态方法(使用上述实例)
   B.getPwb();  //pwd
   
   //要点2：继承子类必须要在构造函数中调用super()调用父类的构造函数
   //super可以指代父对象
   class A {}
   
   class B extends A {
     //这里的构造函数可以省略掉
     constructor() {
       super();  //必须有
     }
   }
   //若去掉super()则报错ReferenceError: Must call super constructor
   
   //要点3：子类也是属于父类对象的实例
   class A {}
   
   class B extends A {
     constructor() {
       super();  //必须有
     }
   }
   new B() instanceof A //true
   new B() instanceof B //true
   B instanceof A //false
   
   //要点4：可以使用Object.getPrototypeOf()来判断是否有是一个子类
   //Object.getPrototypeOf()作用是获取一个对象的原型，而子类的原型是指向父类的
   Object.getPrototypeOf(B) === A //true
   ```

#### 三、super关键字

1. super主要用在继承子类当中，可以作为父类构造函数，也可以作为父类对象。当作为父类对象时，一般指代父类原型对象，可以在构造函数之外使用。(在静态方法中super指父类本身)

   ```javascript
   //要点1：this是指向当前实例对象的
   class A{
       x = 0;
       constructor(){
           this.x =1;
       }
       m(){
           return this.x;
       }
   }
   class B extends A{
       constructor(){
           super();
           this.x = 2;
           super.x = 3;  //子类实例a中，父类中的this实指子类实例对象
       }
       m(){
           //下面super指s的是父类原型对象，原型对象是没有x的
           //super === A.prototype (true)
           console.log(super.x); //返回undefined
           console.log(this.x);  //3
           return super.m();
       }
   }
   let b = new B(); 
   b.m(); //3(返回的是实例a的x)
   ```

2. 父子类之间的原型链关系

   ```javascript
   //实例与构造函数和原型的关系
   b.__proto__ === B.prototype //true
   b.__proto__.__proto__ === A.prototype //true
   B.prototype.__proto__ === A.prototype //true
   B.__proto__ === A //true
   B.__proto__.__proto__ === Function.prototype //true
   //实际的继承关系
      //B的原型实例指向A的原型实例
      Object.setPrototype(B.prototype, A.prototype);
      //B的原型指向A
      Object.setPrototype(B, A);
   
      //Object.setPrototype的实现
      Object.setPrototype = function(obj, proto){
          obj._proto_ = proto;
          return obj;
      }
   ```

