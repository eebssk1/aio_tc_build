#!/bin/sh

echo $PWD
ls -hlA

FILES=$(find m_* -type f -name "config.log")
RND=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | od -An -N2 -i | tr -d ' \n')
echo ID is $RND
echo "logs > $FILES"
echo "taring logs"
tar -zhcf conflogs_$RND.tgz $FILES
LA=$(find . -type f -name "*cross.tb2")
LB=$(find . -type f -name "*native.tb2")
if [ "x$LA" = "x" ] && [ "x$LB" = "x" ]; then
echo "taring current output"
tar -zhcf curouts_$RND.tgz out
fi

exit 0
