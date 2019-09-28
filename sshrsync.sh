#!/system/bin/sh

#  /storage/sdcard1/s3/sshrsync.sh

#
### Setup:
#
# login as root, generate a key:
# adb shell
# su
#
# mkdir /data/.ssh
# ssh-keygen -t rsa  -C 'android' -N '' -f /data/.ssh/KEY
#
# Will output rsa secret key to '/data/.ssh/KEY'
# Copy public to your authorized_keys files where going to.
# ssh-keygen -y -f /data/.ssh/KEY
#
### copy the contents to your remote server into the authorized_keys2 file
### ssh using the system ssh and verify you can login without a password
## Test it
#
# root@android:/ # /system/bin/ssh -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/data/.ssh/known_hosts' -i /data/.ssh/KEY USER@HOST
# Last login: Sat Nov  9 15:42:48 2013 from s3
#
# Make a backup dir in your sd card (internal or external),
# BUDIR .. cp your /data/.ssh/KEY and these other files there:
#
# mkdir -p /storage/8899-1234/v20/BU
# cp -r /data/.ssh /storage/8899-1234/v20/BU
# rsync
# busybox
#
#
# On the REMOTE_HOST side in the REMOTE_PATH
# Put these files:
#
# busybox --- same as in Backup
# rsync --- same as in Backup
# hardlink.sh
# rsync.exclude
# sshrsync.sh
#
###


#
# Get full dir for starting path
DIR=`dirname $0`
cd ${DIR}
DIR=`pwd`
. ${DIR}/sshrsync.config
BASE=`basename $0`
PROGRAM="${DIR}/${BASE}"

#
# Detect SD name and internal only support
cd /
SD=`ls -d storage/????-???? 2>/dev/null`
if [ "${SD}" = "" ] ; then
   INTERNAL=1
   SD="/sdcard"
   RW=""
else
   RW=`basename ${SD}`
   SD="/${SD}"
fi

# No need to change
SSHARGS="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/data/.ssh/known_hosts -i /data/.ssh/KEY"

### Check to ensure you are powered (AC/USB)
##AC=`cat /sys/class/power_supply/ac/online`
if [ -f "/sys/class/power_supply/ac/charging_enabled" ] ; then
   AC=`cat /sys/class/power_supply/ac/charging_enabled`
   echo "AC /sys/class/power_supply/ac/charging_enabled = ${AC}"
else
   AC=0
fi
if [ -f "/sys/class/power_supply/usb/online" ] ; then
   USB=`cat /sys/class/power_supply/usb/online`
   echo "USB /sys/class/power_supply/usb/online = ${USB}"
else
   USB=0
fi
#
# Backup direcotory relative to SD card (or internal SD)
if [ -f "/sys/class/power_supply/battery/charging_enabled" ] ; then
   BAT=`cat /sys/class/power_supply/battery/charging_enabled`
   echo "BAT /sys/class/power_supply/battery/charging_enabled = ${BAT}"
else
   BAT=0
fi
if [ -f "/sys/class/power_supply/battery/capacity" ] ; then
   CAP=`cat /sys/class/power_supply/battery/capacity`
   echo "CAP /sys/class/power_supply/battery/capacity = ${CAP}"
else
   CAP=0
fi
if [ -f "/sys/class/power_supply/sec-charger/status" ] ; then
   SEC=`cat /sys/class/power_supply/sec-charger/status`
   echo "SEC /sys/class/power_supply/sec-charger/status = ${SEC}"
else
   SEC="Battery"
fi


if [ "$1" == "INTERNAL" ] ; then
   INTERNAL=1
   RW=""
   shift
fi

if [ "${USB}" -eq 0 -a "${CAP}" -ne 100 -a "$1" == "" ] ; then
   echo " "
   echo "**ERROR: Not charging."
   echo " "
   exit 25
fi

if [ -x "/system/bin/scp" ] ; then
   SCP="/system/bin/scp"
else
   echo "Missing SCP!!"
   exit 0
fi

if [ -x "/system/bin/ssh" ] ; then
   SSH="/system/bin/ssh"
else
   echo "Missing SSH!!"
   exit 0
fi

#
# Missing KEY.. retreive from local BUDIR
ERROR=0
if [ ! -f "/data/.ssh/KEY" ] ; then
   mkdir -p /data/.ssh
   FILES="KEY KEY.pub known_hosts"
   for FILE in ${FILES} ; do
      if [ -f "/${SD}/${BUDIR}/.ssh/${FILE}" ] ; then
         cp /${SD}/${BUDIR}/.ssh/${FILE} /data/.ssh/
         chmod 600 /data/.ssh/${FILE}
      else
         echo "Missing ${FILE}"
         if [ "${FILE}" != "known_hosts" ] ; then
            ERROR=1
         fi
      fi
   done
fi
if [ "${ERROR}" = "1" ] ; then
   exit 1
fi

#
# Get rsync and static busybox setup
FILES="rsync busybox"
for FILE in ${FILES} ; do
   if [ ! -x "/data/${FILE}" ] ; then
      if [ -f "/${SD}/${BUDIR}/${FILE}" ] ; then
         cp /${SD}/${BUDIR}/${FILE} /data/${FILE}
         chmod 755 /data/${FILE}
      else
         echo ${SCP} ${SSHARGS} ${REMOTE_USER}@${INIT_HOST}:${REMOTE_PATH}/${FILE} /data/${FILE}
         ${SCP} ${SSHARGS} ${REMOTE_USER}@${INIT_HOST}:${REMOTE_PATH}/${FILE} /data/${FILE}
         cp /data/${FILE} /${SD}/${BUDIR}/${FILE}
         chmod 755 /data/${FILE}
      fi
   fi
done

#
# Check we finished
ERROR=0
if [ -x "/data/rsync" ] ; then
   RSYNC="/data/rsync"
else
   echo "Missing rsync"
   ERROR=1
fi
if [ -x "/data/busybox" ] ; then
   BUSYBOX="/data/busybox"
else
   echo "Missing busybox"
   ERROR=1
fi
if [ "${ERROR}" = "1" ] ; then
   exit 1
fi

## Get DNS
DNS=`getprop net.dns1`
if [ "${REMOTE_IP}" = "" ] ; then
   REMOTEIP=`${BUSYBOX} nslookup ${REMOTE_HOST} ${DNS} | ${BUSYBOX} tail -1  | ${BUSYBOX} awk '{printf $3}'`
else
   REMOTEIP=${REMOTE_IP}
fi

#
### Remote IP (ping work by IP only)

${BUSYBOX} ping -c 1 ${REMOTEIP}
RC=$?
if [ ${RC} -eq 1 ] ; then
 # Failed to ping remote host, try the DNS
   ${BUSYBOX} ping -c 1 ${DNS}
   RC=$?
fi

#
# Checks return code, if server is down it will not sync (in case you are not home at that time)
if [ ${RC} -eq 1 ] ; then
   echo " "
   echo "**ERROR: Failed to ping remote host, exiting...."
   echo " "
   exit 255
fi

SCP="${SCP} ${SSHARGS} "
SSH="${SSH} ${SSHARGS} "
SSHUSER="${REMOTE_USER}@${REMOTEIP}"

if [ `ps | egrep -c "${RSYNC}"` -ge 1 ] ; then
   echo " "
   echo "**ERROR: Already running a ${RSYNC}"
   echo " "
   exit 9
fi

# ensure that directory exists first
${SSH} ${SSHUSER} mkdir -p ${REMOTE_PATH}

#
# Copy rsync.exclude from remote
echo ${SCP} ${SSHUSER}:${REMOTE_PATH}/rsync.exclude /data/rsync.exclude
${SCP} ${SSHUSER}:${REMOTE_PATH}/rsync.exclude /data/rsync.exclude

# 
#
# First back myself, the config, and excludes up:
echo ${SCP} ${PROGRAM} /data/rsync.exclude ${DIR}/sshrsync.config ${SSHUSER}:${REMOTE_PATH}
${SCP} ${PROGRAM} /data/rsync.exclude ${DIR}/sshrsync.config ${SSHUSER}:${REMOTE_PATH}

# Mark the "start" time
/system/bin/date > /sdcard/start
echo ${SCP} /sdcard/start ${SSHUSER}:${REMOTE_PATH}
${SCP} /sdcard/start ${SSHUSER}:${REMOTE_PATH}

### options for rsync (look then up)
OPTIONS="--stats --delete --delete-excluded --progress --exclude-from=/data/rsync.exclude"
#
# It is needed to ignore permsions/owner/group since sdcard will cause issues syncing
# if you try it changes permission to 0100 which causes the rsync to lose write permissions
# these options work, adjust at your own risk
#
OPTIONS="${OPTIONS} --rsync-path=${REMOTE_RSYNC} -azR --no-p --no-g --no-o --chmod=ugo=rwX -k --delete-excluded"
#
# Ignore errors and keep going
OPTIONS="${OPTIONS} --ignore-errors "

DATE=`/system/bin/date '+%m-%d-%Y'`
DOW=`/system/bin/date +%a`
mkdir -p /${SD}/s3/BU/${DOW}
cp /data/misc/wifi/WifiConfigStore.xml /data/misc/wifi/wpa_supplicant.conf /data/misc/bluedroid/bt_config.conf /${SD}/${BUDIR}/${DOW}

# Ok....need to loop here if the Return Code on RSYNC is 127 (network intruppted), however sleep for 30 seconds before trying again

RC=127

while [ ${RC} -ne 0 ] ; do
## Ping again here
   ${BUSYBOX} ping -c 1 ${REMOTEIP}
   RC=$?
   if [ ${RC} -eq 1 ] ; then
     # Failed to ping remote host, try the DNS
      ${BUSYBOX} ping -c 1 ${DNS}
      RC=$?
   fi

### Checks return code, if server is down it will not sync (in case you are not home at that time)
# Lost net if we cannot pig
   if [ ${RC} -eq 1 ] ; then
      echo "ERROR: Failed to ping remote host/dns, exiting...."
      exit 255
   fi
# Ok to go, rsync away
   cd /
# backup the internal and external (two passes)
# This is the sdcard first
   FILES="data/.ssh data/rsync storage/self/primary "
   echo "${RSYNC} ${OPTIONS} -e \"${SSH}\" ${FILES} ${SSHUSER}:${REMOTE_PATH}"
   ${RSYNC} ${OPTIONS} -e "${SSH}" ${FILES} ${SSHUSER}:${REMOTE_PATH}
# If we are NOT internal only, do the next part
   if [ "${INTERNAL}" = "0" ] ; then
      if [ "${RW}" != "" ] ; then
         cd ${SD}/..
         echo "${RSYNC} ${OPTIONS} -e \"${SSH}\" ${RW}/ ${SSHUSER}:${REMOTE_PATH}/storage"
         ${RSYNC} ${OPTIONS} -e "${SSH}" ${RW}/ ${SSHUSER}:${REMOTE_PATH}/storage
      fi
   fi

   RC=$?
   echo "RC=${RC}"

# If RC is 127, then the network was interuppted.....sleep for 30 seconds hoping the network will restore, then try again.
# probably re-run if RC anything other than 0
   if [ $RC -ne 0 ] ; then
      echo "Failure, sleeping 10 seconds...."
      sleep 10
   fi
done
#
# 
# hardlink files.
${SSH} ${SSHUSER} ${REMOTE_PATH}/hardlink.sh ${REMOTE_PATH} ${DATE}

### Send last backup...
/system/bin/date > /sdcard/last
echo ${SCP} /sdcard/last ${SSHUSER}:${REMOTE_PATH}
${SCP} /sdcard/last ${SSHUSER}:${REMOTE_PATH}

#
# Done, exit 0
exit 0
