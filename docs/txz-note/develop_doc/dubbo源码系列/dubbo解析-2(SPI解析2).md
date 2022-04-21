接上一章

```java
private Class<?> getAdaptiveExtensionClass() {
    //加载SPI接口配置文件中具体的实现类信息
    getExtensionClasses();
    if (cachedAdaptiveClass != null) {
        return cachedAdaptiveClass;
    }
    return cachedAdaptiveClass = createAdaptiveExtensionClass();
}
```

主要有两个方法，一是**getExtensionClasses()**，这个方法会加载SPI接口配置文件中具体的实现类信息；二是**createAdaptiveExtensionClass()**方法，继续创建扩展实例。

#### 1.获取要实例化的SPI配置

先看**getExtensionClasses()**的逻辑：

```java
private Map<String, Class<?>> getExtensionClasses() {
       Map<String, Class<?>> classes = cachedClasses.get();
       if (classes == null) {
           synchronized (cachedClasses) {
               classes = cachedClasses.get();
               if (classes == null) {
                   //缓存/resource/META-INF/下面的SPI配置文件中的class对象为一个map
                   classes = loadExtensionClasses();
                   cachedClasses.set(classes);
               }
           }
       }
       return classes;
}
```

很眼熟的逻辑，通过ExtensionLoader实例的cachedClasses缓存来存储SPI配置中的Class信息，具体的逻辑在**loadExtensionClasses()**方法中：

```java
private Map<String, Class<?>> loadExtensionClasses() {
    final SPI defaultAnnotation = type.getAnnotation(SPI.class);
    if(defaultAnnotation != null) {
        String value = defaultAnnotation.value();
        if(value != null && (value = value.trim()).length() > 0) {
            String[] names = NAME_SEPARATOR.split(value);
            if(names.length > 1) {
                throw new IllegalStateException("more than 1 default extension name on extension " + type.getName()
                        + ": " + Arrays.toString(names));
            }
            if(names.length == 1) cachedDefaultName = names[0];
        }
    }
    
    Map<String, Class<?>> extensionClasses = new HashMap<String, Class<?>>();
    //加载三个路径下的全部配置文件中的class对象信息，放入到extensionClasses Map中进行缓存
    loadFile(extensionClasses, DUBBO_INTERNAL_DIRECTORY); //META-INF/dubbo/internal/
    loadFile(extensionClasses, DUBBO_DIRECTORY); //META-INF/dubbo/
    loadFile(extensionClasses, SERVICES_DIRECTORY); //META-INF/services/
    return extensionClasses;
}
```

通过loadFile()方法来获取具体配置文件信息，并将结果存储到extensionClasses中。

```java
private void loadFile(Map<String, Class<?>> extensionClasses, String dir) {
    //获取META-INF下某个配置目录下的SPI接口配置文件路径,例如：META-INF/dubbo/internal/com.alibaba.dubbo.rpc.Protocol
    String fileName = dir + type.getName();
    try {
        Enumeration<java.net.URL> urls;
        ClassLoader classLoader = findClassLoader();
        if (classLoader != null) {
            urls = classLoader.getResources(fileName);
        } else {
            urls = ClassLoader.getSystemResources(fileName);
        }
        if (urls != null) {
            //遍历加载所有项目和jar中的fileName文件(先本地后jar包)
            while (urls.hasMoreElements()) {
                java.net.URL url = urls.nextElement();
                try {
                    BufferedReader reader = new BufferedReader(new InputStreamReader(url.openStream(), "utf-8"));
                    try {
                        String line = null;
                        //循环一行行的读取
                        while ((line = reader.readLine()) != null) {
                            final int ci = line.indexOf('#');
                            if (ci >= 0) line = line.substring(0, ci);
                            line = line.trim();
                            if (line.length() > 0) {
                                try {
                                    String name = null;
                                    int i = line.indexOf('=');
                                    if (i > 0) {
                                        //获取SPI配置关键字
                                        name = line.substring(0, i).trim();
                                        //获取关键字对应的类路径
                                        line = line.substring(i + 1).trim();
                                    }
                                    if (line.length() > 0) {
                                        //获取SPI接口实现类的class对象
                                        Class<?> clazz = Class.forName(line, true, classLoader);
                                        if (! type.isAssignableFrom(clazz)) {
                                            throw new IllegalStateException("Error when load extension class(interface: " +
                                                    type + ", class line: " + clazz.getName() + "), class " 
                                                    + clazz.getName() + "is not subtype of interface.");
                                        }
                                        //如果这个类上被@Adaptive注解标注，则直接把当前class对象作为cachedAdaptiveClass，在getAdaptiveExtensionClass()中会直接返回
                                        if (clazz.isAnnotationPresent(Adaptive.class)) {
                                            if(cachedAdaptiveClass == null) {
                                                cachedAdaptiveClass = clazz;
                                            } else if (! cachedAdaptiveClass.equals(clazz)) {
                                                throw new IllegalStateException("More than 1 adaptive class found: "
                                                        + cachedAdaptiveClass.getClass().getName()
                                                        + ", " + clazz.getClass().getName());
                                            }
                                        } else {
                                            try {
                                                //加载SPI接口项目下的class对象信息，如果这个类存在对于SPI接口参数的构造方法，则该方法是一个当前SPI接口的包装对象,存入cachedWrapperClasses Set对象中
                                                clazz.getConstructor(type);
                                                Set<Class<?>> wrappers = cachedWrapperClasses;
                                                if (wrappers == null) {
                                                    cachedWrapperClasses = new ConcurrentHashSet<Class<?>>();
                                                    wrappers = cachedWrapperClasses;
                                                }
                                                wrappers.add(clazz);
                                            } catch (NoSuchMethodException e) {
                                                //如果当前try块中没有找到有SPI参数的构造，则把关键字和class对象存储到extensionClasses中
                                                clazz.getConstructor();
                                                if (name == null || name.length() == 0) {
                                                    name = findAnnotationName(clazz);
                                                    if (name == null || name.length() == 0) {
                                                        if (clazz.getSimpleName().length() > type.getSimpleName().length()
                                                                && clazz.getSimpleName().endsWith(type.getSimpleName())) {
                                                            name = clazz.getSimpleName().substring(0, clazz.getSimpleName().length() - type.getSimpleName().length()).toLowerCase();
                                                        } else {
                                                            throw new IllegalStateException("No such extension name for the class " + clazz.getName() + " in the config " + url);
                                                        }
                                                    }
                                                }
                                                //记录被Activate注解标注的类，放入到cachedActivates中
                                                String[] names = NAME_SEPARATOR.split(name);
                                                if (names != null && names.length > 0) {
                                                    Activate activate = clazz.getAnnotation(Activate.class);
                                                    if (activate != null) {
                                                        cachedActivates.put(names[0], activate);
                                                    }
                                                    for (String n : names) {
                                                        if (! cachedNames.containsKey(clazz)) {
                                                            cachedNames.put(clazz, n);
                                                        }
                                                        Class<?> c = extensionClasses.get(n);
                                                        if (c == null) {
                                                            extensionClasses.put(n, clazz);
                                                        } else if (c != clazz) {
                                                            throw new IllegalStateException("Duplicate extension " + type.getName() + " name " + n + " on " + c.getName() + " and " + clazz.getName());
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } catch (Throwable t) {
                                    IllegalStateException e = new IllegalStateException("Failed to load extension class(interface: " + type + ", class line: " + line + ") in " + url + ", cause: " + t.getMessage(), t);
                                    exceptions.put(line, e);
                                }
                            }
                        } // end of while read lines
                    } finally {
                        reader.close();
                    }
                } catch (Throwable t) {
                    logger.error("Exception when load extension class(interface: " +
                                        type + ", class file: " + url + ") in " + url, t);
                }
            } // end of while urls
        }
    } catch (Throwable t) {
        logger.error("Exception when load extension class(interface: " +
                type + ", description file: " + fileName + ").", t);
    }
}
```

-----------------

loadExtensionClasses()方法执行完成后，我们就可以通过全局缓存extensionClasses获取SPI关键字对应的class对象，同时还初始化了以下几个变量或逻辑：

- 如果有@Adaptive注解标注的class，则会设置到cachedAdaptiveClass中直接返回，不在执行后面的createAdaptiveExtensionClass()方法了
- 如果加载的class类中存在对于SPI接口参数的构造方法，则该方法是一个当前SPI接口的包装对象，后续实例化会用到
- 如果**clazz.getConstructor(type)**没有找到有SPI参数的构造方法，则把关键字和class对象存储到extensionClasses中
- 如果**clazz.getConstructor(type)**找到有SPI参数的构造方法，则会把当前class作为SPI接口的包装类存储到cachedWrapperClasses中

#### 2.创建适应性扩展class

当**getExtensionClasses()**方法执行完成后，如果在配置中没有找到**cachedAdaptiveClass**，则会继续执行**createAdaptiveExtensionClass()**，这个方法会手动创建一个适应性的扩展class对象。

```java
//，再使用Compiler创建获取这个代理类的class对象
private Class<?> createAdaptiveExtensionClass() {
    //createAdaptiveExtensionClassCode()会创建SPI接口的代理实现类的代码字符串
    String code = createAdaptiveExtensionClassCode();
    //获取当前类的ClassLoader对象
    ClassLoader classLoader = findClassLoader();
    //使用JavassistCompiler创建这个代理实现类的Class对象
    com.alibaba.dubbo.common.compiler.Compiler compiler = ExtensionLoader.getExtensionLoader(com.alibaba.dubbo.common.compiler.Compiler.class).getAdaptiveExtension();
    return compiler.compile(code, classLoader);
}
```

从代码中我们不难发现，这个方法手动的的构建了一个适应性类的class java代码，配合当前类的ClassLoader对象，经过递归创建一个Compiler对象，使用compiler.compile()方法动态生成了一个class对象。这个生成的类是怎么样的呢？以Protocol接口为例，下面是其生成的适应性class对象：

```java
package com.alibaba.dubbo.rpc;
import com.alibaba.dubbo.common.extension.ExtensionLoader;
public class Protocol$Adpative implements com.alibaba.dubbo.rpc.Protocol {
    public void destroy() {throw new UnsupportedOperationException("method public abstract void com.alibaba.dubbo.rpc.Protocol.destroy() of interface com.alibaba.dubbo.rpc.Protocol is not adaptive method!");
    }
    public int getDefaultPort() {throw new UnsupportedOperationException("method public abstract int com.alibaba.dubbo.rpc.Protocol.getDefaultPort() of interface com.alibaba.dubbo.rpc.Protocol is not adaptive method!");
    }

    //有@Adaptive注解的会生成这样的代理方法
    public com.alibaba.dubbo.rpc.Invoker refer(java.lang.Class arg0, com.alibaba.dubbo.common.URL arg1) throws com.alibaba.dubbo.rpc.RpcException {
        if (arg1 == null) throw new IllegalArgumentException("url == null");
        com.alibaba.dubbo.common.URL url = arg1;
        //根据@Adaptive注解的参数，会从URL对象中获取不同的extName，也就是选择不同的SPI接口实现类(没有参数则默认使用@SPI注解的参数)
String extName = ( url.getProtocol() == null ? "dubbo" : url.getProtocol() );
        if(extName == null) throw new IllegalStateException("Fail to get extension(com.alibaba.dubbo.rpc.Protocol) name from url(" + url.toString() + ") use keys([protocol])");
        //获取@SPI指定实现类的实例(首次调用创建)
        com.alibaba.dubbo.rpc.Protocol extension = (com.alibaba.dubbo.rpc.Protocol)ExtensionLoader.getExtensionLoader(com.alibaba.dubbo.rpc.Protocol.class).getExtension(extName);
        return extension.refer(arg0, arg1);
    }

    public com.alibaba.dubbo.rpc.Exporter export(com.alibaba.dubbo.rpc.Invoker arg0) throws com.alibaba.dubbo.rpc.RpcException {
        if (arg0 == null) throw new IllegalArgumentException("com.alibaba.dubbo.rpc.Invoker argument == null");
        if (arg0.getUrl() == null) throw new IllegalArgumentException("com.alibaba.dubbo.rpc.Invoker argument getUrl() == null");com.alibaba.dubbo.common.URL url = arg0.getUrl();
        String extName = ( url.getProtocol() == null ? "dubbo" : url.getProtocol() );
        if(extName == null) throw new IllegalStateException("Fail to get extension(com.alibaba.dubbo.rpc.Protocol) name from url(" + url.toString() + ") use keys([protocol])");
        com.alibaba.dubbo.rpc.Protocol extension = (com.alibaba.dubbo.rpc.Protocol)ExtensionLoader.getExtensionLoader(com.alibaba.dubbo.rpc.Protocol.class).getExtension(extName);
        return extension.export(arg0);
    }
}
```

我们简单分析下这个类的成分：

- 这个类以$Adpative后缀结尾，并且实现了SPI接口Protocol
- 对比Protocol接口方法，这个类中的方法只有被@Adaptive标注才有具体的内容，没有被标注的方法会抛出is not adaptive method!的异常
- 在这些@Adaptive标注的方法中，都需要获取到com.alibaba.dubbo.common.URL对象，不管是直接入参，还是入参中含有URL成员变量的
- 这些方法再次获取了SPI接口的ExtensionLoader对象，不过具体调用的方法是getExtension(extName)，其中的extName是从URL对象中获取的

class对象创建完成后，我们再次回到createAdaptiveExtension()中，此时我们已经知道getAdaptiveExtensionClass()创建了一个$Adpative结尾的的SPI接口代理类的class对象，只剩下injectExtension(instance)一个方法了，这个方法入参就是创建了一个$Adpative类的实例。

```java
private T createAdaptiveExtension() {
    try {//getAdaptiveExtensionClass()会创建SPI接口的的代理类的Class对象
        return injectExtension((T) getAdaptiveExtensionClass().newInstance());
    } catch (Exception e) {
        throw new IllegalStateException("Can not create adaptive extenstion " + type + ", cause: " + e.getMessage(), e);
    }
}
```

最后我们来了解下injectExtension(intance)这个方法：

```java
private T injectExtension(T instance) {
    try {
        if (objectFactory != null) {
            //实例方法列表中是否存在set方法
            for (Method method : instance.getClass().getMethods()) {
                if (method.getName().startsWith("set")
                        && method.getParameterTypes().length == 1
                        && Modifier.isPublic(method.getModifiers())) {
                    Class<?> pt = method.getParameterTypes()[0];
                    try {
                        //从set方法名称中获取属性名称
                        String property = method.getName().length() > 3 ? method.getName().substring(3, 4).toLowerCase() + method.getName().substring(4) : "";
                        //创建或者获取这个成员变量
                        Object object = objectFactory.getExtension(pt, property);
                        if (object != null) {
                            method.invoke(instance, object);
                        }
                    } catch (Exception e) {
                        logger.error("fail to inject via method " + method.getName()
                                + " of interface " + type.getName() + ": " + e.getMessage(), e);
                    }
                }
            }
        }
    } catch (Exception e) {
        logger.error(e.getMessage(), e);
    }
    return instance;
}
```

#### 3.ExtensionFactory的作用

这个类中我们又遇到了objectFactory对象，这个对象我们之前提过一次，他是在ExtensionLoader类创建时，在构造方法中初始化的:

```java
    objectFactory = (type == ExtensionFactory.class ? null : ExtensionLoader.getExtensionLoader(ExtensionFactory.class).getAdaptiveExtension());
```

其中ExtensionFactory.class接口是dubbo-common模块下的一个SPI接口，我们在/resources目录下找到这个接口配置的实现类：

```
adaptive=com.alibaba.dubbo.common.extension.factory.AdaptiveExtensionFactory
spi=com.alibaba.dubbo.common.extension.factory.SpiExtensionFactory
```

其中AdaptiveExtensionFactory的class上是被@Adaptive标注的，说明其不需要手动构建$Adpative class类，也就是objectFactory指向的实例就是一个AdaptiveExtensionFactory对象：

```java
@Adaptive
public class AdaptiveExtensionFactory implements ExtensionFactory {
    
    private final List<ExtensionFactory> factories;
    
    public AdaptiveExtensionFactory() {
        ExtensionLoader<ExtensionFactory> loader = ExtensionLoader.getExtensionLoader(ExtensionFactory.class);
        List<ExtensionFactory> list = new ArrayList<ExtensionFactory>();
        //获取ExtensionFactory接口下有多少可以被创建的实现类关键字，然后进行遍历
        for (String name : loader.getSupportedExtensions()) {
            //根据关键字，创建ExtensionFactory实现类实例，放入到factories中(这里只有一个SpiExtensionFactory)
            list.add(loader.getExtension(name));
        }
        factories = Collections.unmodifiableList(list);
    }

    //injectExtension方法中执行objectFactory.getExtension(pt, property)时，会调用该方法
    public <T> T getExtension(Class<T> type, String name) {
        for (ExtensionFactory factory : factories) {
            T extension = factory.getExtension(type, name);
            if (extension != null) {
                return extension;
            }
        }
        return null;
    }

}
```

再者，在构造方法中会循环的调用ExtensionLoader.getExtension(name)方法，这个方法会创建真正的SPI接口实现类实例；由于ExtensionFactory接口的SPI配置中，只有一个spi=com.alibaba.dubbo.common.extension.factory.SpiExtensionFactory，所以当 objectFactory调用getExtension(pt, property)方法时，实际上会调用SpiExtensionFactory类的getExtension(pt, property)方法。

------------

我们回到injectExtension(T instance)方法中，简单阅读其逻辑，会发现这个方法主要作用是筛选出适应性类(不管是@Adaptive标注的类，还是手动构建的Class实例化的)方法列表中的set方法，然后通过调用objectFactory.getExtension(pt, property)，来获取一个实例，再通过反射调用set方法，给instance进行属性填充。

