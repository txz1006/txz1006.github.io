SAX解析XML文件

#### 一、SAX解析xml简介

SAX是Simple API for Xml的简写，主要功能是用于对xml文档进行解析。由于该方式采用的是事件驱动(callback回调机制)解析方式，所以有速度快、占内存少的优点，当然这些优点也仅限于xml的读取操作，SAX是无法对读取的XML元素进行修改的。如果要修改节点元素则需要使用DOC方式进行将xml文件读取，它会将xml读取成document树结构对象，这样可用对节点元素进行编辑操作；DOC方式的缺点也比较明显：占内存大、解析速度较慢。

所以仅用于读取xml操作，使用SAX方式是比较好的方式。

#### 二、SAX解析XML实例

创建一个解析的xml文件

```xml
<?xml version="1.0" encoding="utf-8"?>
<persons>
    <user>
        <userId>1001</userId>
        <userName>张三</userName>
    </user>
    <user>
        <userId>1002</userId>
        <userName>李四</userName>
    </user>
</persons>
```

创建一个XMLparseHandler用于自定义xml解析

```java
public class Customhandler extends DefaultHandler2 {

    List<Map> list = new ArrayList<>();
    Map map = null;
    String tag = "";

    @Override
    public void startDocument() throws SAXException {
        System.out.println("开始解析xml");
    }

    @Override
    public void startElement(String uri, String localName, String qName, Attributes attributes) throws SAXException {
        System.out.println("开始解析元素: <"+ qName + ">");
        if(qName == "user"){
            map = new HashMap();
        }
        tag = qName;
    }

    @Override
    public void characters(char[] ch, int start, int length) throws SAXException {
        String text = new String(ch, start, length).trim();
        if(text != null && !text.isEmpty() && tag!=null&& tag!=""){
            map.put(tag, text);
            if(!map.containsKey(tag)){
            }
            System.out.println("解析到元素值："+ text);
        }
    }

    @Override
    public void endElement(String uri, String localName, String qName) throws SAXException {
        System.out.println("结束解析元素: <"+ qName + ">");
        if(qName.equals("user")){
            list.add(map);
        }
        tag = "";
    }

    @Override
    public void endDocument() throws SAXException {
        System.out.println("结束解析xml");
    }
}
```

创建SAX解析对象解析xml

```java
public static void main(String[] args) throws ParserConfigurationException, SAXException, IOException {
    //创建xml解析工厂
    SAXParserFactory factory = SAXParserFactory.newInstance();
    //创建xml解析对象
    SAXParser parser = factory.newSAXParser();
    File file = new File("test/custom/user.xml");
    InputStream inputStream = new FileInputStream(file);
    Customhandler customhandler = new Customhandler();
    //方式一
    //parser.parse(inputStream, customhandler);

	//方式二
    InputSource source = new InputSource(file.toURI().toURL().toString());
    XMLReader xmlParser = parser.getXMLReader();
    xmlParser.setContentHandler(customhandler);
    xmlParser.parse(source);
    List c = customhandler.list;
    inputStream.close();
}


//打印结果为：
开始解析xml
开始解析元素: <persons>
开始解析元素: <user>
开始解析元素: <userId>
解析到元素值：1001
结束解析元素: <userId>
开始解析元素: <userName>
解析到元素值：张三
结束解析元素: <userName>
结束解析元素: <user>
开始解析元素: <user>
开始解析元素: <userId>
解析到元素值：1002
结束解析元素: <userId>
开始解析元素: <userName>
解析到元素值：李四
结束解析元素: <userName>
结束解析元素: <user>
结束解析元素: <persons>
结束解析xml
```

#### 三、SAX的实际应用

在tomcat源码中，有一个Digester对象，这个Digester是tomcat启动时，初始化各个容器(service、engine、Connetor)的执行者，而Digester执行容器初始化的依据是解析配置文件server.xml的内容，根据xml的具体配置进行来初始化容器。

下面是Digester的类的一些主要方法：

```java
//org.apache.tomcat.util.digester.Digester#parse(org.xml.sax.InputSource)
public class Digester extends DefaultHandler2 {
    
    //读取解析xml
    public Object parse(InputSource input) throws IOException, SAXException {
        configure();
        getXMLReader().parse(input);
        return root;
    }
    
    //对每个xml标签进行解析，并执行于之对应的Rule规则列表
    public void startElement(String namespaceURI, String localName, String qName, Attributes list)
        throws SAXException {
        boolean debug = log.isDebugEnabled();
        // Parse system properties
        list = updateAttributes(list);
        // Save the body text accumulated for our surrounding element
        bodyTexts.push(bodyText);
        bodyText = new StringBuilder();
        // the actual element name is either in localName or qName, depending
        // on whether the parser is namespace aware
        String name = localName;
        if ((name == null) || (name.length() < 1)) {
            name = qName;
        }

        // Compute the current matching rule
        StringBuilder sb = new StringBuilder(match);
        if (match.length() > 0) {
            sb.append('/');
        }
        sb.append(name); //根据每次xml节点的名称拼接成匹配url
        match = sb.toString();

        // Fire "begin" events for all relevant rules(根据namespaceURI匹配获取的Rule规则列表，有顺序规则)
        List<Rule> rules = getRules().match(namespaceURI, match);
        matches.push(rules);
        if ((rules != null) && (rules.size() > 0)) {
            for (Rule value : rules) {
                try {
                    Rule rule = value;
                    if (debug) {
                        log.debug("  Fire begin() for " + rule);
                    }
                    //依次执行begin方法
                    rule.begin(namespaceURI, name, list);
                } catch (Exception e) {
                    log.error("Begin event threw exception", e);
                    throw createSAXException(e);
                } catch (Error e) {
                    log.error("Begin event threw error", e);
                    throw e;
                }
            }
        } else {
            if (debug) {
                log.debug("  No rules found matching '" + match + "'.");
            }
        }

    }
}
```

与之对应的server.xml片段如下：

```xml
<Service name="Catalina">

    <Connector port="8081" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />

    <Engine name="Catalina" defaultHost="localhost">

          <Host name="localhost"  appBase="webapps"
                unpackWARs="true" autoDeploy="true">
          </Host>
    </Engine>
</Service>
```

Digester读取到上面这些xml标签后，就会从外向里进行嵌套解析，将这些标签创建为与之对应的java类实例，也就是tomcat的主体容器结构。