#!/usr/bin/env bash


STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
diff=1
host=$1
tmppath=/scripts/nagios
site=example.com

if [ $# -lt 1 ]; then
    echo usage $0 host
    exit $STATE_UNKNOWN
fi


if [ ! -f  $tmppath/$site-checksum-$host.lst ]; then
   echo "File $tmppath/$site-checksum-$host.lst not found!"
   sudo ssh $host "find /hosting/$site/ -type f -regex '.*\.\(php\|js\|css\|htaccess\)' -exec md5sum {} \;" > $tmppath/$site-checksum-$host.lst
   #exit $STATE_WARNING
fi

   sudo ssh $host "find /hosting/$site/ -type f -regex '.*\.\(php\|js\|css\|htaccess\)' -exec md5sum {} \;" > $tmppath/$site-checksum-$host-new.lst

#Проверяем чексуммы
while read line
do
checksum_old=`echo $line | cut -d " " -f1`
file=`echo $line | cut -d " " -f2`
checksum_new=`cat  $tmppath/$site-checksum-$host-new.lst | grep -F $file | cut -d " " -f1`

if [ "$checksum_old" != "$checksum_new" ]; then
        if [ -z "$checksum_new" ]; then
                errors="$errors FILE NOT FOUND $file\n"
        else
                errors="$errors FILE DIFFERENCE $file\n"
                if [ $diff -eq 1 ]; then
                        sudo scp $host:$file /tmp/ > /dev/null 2>&1
                        fname=`basename $file`
                        flocal="${file#/hosting}"
                        flocal="/backup/site$flocal"
                        diffres=`diff $flocal /tmp/$fname`
                        errors="$errors $diffres"
                        rm /tmp/$fname
                fi
        fi
fi
unset checksum_old
unset checksum_new
done <  $tmppath/$site-checksum-$host.lst

#Проверяем не появились-ли новые файлы
while read line
do
checksum_old=`echo $line | cut -d " " -f1`
file=`echo $line | cut -d " " -f2`
checksum_old=`cat  $tmppath/$site-checksum-$host.lst | grep -F $file | cut -d " " -f1`

        if [ -z "$checksum_old" ]; then
                errors="$errors NEW FILE FOUND $file\n"
        fi

unset checksum_old
unset checksum_new
done <  $tmppath/$site-checksum-$host-new.lst

if [ -n "$errors" ]; then
        printf "Critical - files are different \n$errors"
        #echo "$errors"
        exit $STATE_CRITICAL

else
        echo "OK - all files are identical"

fi
