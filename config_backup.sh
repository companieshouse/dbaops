#!/bin/ksh
#############################################################################
#
# File:  config_backup.sh
#
# Description:
# Script to backup copies of important config files (to be used in case of failover etc.)
#
# History:
# When        Who                   Version  What
# 29th Jun 22 Howard Dickins        1.0      Initial version
#
#
##############################################################################

trap "touch ${REF}/.INTERRUPTED; trap '' 1 2 3 15" 1 2 3 15

# setup environment variables
ORACLE_BASE=/u01/app/oracle; export ORACLE_BASE
ORACLE_HOME=/u01/app/oracle/product/12.1.0.2/db_1; export ORACLE_HOME
PATH=/u01/local/bin:/u01/bin:/u01/app/oracle/product/12.1.0.2/db_1/bin:/u01/ccs/bin:/etc:/u01/openwin/bin:/u01/local/bin:/u01/app/oracle/scripts:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin:/usr/bin:/usr/local/sbin:/usr/sbin export PATH
LD_LIBRARY_PATH_64=/u01/app/oracle/product/12.1.0.2/db_1/lib; export LD_LIBRARY_PATH_64
LD_LIBRARY_PATH=/u01/app/oracle/product/12.1.0.2/db_1/lib32; export LD_LIBRARY_PATH
LOGFILE=/u01/app/oracle/logs/config_backup.log
BACKUP_DIR=/CHP/oracle/data/config_backup

rm -r $LOGFILE

if [ ! -d ${BACKUP_DIR} ] ; then
  mkdir ${BACKUP_DIR}
fi 
cp -pr $ORACLE_HOME/dbs/init*                 ${BACKUP_DIR}
cp -pr $ORACLE_HOME/dbs/orapw*                ${BACKUP_DIR}
cp -pr $ORACLE_HOME/dbs/spfile*               ${BACKUP_DIR}
cp -pr $ORACLE_HOME/dbs/osbws*ora             ${BACKUP_DIR}

cp -pr $ORACLE_HOME/network/admin/listener*   ${BACKUP_DIR}
cp -pr $ORACLE_HOME/network/admin/tnsnames*   ${BACKUP_DIR}
cp -pr $ORACLE_HOME/network/admin/sqlnet*     ${BACKUP_DIR}

echo "Config files backed up to ${BACKUP_DIR}" > $LOGFILE
ls -ltr ${BACKUP_DIR} >> $LOGFILE

exit 0
