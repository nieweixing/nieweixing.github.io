#!/bin/bash

hexo clean && hexo generate
cd ..
cd nieweixing.github.io
# git pull
cd ..
cp -fr ./public/* ./nieweixing.github.io/
cd nieweixing.github.io
git add .
git commit -m "modify bolg"
git push