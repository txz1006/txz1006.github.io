### Stable diffusion简介

Stable diffusion是一个扩散模型，通过不停去除噪音来获得结果的。在AI绘画早期，扩散是发生在像素空间pixel space的，不仅效果不好而且单张图大约需要10-15分钟，后来英国初创公司StabilityAI改进了模型，把核心计算从像素空间改到了潜空间(latent space)，稳定性和画质得到了极大提升，并且速度翻了几乎100倍，故名stable diffusion，从此AI绘画进入火热阶段。由于Stable diffusion是一个开源的模型，基本上后面的所有AI绘图的初创公司都是基于的这个模型，所以结果都非常相似。

要使用这项前沿技术，最简单的办法是使用云服务，对于国内同学来说，全中文提词的话使用Tiamat或者盗梦师。不过他们的质量目前都还不太好，特别是盗梦师基本上处于跟没有细调的原始开源版处于同一水平，跟国外Midjourney的品质相比差距较大；而Tiamat在艺术风格上有所改进，但是平均生成速度是50秒到3分钟左右，比较缓慢。

### Stable-diffusion-webui 简介

Stable-diffusion-webui 是一个在线的可视化平台，这个平台提供了一个直观的用户界面，无需在本地安装任何软件或库，即可使用平台上的工具和功能。用户可以上传自己的数据集或直接使用平台上的示例数据集，对数据进行可视化分析和处理，如添加、删除、拖动、缩放等等。用户还可以自定义数据集的时间范围和间隔，并选择合适的统计方法进行分析。

借助这个工具，我们可以直接在UI界面上训练、操作Stable Diffusion模型来给我创作出想要的画作。同时Stable-diffusion-webui还集成了很多好用的插件，可以让我们来任意组合Stable Diffusion相关的绘画模型。

### google Colab简介

谷歌Colab（Google Colaboratory）是一种基于云端的 Python 编程环境，可以免费使用。它可以将Python编程语言、云端存储和协作文档编辑器等功能集成在一个平台上，方便用户在线编写和运行代码、创建和分享Notebook、导入和导出数据集等等。

使用 Google Colab 无需在本地安装 Python 环境，代码可以在 Google 的服务器上运行，并享有免费的 GPU 和 TPU 资源，可以提高深度学习模型训练的速度。同时，用户也可以分享自己的代码、Notebook，与他人协作，相当于一个在线的代码分享平台。

Google Colab还支持导入主流的 Python 数据科学库，如 NumPy、Pandas、matplotlib、scikit-learn，并且可以访问 Google Drive，方便用户导入和保存数据集。

### 使用谷歌网盘+Colab部署Stable-diffusion-webui

因为财大气粗的谷歌向开发者们提供了免费的GPU算力，所以我们可以使用谷歌的服务器来跑Stable  diffusion模型来生成图片。

每一个Colab用户可以免费获得50G左右的使用空间，要注意的是，如果你长时间不使用Colab，你的空间当中的数据会被谷歌给清除掉，所以我们每次使用的时候，都需要重新安装你需要的软件。

但是呢，因为谷歌的网盘是和Colab应用互相打通的，所以我们可以把stable diffusion软件安装到谷歌网盘当中， Colab空间仅保留运行时生成的文件，所以我们可以将 Stable diffusion模型和各种webui组件安装到谷歌网盘当中，然后通过Colab来启动我们的stable diffusion程序。

