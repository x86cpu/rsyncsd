# rsyncsd
Rsync Android internal/extermnal storage via SSH

## Requirements
* root - Needed for script to run
* ssh/scp - Either via Magisk module or built-in (ex: Lineage)
* ssh-keygen - Only needed to setup keys.
* Some *cron-like* program to run the script (tested against):
   * https://play.google.com/store/apps/details?id=os.tools.scriptmanager
   * https://play.google.com/store/apps/details?id=os.tools.scriptmanagerpro

## Files
* busybox - Tested arm binary for busybox
* rsync - Tested rsync arm binary
* rsync.exclude - Example rsync.exclude to ignore some files or directories.
* sshrsync.sh - The main script that processes it all
* sshrsync.config - Configuration items to change (you should only need to change this file)
* hardlink.sh - A script that will create hardlinked backups for your **storage** directory dated (does not cleanup), do not install if you don't want this.
* x86cpu-ssh-client-1.00.zip - A Magisk module that will provide ssh/scp/ssh-keygen binaries
 
 ## Install
* Change the **REMOTE_** varibles in the *sshrsync.config* for your envionment ( see [Config](#config) )
* Review and adjust *rsync.exclude* file as necessary
* Create a backup directory on your SD card (internal or external), set **BUDIR** to that.
* Create the backup **BUDIR** directory. (Using this as an example: */storage/8899-1234/v20/BU* )
   ```
   adb shell mkdir -p /storage/8899-1234/v20/BU/
   ```
* Create an ssh key, copy it to your backup directory (script will sync it too):
   ```
   adb shell
   su
   mkdir /data/.ssh
   ssh-keygen -t rsa  -C 'android' -N '' -f /data/.ssh/KEY
   ssh-keygen -y -f /data/.ssh/KEY
   cp -r /data/.ssh /storage/8899-1234/v20/BU/
   ```
* Copy your ssh public key to your *REMOTE_HOST* as the *REMOTE_USER*
   ```
   ssh-keygen -y -f /data/.ssh/KEY
   ```
* Test ssh works correctly with that key:
   ```
   /system/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/data/.ssh/known_hosts -i /data/.ssh/KEY ${REMOTE_USER}@${REMOTE_HOST}
   ```
* Copy or use adb to get these files to your **BUDIR**:
  * rsync
  * busybox
  * sshrsync.config
  * sshrsync.sh
  ```
  adb push rsync /storage/8899-1234/v20/BU/
  adb push busybox /storage/8899-1234/v20/BU/
  adb push sshrsync.config /storage/8899-1234/v20/BU/
  adb push sshrsync.sh /storage/8899-1234/v20/BU/
  ```
* Copy these files to your defined *REMOTE_PATH* on your *REMOTE_HOST* as the *REMOTE_USER*
  * rsync
  * busybox
  * rsync.exclude
* Test the inital script, watch output to ensure things are working. First time take take a while. You can CTRL-C to stop it and adjust **rsync.exclude** file (ON the *REMOTE_HOST* only) as necessary.
   ```
   adb shell
   su
   cd /storage/8899-1234/v20/BU/
   sh ./sshrsync.sh
   ```
* Add to your *cron-like* program of choice to run once daily.   
   
 ## Config

 * **REMOTE_USER** - The username to ssh in as
 * **REMOTE_HOST** - The remote hostname to use.
 * **REMOTE_IP** - If this is not empty, it will override the given **REMOTE_HOST**
 * **REMOTE_RSYNC** - Typically */usr/bin/rsync*
 * **SCP=** - scp binary, default set to */system/bin/scp*
 * **SSH=** - ssh binary, default set to */system/bin/ssh*
 * **BUDIR** - The backup directory relative to /storage/8899-1234 or /sdcard if no external SD support
 * **POST_SCRIPT** - A script to run at the end of the backup, it is given two arguments: $REMOTE_PATH `date '+%m-%d-%Y'`

