---
title: 使用python脚本将pdf转png长图
author: VashonNie
date: 2021-07-10 14:10:00 +0800
updated: 2021-07-10 14:10:00 +0800
categories: [python]
tags: [python]
math: true
---

很多时候，大家会需要将pdf文件转换成图片格式，网上有很多工具可以实现，但是有的要收费，下面我们用python脚本pdf-to-png.py来实现这个功能

首先需要下载对应的python包

```
pip install fitz
pip install PyMuPDF
pip install Pillow 
```

包下载好之后，对应的脚本实现如下

```
import fitz
import os
from PIL import Image

'''
# 将PDF转化为图片
pdfPath pdf文件的路径
imgPath 图像要保存的文件夹
zoom_x x方向的缩放系数
zoom_y y方向的缩放系数
rotation_angle 旋转角度
'''

def pdf_image(pdfPath,imgPath,zoom_x,zoom_y,rotation_angle):
    # 打开PDF文件
    pdf = fitz.open(pdfPath)
    # 逐页读取PDF
    for pg in range(0, pdf.pageCount):
        page = pdf[pg]
        # 设置缩放和旋转系数
        trans = fitz.Matrix(zoom_x, zoom_y).preRotate(rotation_angle)
        pm = page.getPixmap(matrix=trans, alpha=False)
        # 开始写图像
        pm.writePNG(imgPath+str(pg)+".png")
    pdf.close()

'''
将上一步生成的图片合成为长图
output_path为长图的输出路径
'''

def generate_long_image(output_path):
    picture_path = output_path[:output_path.rfind('.')]
    print(picture_path)
    last_dir = os.path.dirname(picture_path)  # 上一级文件目录

    imagename = []
    # 获取单个图片
    for fn in os.listdir(picture_path):
         if fn.endswith('.png'):
            ims = [Image.open(os.path.join(picture_path, fn))]
            imagename.append(os.path.join(picture_path, fn))

    width, height = ims[0].size  # 取第一个图片尺寸
    long_canvas = Image.new(ims[0].mode, (width, height * len(ims)))  # 创建同宽，n高的白图片

    # 拼接图片
    for i, image in enumerate(ims):
        long_canvas.paste(image, box=(0, i * height))

    for j, name in  enumerate(imagename):   
        os.remove(name)
        
    long_canvas.save(os.path.join(last_dir, 'long-image.png'))  # 保存长图
    
    
pdf_image(r"C:\Users\nwx\Desktop\xxxxx.pdf",r"C:\Users\nwx\Desktop\\",5,5,0)

generate_long_image(r"C:\Users\nwx\Desktop\\")

```