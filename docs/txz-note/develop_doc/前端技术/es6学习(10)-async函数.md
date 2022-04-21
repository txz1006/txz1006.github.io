es6学习(10)-async函数

#### 一、async函数

1. async函数是Generator函数的一个语法糖，会将Generator函数的`*` 变为async，表示是一个异步操作，将yield变为await，表示需要等待返回；这样的改动使语意变得更加清晰。

   ```javascript
   //async函数有两个特点
   //1.会自动执行遍历Generator函数
   //2.返回一个Promise对象
   
   async function fun(x){
       let i = await x+1;
       console.log(i);
       let k = await i*i;
       console.log(k);
   } 
   //调用fun
   var pr = fun(2); //打印3、9
   //pr为一个promise对象
   
   //自定义Promise返回
function timeOut(ms){
       return new Promise((resolve) =>{
       	setTimeout(resolve, ms);
       })
   }
   
   async function asyncPrint(val, ms){
       await timeOut(ms);
       console.log(val);
   }
   //延迟两秒打印123
   asyncPrint('123',2000);
   ```
   

2. async函数使用的位置几乎所有的方法头前

   ```javascript
   //函数声明
   async function foo(){}
   //表达式
   var a = async function(){}
   //对象
   var obj = {
       async foo(){}
   }
   obj.foo.then()
   //箭头函数
   var obj = async () =>{}
   ```

3. async函数中，若是有错误抛出，则返回的Promise对象状态直接变为rejected

   ```javascript
   async function f(){
   	throw new Error("error");
   }
   f().then(
   	(res) => console.log(res),
       (rej) => console.log(rej)
   )
   //status:rejected
   ```

3. await命令后如果跟的Promise对象，则返回该对象的结果；如果不是，则作为resolve的参数返回。

   ```javascript
   //返回非Promise对象直接返回
   async function f(){
       return await 123;
   }
   f().then((res)=>console.log(res)); //123
   
   //返回Promise对象，则要注意对象的请求状态
   //若存在rejected的状态对象则终止后面的操作
   async function f(){
       //reject状态的return可省略
       await Promise.reject(123);
       await Promise.resolve(234);  //不会执行
   }
   f().then(v => console.log(v)).catch(e => console.log(e));
   //打印123
   
   //可以通过try...catch继续执行
   async function f(){
       try{
           //此时的catch不会抛到对象调用的catch中
           await Promise.reject(123);
       }catch(e){}
       return await Promise.resolve(234); 
   }
   f().then(v => console.log(v)).catch(e => console.log(e));
   //打印234
   
   //上述try catch可以简写
   async function f(){
       await Promise.reject(123).catch(e=>{});
       return await Promise.resolve(234); 
   }
   ```

4. async函数的应用技巧

   ```javascript
   //若有多个await命令，由于不知道跟在后面的promise对象的状态变化
   //最好放在try catch中处理
   //实例：重试3次
   async function main(){
       for(let i = 0; i < 3; i++){
           try{
               await first();
               await second();
               await third();
               break;
           }catch(e){}
       }
   
   }
   
   //多个await命令最好同时触发，异步完成
   //使用Promise.all并发执行
   let [objA, objB] = await Promise.all([getObjA(), getObjB()])
   
   async function dbFun(db){
       let docs = [{},{},{}];
       //map操作为并发执行，每次返回一个promise对象
       let promises = docs.map((doc)=>db.post(doc));
       let res = await Promise.all(promises);
       console.log(res);
   }
   ```

   