#!/bin/sh

PATH=$1
cd ${PATH}
DATE=$2

# 
#  Assumes once/day
if [ ! -d "storage.${DATE}" ] ; then
   cp -parl storage storage.${DATE}
fi

