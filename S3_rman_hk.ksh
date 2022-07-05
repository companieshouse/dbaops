#!/bin/ksh
################################################################################
#
# File: rman_levelx_tape_backup.ksh
#
# Description:
#
# History:
# When        Who                   Version       What
# 12-02-2008  The King              1.0           The beginning
# 28-06-2012  Iain Smith            1.1           Script altered from rman_levelx_tape_backup.ksh to be rman_levelx_DD_backup.ksh.
#                                                 This to to convert it from a tape rman backup to a NFS disk one with the disk 
#                                                 being the Data Domain backup machine.
# 20-03-2015  Rod Jenkins           1.2           Ammended for DataGuard databases 
# 20-May-22   H.Dickins             1.3           Modified for OSBWS (RMAN to S3)
#
################################################################################

trap "touch ${REF}/.INTERRUPTED; trap '' 1 2 3 15" 1 2 3 15

#set -x

################################################################################
# Function: Display Parameter Requirements
################################################################################

echo_params () {

echo "\nRMAN_LEVELX_BACKUP.KSH"
echo "\nSTARTED "`date +"%d %b %Y %T"`
echo "\nTHE FOLLOWING PARAMETERS CAN BE SPECIFIED -\n"
echo "PARAMETER          DESCRIPTION                                           VALIDATION     DEFAULT           REQD "
echo "=================  ====================================================  =============  ================  ==== "
echo "sid=xxxx           Target SID                                            /etc/oratab                      YES  "
echo "level=x            Backup level (full,incremental)                       0,1            0                  NO  "
echo ""

}

################################################################################
# Function: Check SID parameter
################################################################################

check_SID () {

echo $PARMS|grep -q "sid=" || { echo "ERROR: sid= parameter not specified"; PARMERROR="Y"; return; }
SID=`echo $PARMS|awk -F"sid=" '{print $2}'|awk -F" " '{print $1}'`
grep -q "^${SID}:" /etc/oratab || { echo "ERROR: sid= parameter not in /etc/oratab"; PARMERROR="Y"; return; }

export ORACLE_SID=${SID}
export UPPER_ORACLE_SID=`printf "%s\n" "${SID}" | tr '[a-z]' '[A-Z]'`
export ORAENV_ASK=NO
. /usr/local/bin/oraenv
export ORAENV_ASK=YES

}
export ORACLE_SID=${SID}
export LD_LIBRARY_PATH_64=${ORACLE_HOME}/lib
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib32

################################################################################
# Function: Check BACKUP LEVEL parameter
################################################################################

check_BACKUP_LEVEL () {

echo $PARMS|grep -q "level=" || { BACKUP_LEVEL=0; return; }
BACKUP_LEVEL=`echo $PARMS|awk -F"level=" '{print $2}'|awk -F" " '{print $1}'`
[[ ${BACKUP_LEVEL} = +([0-9]) ]] || { echo "ERROR: level= parameter is invalid"; PARMERROR="Y"; return; }
[ ${BACKUP_LEVEL} -eq 0 -o ${BACKUP_LEVEL} -eq 1 ] || { echo "ERROR: level= parameter is invalid"; PARMERROR="Y"; return; }

}

################################################################################
# Function: Check parameters & exit if errors
################################################################################

check_params () {

[ ${PARMERROR} = "Y" ] && { exit 4; }
echo "PARAMETERS VALIDATED AS OK"

}

################################################################################
# Function: Check RMAN OPTIONS FILE exists for SID
################################################################################

check_RMAN_OPTFILE () {

OPTFILE="/u01/app/oracle/scripts/rman/optfiles/rman.opt.${ORACLE_SID}"
[ ! -f "${OPTFILE}" ] && { echo "RMAN options file rman.opt.${ORACLE_SID} not found"; exit 4; }

}

################################################################################
# Function: Get RETENTION POLICY option
################################################################################

get_RETENTION_POLICY () {

grep -q "^RETENTION_VALUE" ${OPTFILE} || { echo "ERROR: RETENTION_VALUE option not specified in OPTFILE"; PARMERROR="Y"; return; }
RETENTION_VALUE=`grep "^RETENTION_VALUE" ${OPTFILE} | awk -F"RETENTION_VALUE" '{print $2}'|awk -F" " '{print $1}'`;
[[ ${RETENTION_VALUE} = +([0-9]) ]] || {  echo "ERROR: RETENTION_VALUE option in OPTFILE is invalid"; PARMERROR="Y"; return; }

}

################################################################################
# Function: Get CHANNELS option
################################################################################

get_CHANNELS () {

grep -q "^CHANNELS_DB" ${OPTFILE} || { echo "ERROR: CHANNELS_DB option not specified in OPTFILE"; PARMERROR="Y"; return; }
CHANNELS=`grep "^CHANNELS_DB" ${OPTFILE} | awk -F"CHANNELS_DB" '{print $2}'|awk -F" " '{print $1}'`
[[ ${CHANNELS} = +([0-9]) ]] || { echo "ERROR: CHANNELS_DB option in OPTFILE is invalid"; PARMERROR="Y"; return; }
[ ${CHANNELS} -lt 1 -o ${CHANNELS} -gt 8 ] && { echo "ERROR: CHANNELS_DB option in OPTFILE is invalid"; PARMERROR="Y"; return; }

}

################################################################################
# Function: Check rman options & exit if errors
################################################################################

check_options () {

[ ${PARMERROR} = "Y" ] && { echo "ERROR: Check OPTFILE"; exit 4; }

}

###############################################################################
# Function: Check SID is started
################################################################################

check_SID_started () {

ps -ef | grep -q -i "[o]ra_smon_${ORACLE_SID}" || { echo "\nERROR: ${ORACLE_SID} is shutdown\n"; echo "ERROR: ${ORACLE_SID} is shutdown" | echo -s "RMAN BACKUP FAILED FOR ${ORACLE_SID} - DATABASE IS SHUTDOWN!" dba_ops@companieshouse.gov.uk ; exit 4; }

}

################################################################################
# Function: Display SID run variables
################################################################################

echo_run_vars () {

echo "\nTHE SCRIPT WILL RUN USING THE FOLLOWING VALUES -\n"
echo " DATABASE SID           = ${ORACLE_SID}"
echo " SID HOME               = ${ORACLE_HOME}"
echo " RMAN OPTFILE           = ${OPTFILE}"
echo " RMAN BACKUP RETENTION  = ${RETENTION_VALUE} DAYS"
echo " RMAN BACKUP LEVEL      = ${BACKUP_LEVEL}"
echo " RMAN CHANNELS          = ${CHANNELS}"

}

################################################################################
# Function: Backup database 
################################################################################

backup_database () {

echo "\nIT'S BACKUP TIME! ..."

BACKUP_START_TIME=`date +%y%m%d_%H%M`

LOGFILE="/u01/app/oracle/logs/rman/rman_${ORACLE_SID}_housekeeping_${BACKUP_START_TIME}.log"
echo 'Backup Start Time - '${BACKUP_START_TIME} > ${LOGFILE}
#RC_BACKUPDB="Pending"

# rman nocatalog <<EOF >> ${LOGFILE} 
# connect target / ;
# RUN
# {
	# allocate channel c1aws type sbt parms = 'SBT_LIBRARY=/u01/app/oracle/product/12.1.0.2/db_1/lib/libosbws.so,SBT_PARMS=(OSB_WS_PFILE=/u01/app/oracle/product/12.1.0.2/db_1/dbs/osbws${ORACLE_SID}.ora)';
        # backup archivelog all format '%d_%s_%p_%T.ark' tag '${ORACLE_SID}_ARC_LOG_${BACKUP_START_TIME}' delete input;
        # backup current controlfile format  '%d_%s_%p_%T.ctf' tag '${ORACLE_SID}_CTL_${BACKUP_START_TIME}';
# }
# EOF
# 
# RC=$?; echo "DB Backup Return Code = ${RC}"
# BACKUP_END_TIME=`date +%y%m%d_%H%M`
# echo 'Backup End Time - '${BACKUP_END_TIME} >> ${LOGFILE}

# [ ${RC} -eq 0 ] && { RC_BACKUPDB="Success"; } || { RC_BACKUPDB="Failed"; echo 'BACKUP STATUS - '${RC_BACKUPDB} >> ${LOGFILE}; echo -s "RMAN BACKUP FAILED FOR ${ORACLE_SID} " dba_ops@companieshouse.gov.uk <${LOGFILE}; exit; } # Exit if backup failed
echo 'BACKUP STATUS - '${RC_BACKUPDB} >> ${LOGFILE}
}

################################################################################
# Function: Purge backups
################################################################################

purge_backups () {

echo "\nIT'S HAMMER TIME! ..."

rman nocatalog <<EOF >> ${LOGFILE}
connect target /;
allocate channel for maintenance device type sbt parms = 'SBT_LIBRARY=/u01/app/oracle/product/12.1.0.2/db_1/lib/libosbws.so,SBT_PARMS=(OSB_WS_PFILE=/u01/app/oracle/product/12.1.0.2/db_1/dbs/osbws${ORACLE_SID}.ora)';
configure retention policy to recovery window of ${RETENTION_VALUE} days;
list backup summary;
crosscheck backup;
report obsolete;
delete force noprompt obsolete device type SBT;
delete force noprompt expired backup device type SBT;
delete force noprompt backup completed before 'sysdate-14';
EOF

}

################################################################################
# MAIN TRAIN
################################################################################

PATH=/u01/app/oracle/product/12.1.0.2/db_1/bin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin
NLS_DATE_FORMAT="DD-MON-YYYY.HH24:MI:SS" ; export NLS_DATE_FORMAT
echo_params				              # Echo parameters that can be entered
PARMS=$*; PARMERROR="N"			              # Extract parameters entered
check_SID             			              # Validate SID parameter
PATH=$PATH:$ORACLE_HOME/bin                           # Update PATH
check_BACKUP_LEVEL   			              # Validate BACKUP_LEVEL parameter
check_params   				              # Exit if any parameter errors
check_RMAN_OPTFILE			              # Check SID rman.opt file exists
get_RETENTION_POLICY			              # Extract RETENTION_POLICY option
get_CHANNELS       			              # Extract CHANNELS option
check_options				              # Exit if any option errors
check_SID_started    			              # Check SID is running
echo_run_vars 				              # Display run variables
backup_database                                       # Backup db 
purge_backups                                         # Remove obsolete and expired backups


MESSAGE=`cat $LOGFILE |  egrep "Starting|ORA-|RMAN-|Finished|Recovery Manager complete"`
#mail -s "RMAN backup log check for $ORACLE_SID " dba_ops@companieshouse.gov.uk <$MESSAGE
