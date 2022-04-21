es6学习(4)-symbol

####  一、Symbol

1. Symbol(标记符)，是es6标准新引入的一个原始类型，和boolean、number、string、object、undefined、null形成新的七大基础类型。Symbol主要用于解决变量名和属性名称重复、冲突的问题，所以每一个symbol对象都是唯一的。

2. Symbol的使用

   ```javascript
   //创建Symbol对象
   var a = Symbol();  //不需要new
   typeof a; //返回'symbol'
   
   //Symbol有一个参数，用于描述当前标识符的作用
   var a = Symbol('aaa');
   a.toString()  //'Symbol(aaa)'
   
   //若参数为对象，则会先调用该方法的toStirng()将其转换为字符串
   var str = {toString(){return '123'}}
   var a = Symbol(str);
   a.toString(); //'Symbol(123)'
   
   //Symbol可以转为字符串和boolean值，其他转换会报错
   Boolean(Symbol('111'))  //true
   String(Symbol('111'))  //'Symbol(111)'
   
   //Symbol作为属性名
   var str = Symbol();
   var obj = {};
   //注意下方两种写法结果一样吗
   obj.str = 'aaa';
   obj[str] = 'aaa';
   obj; //{str: "aaa", Symbol(): "aaa"}
   //上面的str标识符作为变量名了
   ```
   
3. Symbol常用方法

   ```javascript
   //Symbol有独立的获取方法(可以定义私有对象)
   Object.keys(obj);  //返回[str]一个变量,取不到Symbol信息
   Object.getOwnPropertySymbols(obj);//返回[Symbol()]
   
   //返回对象所有key名称的方法
   Reflect.ownKeys(obj); //返回['str', Symbol()]
   ```

4. Symbol单例对象

   ```javascript
   //Symbol.for()，Symbol.keyFor()
   //当我们想多次调用同一个Symbol时，可以使用Symbol.for();方法，该方法同样会创建一个Symbol对象，但是我们可以通过for(arg)的参数再次获取到该Symbol对象（arg参数会登记到全局属性中，该方法可用于创建单例对象）
   Symbol.for(123) === Symbol.for(123); //true
   //多次调用Symbol.for(123)都会返回同一个对象
   
   //可以使用Symbol.keyFor()获取for()登记的参数
   var a = Symbol.for('asd');  //登记'asd'
   Symbol.KeyFor(a);  //返回'asd'
   
   var a = Symbol('asd');
   Symbol.KeyFor(a); //返回undefined,未登记
   ```

   

