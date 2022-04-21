es6学习(6)-proxy代理

#### 一、Proxy代理重载对象

1. Proxy对象可以修改代理目标的默认行为。简单的说就是代理一个目标，代理对象可以调用获取目标对象的属性和方法，在这个过程中，通过配置特定的Proxy方法，可以拦截并改变调用目标对象的结果

   ```javascript
//Proxy有两个参数：target和handler，target是被代理目标对象，handler是一个配置对象，用来配置特定方法拦截调用目标的内容
   var target = {a: 'aaa'};
   var handler = {}; //未配置任何拦截
   var proxy = new Proxy(target, handler);
   proxy.a; //'aaa'
   target.a; //'aaa'
   
   //如果handler重写get方法
   var handler = {
       //拦截被代理对象的属性读取，都返回35
       get(target, property){
           return 35;
       }
   }
   var proxy = new Proxy(target, handler);  //target指{a: 'aaa'}
   proxy.a; //35
   proxy.b; //35
   
   //对象原型也会被proxy影响
   let obj = Object.create(proxy); //proxy为上方的对象
   obj.c = 123; //设置一个属性
   obj.c;  //返回123
   obj.kick //返回35(obj无kick属性，就会顺着原型链向上找到obj的原型proxy，在proxy读取kick时，会被拦截，返回35)
   ```

2. proxy常用的拦截方法应用

   ```javascript
   var handler = {
   	//拦截属性读取
   	get(target, name){
   		if(name == 'username'){
   			return Object.prototype;
   		}
   		return 'Hello '+name;
   	},
       //拦截函数的调用
   	apply(target, ctx, args){
   		return args[0]; //返回第一个参数
   	},
       //拦截函数作为构造方法的调用
       construct(target, args){
   		return {value:args[1]}; //返回第二个参数
       }
   }
   
   var target = function(x, y){
       return x +y;
   }
   
   var proxy = new Proxy(target, handler);
   proxy(1,2,3); //返回1(被apply拦截)
   new proxy(1,2,3); //返回{value: 2}(被construct拦截)
   proxy.username === Object.prototype; //true(被get拦截)
   proxy.ccc //Hello ccc(被get拦截)
   ```

3. proxy的常用拦截方法

   ```javascript
   //拦截对象属性的读取
   //参数(代理目标对象，读取属性的名称，代理对象)
   get(target, propKey, receiver)
   
   //拦截对象属性赋值
   //参数(代理目标对象，设置属性的名称，设置属性的值，代理对象)
   set(target, propKey, propVal, receiver)
   
   //拦截propKey in proxy操作
   //参数(代理目标对象, 属性的名称)
   has(target, propKey)
   
   //拦截删除对象属性操作delete proxy[propKey]
   //参数(代理目标对象, 属性的名称)
   deleteProperty(target, propKey)
   
   //拦截Object.getOwnPropertyNames(proxy)、Object.getOwnPropertySymbols(proxy)、Object.keys(proxy)，返回一个数组
   //参数(代理目标对象)
   ownKeys(target)
   
   //拦截Object.getOwnPropertyDescriptor(proxy, propKey)，返回属性的描述对象。
   //参数(代理目标对象, 属性的名称)
   getOwnPropertyDescriptor(target, propKey)
   
   
   //拦截Object.defineProperty(proxy, propKey, propDesc）、Object.defineProperties(proxy, propDescs)，返回一个布尔值。
   //参数(代理目标对象, 属性的名称，描述)
   defineProperty(target, propKey, propDesc)
   
   //拦截Object.preventExtensions(proxy)，返回一个布尔值。
   //参数(代理目标对象)
   preventExtensions(target)
   
   //拦截Object.getPrototypeOf(proxy)，返回一个对象。
   //参数(代理目标对象)
   getPrototypeOf(target)
   
   //拦截Object.isExtensible(proxy)，返回一个布尔值。
   //参数(代理目标对象)
   isExtensible(target)
   
   //拦截Object.setPrototypeOf(proxy, proto)，返回一个布尔值。
   //参数(代理目标对象, proto对象)
   setPrototypeOf(target, proto)
   
   //如果目标对象是函数，那么还有两种额外操作可以拦截。
   //拦截 Proxy 实例作为函数调用的操作，比如proxy(...args)、proxy.call(object, ...args)、proxy.apply(...)。
   //参数(代理目标对象, 上下文对象, 参数数组)
   apply(target, ctx, args)
   
   //拦截 Proxy 实例作为构造函数调用的操作，比如new proxy(...args)。
   //参数(代理目标对象, 参数数组)
   construct(target, args)
   ```

4. proxy的应用

   ```javascript
   var person = {
     name: "张三"
   };
   
   var proxy = new Proxy(person, {
     get: function(target, property) {
       if (property in target) {
         return target[property];
       } else {
         throw new ReferenceError("Property \"" + property + "\" does not exist.");
       }
     }
   });
   
   proxy.name // "张三"
   proxy.age // 抛出一个错误
   ```

#### 二、Reflect(Proxy对应函数库)

1. 主要用于和Proxy配合使用的函数库，一般和Proxy拦截方法一一对应

   ```javascript
   //get(属性读取)
   Reflect.get(target, name, args);
   
   //set(属性赋值)
   Reflect.set(target, name, args);
   
   //has(对象包含,等同name in obj)
   Reflect.has(target, name);
   
   //delete(删除属性,等同delete target[name])
   Reflect.deleteProperty(target, name);
   
   //construct(构造函数,等同new target(...args))
   Reflect.construct(target, args);
   
   //getPrototype(读取obj的原型对象)
   Reflect.getPrototype(obj)
   
   //setPrototype(给obj设置新的原型对象)
   Reflect.setPrototype(obj, newProto)
   
   //函数调用(调用func(...args))
   Reflect.apply(func, ctx, args);
   ```

   

