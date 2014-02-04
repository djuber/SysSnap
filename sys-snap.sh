#!/bin/bash
########################################################################
# SysSnap is a very simple system monitoring script.
########################################################################
#    Copyright (C) 2014
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
########################################################################

##############
# Set Options
##############

# Set the time between snapshots for formating see: man sleep
SLEEP_TIME="1m"

# The base directory under which to build the directory where snapshots are stored.
# You *MUST* put a slash at the end.
ROOT_DIR="~/"

# If you want extended data, set this to 1
# With this enabled it takes approximately 10x more space. [50k/minute vs. 500k/minute.]
MAX_DATA=""

# If you want to change the delimiter you can do that here.
#This is temporarily disabled and possibly will be removed so that I can use other delimiters per process.
#With these separate delimiters you can run something like:
# sed -n '/mysqllog/,/vmstatlog/p' $logfile
#This will give you the mysql log [to a point].
################################################################################
#  If you don't know what you're doing, don't change anything below this line
################################################################################

#######################
# Variable Conventions
# --------------------
# Variables that do not change in the main loop are in all caps.
# Variables that do get updated in the main loop are in all lowercase.
# Use underscores not dashes
#######################

##########
# Set Up
##########

# Get the date, hour, and min for various tasks
date=`date +%Y%m%d`
hour=`date +%H`
min=`date +%M`

# Expand ~ characters
T1=$(echo sa\~a${HOME}a)
T2=$(echo $ROOT_DIR | sed -e $T1)
ROOT_DIR=$T2

if [ ! -d ${ROOT_DIR} ] ; then
  echo $ROOT_DIR is not a directory
  exit 1
fi

if [ ! -w ${ROOT_DIR} ] ; then
  echo $ROOT_DIR is not writable
  exit 1
fi

# if a system-snapshot directory exists, save the data and empty it.
# if it does't, create it.  
if [ -d ${ROOT_DIR}system-snapshot ]; then
  tar -czf ${ROOT_DIR}system-snapshot.${date}.${hour}${min}.tar.gz ${ROOT_DIR}system-snapshot
  rm -fr ${ROOT_DIR}system-snapshot/*
else
  mkdir ${ROOT_DIR}system-snapshot
fi

################
# Main()
################

for ((;;)) ; do
  # update time
  date=`date`
  hour=`date +%H`
  min=`date +%M`

  # go to the next log file
  mkdir -p ${ROOT_DIR}system-snapshot/$hour
  current_interval=$hour/$min

	LOG=${ROOT_DIR}system-snapshot/$current_interval.log
	
  # Clear the log if it already exists
  [ -e $LOG ] && rm $LOG

  # ### Start actually logging ### #

  # Top output! It's simple!
  echo "toplog" >>$LOG
  top -c -n1 -b >>$LOG
  # We always have mysql on customer servers so we don't need this optional, and it is easy to read.
  echo "mysqllog" >>$LOG
  mysqladmin proc >>$LOG
  # Some vmstat information.
  echo "vmstatlog" >>$LOG
  vmstat 1 10 >>$LOG
	# Memory information.
  echo "meminfolog" >>$LOG
  cat /proc/meminfo >>$LOG
	# Ps aux, for data!
  echo "psauwwxflog" >>$LOG
  ps auwwxf >> $LOG
	# Expansive netstat.
  echo "netstatlog" >>$LOG
  netstat -anp >> $LOG
  # diskspace
  echo "diskspacelog" >>$LOG
  df -h >> $LOG

  # Automatic optional logs

  # This gets apache or litespeed status. The check checks for litespeed using litespeed's suggested way, and protects against finding the grep by isolating it.
  # LiteSpeed  logs are per http://www.litespeedtech.com/support/forum/showthread.php?t=6150.
  if [[ -z `ps -ef | grep '[l]itespeed'` ]]; then
    echo "apachelog" >>$LOG
    lynx --dump localhost/whm-server-status >>$LOG
  else
    echo "litespeedlog" >>$LOG
    cat /tmp/lshttpd/.rtreport* >>$LOG
  fi
  # This grabs privvmpages, but only if /user_beancounters exists
  if [ -a /proc/user_beancounters ]; then
    echo "privvmpageslog" >>$LOG
    cat /proc/user_beancounters | head -n2 | tail -n1 >>$LOG
    grep privvmpages /proc/user_beancounters >>$LOG
  fi

  # Optional: change top settings to enable these
  # Max Data [per original syssnap]
  if [ $MAX_DATA ]; then
    echo "max_datalog" >>$LOG
    for i in `ps aux | grep nobody | awk '{print $2}'` ; do ls -al /proc/$i | grep cwd | grep home; done >>$LOG
    lsof >>$LOG
  fi

  # Rotate the "current" pointer
  rm -rf ${ROOT_DIR}system-snapshot/current
  ln -s $LOG ${ROOT_DIR}system-snapshot/current

  sleep $SLEEP_TIME

done
#EOF
