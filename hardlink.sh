#!/bin/sh

PATH=$1
cd ${PATH}
DATE=$2

if [ ! -d "storage.${DATE}" ] ; then
   cp -parl storage storage.${DATE}
fi

