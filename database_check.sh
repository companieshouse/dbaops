#!/bin/ksh
#############################################################################
#
# File:  database_check.sh
#
# Description:
# Script to check database is running and starts up if its not running
#
# History:
# When        Who                   Version  What
# 09-06-2016  Sam George            1.0      Initial version
# 29 Jun 22   Howard Dickins        1.1      New version for EC2 Failover (uses saved config files)
#
##############################################################################

trap "touch ${REF}/.INTERRUPTED; trap '' 1 2 3 15" 1 2 3 15

# setup environment variables
ORACLE_BASE=/u01/app/oracle; export ORACLE_BASE
ORACLE_HOME=/u01/app/oracle/product/12.1.0.2/db_1; export ORACLE_HOME
PATH=/u01/local/bin:/u01/bin:/u01/app/oracle/product/12.1.0.2/db_1/bin:/u01/ccs/bin:/etc:/u01/openwin/bin:/u01/local/bin:/u01/app/oracle/scripts; export PATH
LD_LIBRARY_PATH_64=/u01/app/oracle/product/12.1.0.2/db_1/lib; export LD_LIBRARY_PATH_64
LD_LIBRARY_PATH=/u01/app/oracle/product/12.1.0.2/db_1/lib32; export LD_LIBRARY_PATH
LOGFILE='/u01/app/oracle/logs/DATABASE_CHECK.log'
BACKUP_DIR=/CHP/oracle/data/config_backup
SDATE=`date +%y%m%d_%H%M`
# rm -r $LOGFILE   ## Do not over-write, we run this every minute, so lets keep a log of when it actually does a restart...

#Check Oracle SID
echo $PARMS|grep -q "sid=" || { echo "ERROR: sid= parameter not specified"; PARMERROR="Y"; return; }
SID=`echo $PARMS|awk -F"sid=" '{print $2}'|awk -F" " '{print $1}'`
grep -q "^${SID}:" /etc/oratab || { echo "ERROR: sid= parameter not in /etc/oratab"; PARMERROR="Y"; return; }

export ORACLE_SID=${SID}
export UPPER_ORACLE_SID=`printf "%s\n" "${SID}" | tr '[a-z]' '[A-Z]'`
export ORAENV_ASK=NO
. /usr/local/bin/oraenv
export ORAENV_ASK=YES


##################################################################################
#   Checking that  DB and LISTENER are up                                        #
##################################################################################
#echo "Checking DB and LISTENER are up" >$LOGFILE
db_check=`ps -ef | grep smon | grep $ORACLE_SID | wc -l`
list_check=`ps -ef | grep tns | grep LISTENER1210_1522 | wc -l`

if [ $db_check = 0 ] ; then
  if [ $list_check = 1 ] ; then
    echo "${ORACLE_SID} database down ${SDATE}" >>$LOGFILE
    if [ -d ${BACKUP_DIR} ] ; then
      # Copy in latest saved config files from BACKUP_DIR
      cp ${BACKUP_DIR}/init*    ${ORACLE_HOME}/dbs
      cp ${BACKUP_DIR}/orapw*   ${ORACLE_HOME}/dbs
      if [ ${BACKUP_DIR}/spfile${ORACLE_SID}.ora -nt ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora ]
        mv ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora.${SDATE}
        cp ${BACKUP_DIR}/spfile${ORACLE_SID}.ora  ${ORACLE_HOME}/dbs
        echo "New version of spfile${ORACLE_SID}.ora used" >>$LOGFILE
      fi
      cp ${BACKUP_DIR}/osbws*   ${ORACLE_HOME}/dbs
    fi
    sqlplus -s "/ as sysdba" <<EOF >>$LOGFILE
    startup;
    exit;
EOF
  else
    if [ $list_check = 0 ] ; then
      echo "LISTENER1210_1522 and database ${ORACLE_SID} down. ${SDATE}" >>$LOGFILE
    fi
  fi
fi


db_check1=`ps -ef | grep smon | grep $ORACLE_SID | wc -l`
list_check1=`ps -ef | grep tns | grep LISTENER1210_1522 | wc -l`

if [ $db_check1 = 1 ] ; then
  if [ $list_check = 0 ] ; then
    echo "LISTENER1210_1522 down ${SDATE} ........ RESTARTING" >>$LOGFILE
    if [ -d ${BACKUP_DIR} ] ; then
      if [ ${BACKUP_DIR}/listener.ora -nt ${ORACLE_HOME}/network/admin/listener.ora ] ; then
        mv ${ORACLE_HOME}/network/admin/listener.ora ${ORACLE_HOME}/network/admin/listener.ora.${SDATE}
        cp ${BACKUP_DIR}/listener.ora ${ORACLE_HOME}/network/admin
        echo "New version of listener.ora used" >> $LOGFILE
      fi
      if [ ${BACKUP_DIR}/tnsnames.ora -nt ${ORACLE_HOME}/network/admin/tnsnames.ora ] ; then
        mv ${ORACLE_HOME}/network/admin/tnsnames.ora ${ORACLE_HOME}/network/admin/tnsnames.ora.${SDATE}
        cp ${BACKUP_DIR}/tnsnames.ora ${ORACLE_HOME}/network/admin
        echo "New version of tnsnames.ora used" >> $LOGFILE
      fi
      if [ ${BACKUP_DIR}/sqlnet.ora -nt ${ORACLE_HOME}/network/admin/sqlnet.ora ] ; then
        mv ${ORACLE_HOME}/network/admin/sqlnet.ora ${ORACLE_HOME}/network/admin/sqlnet.ora.${SDATE}
        cp ${BACKUP_DIR}/sqlnet.ora   ${ORACLE_HOME}/network/admin
        echo "New version of sqlnet.ora used" >> $LOGFILE
      fi
    fi
    lsnrctl start LISTENER1210_1522  >>$LOGFILE
##else
##    if [ $list_check = 1 ] ; then
##      echo "LISTENER1210_1522 and database ${ORACLE_SID} are up and dandy...... " >>$LOGFILE
##    fi
  fi
fi

