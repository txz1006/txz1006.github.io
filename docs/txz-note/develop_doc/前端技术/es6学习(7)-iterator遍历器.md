es6学习(7)-iterator遍历器

#### 一、Iterator遍历器

1. Iterator(遍历器)是一种数据访问接口，能够遍历常见的线性结构，通过next()方法，每次返回一个遍历对象的元素，直到遍历完所有的元素。

   ```javascript
   //模拟Iterator原理
   function getIterator(array){
       var index = 0; //作为遍历指针
       return {
           next(){
              //next()会返回一个对象包含done和value两个元素
              //done返回boolean值，表示是否结束遍历
              //value返回当前元素值
              return index < array.length?
               {done: false, value: array[index++]}:
               {done: true}
           }
       }
   }
   
   var a = getIterator([1,3,5]);
   a.next().value; //1
   a.next().value; //3
   a.next().value; //5
   a.next().value; //undefined
   ```

2. 默认Iterator的接口

   在es6中，如果一个对象具有Symbol.iterator属性和对应的遍历器函数，就可以认为当前对象是可以遍历的；Symbol.iterator属性指向一个遍历器函数(包含next()的对象),当我们需要遍历对象时，可以通过Symbol.iterator属性获取当前对象的遍历函数来进行遍历，由于Symbol.iterator是一个表达式，要放在中括号中

   ```javascript
   //获取数组遍历器
   var arr = [1,3,4,5];
   //获取遍历器
   var itor = arr[Symbol.iterator]();
   itor.next().value; //1
   itor.next().value; //3
   itor.next().value; //4
   
   //=================================
   //创建可遍历对象
   var arr = [1,3,4,5];
   var obj = {
   	[Symbol.iterator]: function(){
   		return this;
       },
       next(){
           return this.index < arr.length?
            {done: false, value: arr[this.index++]}:
            {done: true}
       },
       index: 0
   }
   //获取遍历值
   obj.next().value; //1
   obj.next().value; //3
   obj.next().value; //4
   obj.next().value; //5
   //可以遍历
   for(let i of obj){
       console.log(i); 
       //1
       //3
       //4
       //5
   }
   //=================
   //改变对象的遍历方法
   //下面将对象的遍历器改为数组的
   let itor = {
       0: 'a',
       2: 'b',
       1: 'c',
       length: 3,
       //数组的遍历器，需要length属性和key是从0开始的数值
       [Symbol.iterator]: Array.prototype[Symbol.iterator]
   };
   for(let item of itor){
       console.log(item); 
       //'a'
       //'c'
       //'b'
   }
   ```

3. 指针结构的遍历器

   遍历对象还有两个可选方法return()和throw(),return方法会在遍历提前结束时调用(如continue、break)；throw方法通常和generator函数一起使用

   ```javascript
   function Obj(val){
       this.value = val;
       this.next = null;
   }
   
   Object.prototype[Symbol.iterator] = function(){
       var curr = this;
       var iterator = {
       	next: function(){
               if(curr){
                   let value = curr.value;
                   curr = curr.next;
                   return {done: false, value: value}
               }else{
                   return {done: true}
               }
           }
       };
       //返回一个有next()的对象
       return iterator;
   }
   
   var one = new Obj(1);
   var two = new Obj(2);
   var three = new Obj(3);
   
   one.next = two;
   two.next = three;
   
   for(let i of one){
       console.log(i); 
       //1
       //2
       //3
   }
   ```

4. Iterator接口的应用

   ```javascript
   //下面的场景都用到了Iterator接口
   //1.数组和Set的解构
   let [a, b, ...c] = [1,2,3,4,5] //a=1, b=2, c=[3,4,5]
   
   //2.扩展运算符
   [...'hello'] //["h", "e", "l", "l", "o"]
   
   //3.yield*
   //yield* 后面跟一个可遍历对象，遍历时每个元素依次返回
   let generator = function*(){
       yield 1;
       yield* [2,3];
       yield 6;
   }
   var itor = generator();
   itor.next().value; //1
   itor.next().value; //2
   itor.next().value; //3
   itor.next().value; //6
   ```

5. for...of循环

   js中原有for.. in用于遍历，但只能取到遍历对象的key；所以es6中增加了for...of循环是可以取到key和val的

   ```javascript
   //常用遍历方式
   //forEach
   var arr = [1,2,'a','b'];
   arr.forEach((val, key)=>{
       console.log(key+":"+val);
       //0:1
       //1:2
       //2:'a'
       //3:'b'
   })
   
   //for...in(主要用于对象遍历)
   for(let item in arr){
        console.log(item+":"+arr[item]);
       //0:1
       //1:2
       //2:'a'
       //3:'b'
   }
   
   //for...of
   for(let [key, val] of arr.entires()){
       console.log(key+":"+val);
       //0:1
       //1:2
       //2:'a'
       //3:'b'    
   }
   ```