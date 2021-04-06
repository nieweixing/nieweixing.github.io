---
title: Post文章模板
author: VashonNie
date: 2020-1-1 14:10:00 +0800
updated: 2020-1-1 14:10:00 +0800
categories: [Template,Markdown,Kubernetes]
tags: [Template,Markdown,Kubernetes]
math: true
---

该文章为个人博客模板和markdown的语法使用

# 代码配置方式
```
import java.lang.Runtime;

public class T{
    public static void main(String[] args) {
        int availProcessors = Runtime.getRuntime().availableProcessors();
        System.out.println(availProcessors);
    }
}
```

# 图片的引用

![upload-image](/assets/images/blog/a.jpg) 

# 列表

## 有序列表

* 第一条
* 第二条
* 第三条

## 无序列表

1. test1
2. test2
3. test3


# 表格

| 表头 | 表头 |
|----|----|
|第一行	|第一行|
|第二行 |第二行|
|第三行	|第三行|

# 空格插入


插入一个空格 (non-breaking space)：\&nbsp; 或  \&#160; 或      \&#xA0;  
插入两个空格 (en space)：\&ensp;     或    \&#8194;   或     \&#x2002;  
插入四个空格 (em space)：\&emsp;    或    \&#8195;   或     \&#x2003;  
插入细空格 (thin space)：\&thinsp;   或    \&#8201;  或     \&#x2009; 

# 字体加粗

**hello**

# 网站链接

<https://www.runoob.com>
