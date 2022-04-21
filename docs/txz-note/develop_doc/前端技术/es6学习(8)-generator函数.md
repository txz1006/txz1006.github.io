es6学习(8)-generator函数

#### 一、Generator函数

1. Generator函数是一种特殊的函数，不同于传统函数的调用，会直接执行完函数体的代码，Generator函数可以将函数体分多个阶段，类似于遍历对象，要调用才会进行元素读取,每次调用会执行一个阶段的代码并返回此阶段的结果，直到函数体执行完毕 (Generator函数的确是可以遍历的)。

   ```javascript
   //Generator函数的遍历
   function* Gen(){
       console.log('-----begin1----')
       console.log('-----begin2----')
       yield 'aaa'+'bbb';
       yield 111 + 222;
       yield {a:'123'};
       console.log('-----end1----')
       console.log('-----end2----')
   }
   var obj = Gen();
   obj.next(); //打印begin1和begin2，并返回{value: "aaabbb", done: false}
   obj.next(); //返回{value: 333, done: false}
   obj.next(); //返回{value: {a: "123"}, done: false}
   obj.next(); //打印end1和end2,返回{value: undefined, done: true}
   //通过上述示例我们可以发现几个特点：
   //1.单纯调用Gen()不会执行函数体，需要执行next(),才会执行
   //2.执行next()后会返回一个迭代格式的对象，value的值为yield后表达式的计算结果
   //3.执行next()，在遇到yield后会暂停后续的代码执行，直到下次next()的调用
   //4.next()返回结果符合Iterator接口的格式，应该可以使用for...of进行遍历
   ```

2. yield关键字

   yield是只能在generator函数中使用的关键字，意为'产出'，在函数中作为暂停执行的标记。只有在调用next()函数时才会计算yield后的表达式，所以属于懒加载。在普通方法中使用yield会报错。

   ```javascript
   var arr = [1, [[2, 3], 4], [5, 6]];
   var flat = function* (arr){
   	for(let i = 0; i < arr.length; i++){
           var item = arr[i];
           if(typeof item != 'number'){
               //处理数组(flat函数会去除数组内部的子数组)
               yield* flat(item);
           }else{
               //处理单个数
               yield item;
           }
       }
   }
   
   for(let f of flat(arr)){
       consloe.log(f); //依次执行1, 2, 3, 4, 5, 6
   }
   //这里的for循环无法使用forEach,因为forEach内部的函数属于普通函数
   
   //yield在表达式中要用括号括住，不然报错
   console.log('Hello' + yield 123); // SyntaxError
   console.log('Hello' + (yield)); // OK
   ```


3. Generator函数与Iterator接口关系

   在上回Iterator接口的介绍中，我们知道进行遍历要有[Symbol.iterator]和指向的遍历器函数，而Generator函数就是一个遍历器生产函数，所以可以直接进行遍历使用

   ```javascript
   var obj = {};
   obj[Symbol.iterator] = function* gen(){
       yield 1;
       yield 2;
       yield 3;
   }
   
   for(let i of obj){
       console.log(i); //返回1、2、3
   }
   //或者
   [...obj] //返回[1,2,3]
   //=========================
   //Generator函数自身的[Symbol.iterator]函数等于当前对象
   function* gen(){
       yield 1;
       yield 2;
       yield 3;
   }
   var a = gen();
   a[Symbol.iterator]() === a; //true
   ```

4. next()方法参数

   ```javascript
   //yield语句默认会返回undefined，但是可以通过next()的参数,将参数作为上个yield语句的返回值(所以第一个next()如果有参数会不被解释)
   function* gen(){
       var x = yield 1;
       yield 2 + x;
       yield 3;
   }
   var a = gen();
   a.next();  //{value: 1, done: false}
   a.next(10); //{value: 12, done: false} 
   //参数10会作为yield 1;的返回值，赋值给x
   
   //若不带参数会输出什么？
   var b = gen();
   a.next(); //{value: 1, done: false}
   a.next(); //{value: NaN, done: false}
   //yield语句默认会返回undefined,2+undefined为NaN
   
   //=======================
   //另一个例子
   function* fun(x){
       var y = 2 * (yield (x+1));
       var z = yield (y/3);
       return (x+y+z)
   }
   var a = fun(5);
   a.next(); //返回6(输出yield后面表达式的结果)
   a.next(12);//返回8(12作为第一个yield的结果乘以2后赋值给y,返回y/3)
   a.next(13); //返回42(x为5,y为24，z为13,13作为第二个yield的结果赋值给z)
   
   //=======================
   //使用模板输入yield
   function* data(){
       console.log('begin');
       console.log(`1. ${yield}`);
       console.log(`2. ${yield}`);
   	return '111'; 
   }
   var a = data();
   a.next();  //打印begin
   a.next(666); //打印1. 666
   a.next(888); //打印2. 888 返回{value: "111", done: true}
   ```


5. 使用for...of遍历generator函数

   ```javascript
   function* fun(){
       yield 1;
       yield 2;
       yield 3;
   }
   //使用for...of遍历不需要调用next
   for(let item of fun()){
       console.log(item); //1,2,3
   }
   
   //============
   //注意循环范围
   function* numbers() {
     yield 1
     yield 2
     return 3
     yield 4
   }
   [...numbers()] //返回[1,2](只返回return前的yield语句)
   for(let item of numbers()){
       console.log(item); //1,2
   }
   ```

6. yield*语句

   如果想在generator函数中调用另一个generator函数(其他可遍历对象)，就需要用到yield*
   
   ```javascript
   //正常调用另一个generator函数
   function* genA(){
   	yield 'a';
   }
   function* genB(){
   	yield 1;
       genA();
       yield 2;
   }
   [...genB()] //返回[1,2](不生效)
   
   //直接使用yield
   function* genA(){
   	yield 'a';
   }
   function* genB(){
   	yield 1;
       yield genA();
       yield 2;
   }
   [...genB()] //返回[1, genA, 2]
   //next可以嵌套调用
   var c = genB();
   c.next(); //{value: 1, done: false}
   c.next().value.next(); //{value: "a", done: false}
   //调用genA()的内容，只能调用一次，因为b.next()已经指向下一个元素
   c.next(); //{value: 2, done: false}
   
   //使用yield*
   function* genA(){
   	yield 'a';
   }
   function* genB(){
   	yield 1;
       yield* genA();
       yield 2;
   }
   [...genB()] //返回[1, 'a', 2]
   //说明yield*也会返回一个遍历器对象，遍历跟在后边的可遍历内容
   ```
   
   注意，如果嵌套中包含return语句的情况
   
   ```javascript
   function* genA(){
   	yield 'a';return 'b';
   }
   function* genB(){
   	yield 1;
       var x = yield* genA();
       yield x;
       yield 2;
   }
   var b = genB();
   b.next(); //{value: 1, done: false}
   b.next(); //{value: 'a', done: false}
   b.next(); //{value: 'b', done: false}(b作为genA返回值赋给了x)
   b.next(); //{value: 2, done: false}
   
   //要是去掉yield x
   function* genA(){
   	yield 'a';return 'b';
   }
   function* genB(){
   	yield 1;
       var x = yield* genA();
       console.log(x);
       yield 2;
   }
   [...genB()] //返回[1, "a", 2],打印b
   //要注意区别yield的返回值和遍历值
   ```

7. generator函数简写

   ```javascript
   var obj = {function* gen(){yield 'a'}}
   [...obj.fun()] //["a"]
   var obj = {*gen(){yield 'a'}}
   [...obj.fun()] //["a"]
   ```

   

8. generator函数注意事项

   ```javascript
   //generator函数不能当构造函数用
   function *fun(){
   	yield 1;
   }
   new fun(); //TypeError: fun is not a constructor
   
   //由于不能new实例化，generator函数中this不指向创建对象本身
   function *gen(){
   	this.a = 1;
   }
   var obj = gen();
   obj.a //undefined
   
   //处理this指向问题，将generator函数指向一个对象
   function *fun(){
   	yield this.a = 1;
   }
   var obj = {};
   var f = fun.call(obj); //改变fun指向obj对象,此时f为遍历器对象
   f.next(); //{value: 1, done: false}
   obj.a  //返回1
   
   //统一f和obj对象
   function *fun(){
   	yield this.a = 1;
   }
   var f = fun.call(fun.prototype);
   f.next(); //{value: 1, done: false}
   f.a  //返回1
   
   //将f改造成构造函数
   function *fun(){
   	yield this.a = 1;
   }
   function Fun(){
   	return fun.call(fun.prototype);
   }
   var a = new Fun();
   a.next();//{value: 1, done: false}
   a.a //返回1
   ```

9. generator函数应用

   ```javascript
   //异步操作同步化
   function* main(){
       var res = yield request("http://www...");
       var a = JONS.parse(res);
       console.log(a);
   }
   var a = main();
   
   function request(url){
       ajax(url, function(res){
           //第二次next,将res返回
           a.next(res);
       })
   }
   a.next();//发起请求
   
   //对象操作阶段化
   let jobs = [job1, job2, job3];
   let steps = [step1, step2, step3];
   //一个任务下多个步骤
   function* iterStep(steps){
       for(let item of steps){
           yield item();
       }
   }
   //遍历任务
   function* iterObj(jobs){
       for(let item of jobs){
           yield* iterStep(item.steps);
       }
   }
   //遍历多个任务，按照任务->步骤执行
   for(let step of iterObj(jobs)){
       console.log(step.id); 
   }
   ```

10. 对象部署iterator接口

    ```javascript
    function* iterObj(obj){
        for(let item of Object.keys(obj)){
            yield [item, obj[item]];
        }
    }
    
    let obj = {a: 123, b: 666}
    for(let [k, v] of iterObj(obj)){
        console.log(k, v); //a 123, b 666
    }
    ```

    