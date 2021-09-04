#!/bin/bash

hexo generate
cd ..
cp -fr ./public/* ./nieweixing.github.io/
cd nieweixing.github.io
git add .
git commit -m "modify bolg"
git push