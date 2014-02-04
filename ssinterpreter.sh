#SysSnap Interpreter is a simple command-line script that returns a few quick things over time within the logging script.
#version 0.12
#Variables that currently aren't output and are definitely planned: apache/litespeed log.
echo "Running ... this may take a few seconds."
#here we initialize our numbers and averages. first, let us initialize.
count=0;
highload=0;
highloadlog="nothing";
avgload=0;
memfreelow=100000000; #"arbitrarily large", would rather find a better way to do this ...
memfreelog="nothing";
totmysql=0;
highmysql=0;
highmysqllog="nothing";
totproc=0;
highproc=0;
highproclog="nothing";
totcon=0;
highcon=0;
highconlog="nothing";
highdisk=0;
highdisklog=0;
privvmerror="no";
privvmlog=".";
totpersec=0;
highpersec=0;
apacheconlog="nothing";
apache=1;
maxdata="";
maxheld=0;
barrier=0;
#automatically set variables
#this checks for apache within the logs and picks whether it should grab apache or litespeed. may take this out for speed/legibility later.
test=`grep lsws /root/system-snapshot/current`
if [ -z $test ]; then
  apache=""
fi
#this checks for maxdata being on within the logs.
test=`grep maxdatalog /root/system-snapshot/current`
if [ $test ]; then
  maxdata=1
fi
#variables only in the loop:
#logfile, loadavg
#now we start the actual program
#grab all the logfiles
for logfile in $(/bin/ls -A /root/system-snapshot/*/*.log);
  do
  #count!
  count=$(( $count + 1 ));
  #grab the load average [1 minute average] from each log. this requires top to have its top line in line 2.
  loadavg=`cat $logfile | head -n 2 | rev | awk '{print $3}' | rev | awk -F"." '{print $1}'`;
  #adding up the average load so we can divide it by count at the end of the program to find the average load.
  avgload=$(( $avgload + $loadavg ));
  #if the load we're adding now is higher than our current high load, write it down!
  if [ $loadavg -gt $highload ]; then
    highloadlog=$logfile;
    highload=$loadavg;
  fi;
  
  #quick memory check.
  memfree=`grep MemFree $logfile | awk '{print $2}'`
  if [ $memfree -lt $memfreelow ]; then
    memfreelow=$memfree;
    memfreelog=$logfile;
  fi

  #mysql logs.
  #let's grab the mysql output for each run and put it in a separate logfile!
  sed -n '/mysqllog/,/vmstatlog/p' $logfile | tail -n +5 | head -n -2 | cut -d"|" -f9 >> /tmp/mysqlsyssnaplog.txt
  #also let's get the total numer of mysql processes and average it like the load average.
  mysqlcon=`sed -n '/mysqllog/,/vmstatlog/p' $logfile | tail -n +5 | head -n -2 | wc -l`
  totmysql=$(( $totmysql + $mysqlcon ))
  if [ $mysqlcon -gt $highmysql ]; then
    highmysql=$mysqlcon;
    highmysqllog=$logfile;
  fi;
  
  #psauwwxf logs.
  #let's grab ps auwwxf!
  sed -n '/psauwwxflog/,/netstatlog/p' $logfile | head -n -1 | tail -n +3 >> /tmp/psauwwxfsyssnaplog.txt
  #also let's get the total number of ps auwwxf processes and average it like the load average.
  processes=`sed -n '/psauwwxflog/,/netstatlog/p' $logfile | head -n -1 | tail -n +3 | wc -l`
  totproc=$(( $totproc + $processes ))
  if [ $processes -gt $highproc ]; then
    highproc=$processes;
    highproclog=$logfile;
  fi;

  #netstat logs.
  #let's grab netstat! 
  sed -n '/netstatlog/,/diskspacelog/p' $logfile | head -n -1 | tail -n +4 >> /tmp/netstatsyssnaplog.txt
  #let's get the total number of connections and see if it's the most. if so, oh yeah.
  connections=`sed -n '/netstatlog/,/diskspacelog/p' $logfile | grep CONNECTED | wc -l`
  totcon=$(( $totcon + $connections ))
  if [ $connections -gt $highcon ]; then
    highcon=$connections;
    highconlog=$logfile;
  fi;


  #let's grab either apache or litespeed! need to check this for diskspace too since the outer delimiter is apache or ls depending.
  #this is not done. but currently there's something in the output anyways.
  if [ apache ]; then
    for diskusage in $(sed -n '/diskspacelog/,/apachelog/p' $logfile | awk '{print $5}' | tail -n +3 | sed s/"%"//g); 
      do 
      if [ $diskusage -gt $highdisk ]; then
        highdisk=$diskusage;
        highdisklog=$logfile;
      fi
    done
    apachepersec=`grep requests/sec $logfile | awk '{print $4}' | cut -d. -f1`;
    totpersec=$(( $apachepersec + $totpersec ));
    if [ $apachepersec -gt $highpersec ]; then
      highpersec=$apachepersec;
      apacheconlog=$logfile;
    fi
    else
    for diskusage in $(sed -n '/diskspacelog/,/litespeedlog/p' $logfile | awk '{print $5}' | sed s/"%"//g);
      do
      if [ $diskusage -gt $highdisk ]; then
        highdisk=$diskusage;
        highdisklog=$logfile;
      fi
    #sed -n '/litespeedlog/,/privvmlog/p' $logfile
    done
  fi


  #privvmpages!
  if [ -a /proc/user_beancounters ]; then
    maxheld=`tail -n 1 $logfile | awk '{print $3}'`
    barrier=`tail -n 1 $logfile | awk '{print $4}'`
    if [ $maxheld -lt $barrier ]; then :
      else privvmerror="an"; 
      privvmlog=$logfile
    fi
  fi
  #max-data here but unnecessary
done


#archives old interpreted logs
if [ -f /root/sys-snap-interpreter-log.txt ]; then
  logdate=`cat sys-snap-interpreter-log.txt | head -n1 | awk '{print $2}'`
  mv /root/sys-snap-interpreter-log.txt /root/sys-snap-interpreter-log-$logdate.txt
fi


#Let's say what we found now. output!
#this grabs the data and replaces spaces with underlines so it writes the log to a new place in /root . everything else is relatively self-descriptive.
echo Date: `date | sed s/" "/_/g` | tee -a /root/sys-snap-interpreter-log.txt
echo Average load: $(( $avgload / $count )) | tee -a /root/sys-snap-interpreter-log.txt
echo Highest load: $highload in $highloadlog | tee -a /root/sys-snap-interpreter-log.txt
echo Lowest free memory was $memfreelow `grep MemFree $memfreelog | awk '{print $3}'` in $memfreelog | tee -a /root/sys-snap-interpreter-log.txt
echo Average MySQL connections: $(( $totmysql / $count )) | tee -a /root/sys-snap-interpreter-log.txt
echo Highest MySQL connections: $highmysql in $highmysqllog | tee -a /root/sys-snap-interpreter-log.txt
echo Average number of processes: $(( $totproc / $count )) | tee -a /root/sys-snap-interpreter-log.txt
echo Highest number of processes: $highproc in $highproclog | tee -a /root/sys-snap-interpreter-log.txt
echo Average number of netstat connections: $(( $totcon / $count )) | tee -a /root/sys-snap-interpreter-log.txt
echo Highest number of netstat connections: $highcon in $highconlog | tee -a /root/sys-snap-interpreter-log.txt
echo Highest diskspace usage: $highdisk percent in $highdisklog | tee -a /root/sys-snap-interpreter-log.txt
echo There is $privvmerror issue with privvm in the log file $privvmlog | tee -a /root/sys-snap-interpreter-log.txt
if [[ -z $apache ]] ; then
  #sed -n '/litespeedlog/,/apachelog/p'
  echo Average bytes/s of apache connections: $(( $totpersec / $count )) | tee -a /root/sys-snap-interpreter-log.txt
  echo Highest bytes/s of apache connections: $highpersec in $apacheconlog | tee -a /root/sys-snap-interpreter-log.txt
  else echo Average number of LiteSpeed connections: this is currently not working, please ignore
fi
echo Top five mysql commands: | tee -a /root/sys-snap-interpreter-log.txt
cat /tmp/mysqlsyssnaplog.txt | sort -nr | uniq -c | sort -nr | head -n5 | tee -a /root/sys-snap-interpreter-log.txt
echo Top five processes by CPU usage: | tee -a /root/sys-snap-interpreter-log.txt
cat /tmp/psauwwxfsyssnaplog.txt | sort -nr | uniq -c | sort -gk 4 | tail -n 5 | tee -a /root/sys-snap-interpreter-log.txt
echo Top five processes by memory usage: | tee -a /root/sys-snap-interpreter-log.txt
cat /tmp/psauwwxfsyssnaplog.txt | sort -nr | uniq -c | sort -gk 5 | tail -n 5 | tee -a /root/sys-snap-interpreter-log.txt
echo Finished! | tee -a /root/sys-snap-interpreter-log.txt
#cleans up text files made in previous loops before the script ends.
rm -f /tmp/*syssnaplog.txt
