#!/bin/bash
files="old.log page.tmpl plants.json plot.tmpl"
dotfile=$HOME/.mydht
mkdir -p $dotfile
for f in $files; do
    cp config/$f $dotfile
done

web="closeup.jpg closeup_thumb.jpg view.jpg view_thumb.jpg dht.css"
mkdir -p $dotfile/web
for f in $web; do
    cp web/$f $dotfile/web
done

