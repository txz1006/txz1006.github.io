JVM-6(阶段复习)

#### 1.概念梳理

- Minor GC和young GC都指的是新生代的垃圾回收，两者等价
- Full GC一般指JVM所有空间(新生代、老年代、永久代)都进行垃圾回收
- Old GC一般指老年代的垃圾回收
- 由于Old GC很多情况下和Minor GC一起连用，所以会有使用Full GC代指Old GC的情况
- Marjor GC一般代指Full GC或Old GC，使用较少、需要注意分清到底指的哪个GC
- Mixed GC是G1中的特有垃圾回收，指年轻代和老年代的垃圾混合回收