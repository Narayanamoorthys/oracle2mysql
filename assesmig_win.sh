#!/bin/bash
export S_CONNECTSTRING=" / as sysdba"
export REP_CONNECT=io2o/welcome1@10.60.30.27:1521/pro
export ASSES_LOG_DIR=/cygdrive/c/Temp

if [ ! -d $ASSES_LOG_DIR ]; then
mkdir -p $ASSES_LOG_DIR
fi

cd /cygdrive/c/Temp
export VPATH=$PATH
export PATH=$PATH:/cygdrive/c/cygwin64/bin
echo $PATH
    export V_HW_MAKE=`cmd /c systeminfo | grep "System Model" | awk -F'[:]' '{ print $2 }' | sed -e 's/^[ \t]*//'`
echo $V_HW_MAKE    
export V_OS=`cmd /c ver | awk '{ print $1 " " $2 }'`
    export V_OS_VERSION=`cmd /c systeminfo | grep "OS Name" | awk -F'[:]' '{ print $2 }' | sed -e 's/^[ \t]*//'`
    export V_HW_BIT_FORMAT=`env | grep PROCESSOR_ARC | awk -F'[=]' '{ print $2 }'`
    export V_CPU=`cat /proc/cpuinfo | grep processor | wc -l`
    cpu=$V_CPU
#id=`vmstat 1 1 | grep -v cpu | grep -v - | grep -v ec | grep -v "^$" | awk '{print $16}'`
    id=0
    #export res=$(echo "scale=2; $cpu*($id/100)" | bc -l)
    #export res=${res%.*}
res=0
    if [ $res -eq 0 ]; then { export res=1; } fi
    export tmkb=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
    export frkb=`cat /proc/meminfo | grep MemFree | awk '{print $2}'`
    export V_MEM=`cmd /c set /a $tmkb/1024/1024`
    export V_FREE_MEM=`cmd /c set /a $frkb/1024/1024`

    SIDS=`sc query state= all | findstr OracleService | findstr SERVICE_NAME | awk '{ print $2}' | cut -c14- | awk '{printf ("%s%s",$0," ")}'`
    echo $SIDS
    
    export V_CPU_CONSUMED=0
    export V_DB_CONSUMED=0
    V_CPU_CONSUMED=`cmd /c typeperf -sc 1 "\processor(_total)\% idle time" | grep -v processor | grep -v command | grep -v Exiting | cut -d, -f2 | tr -d "\""`
    V_DB_CONSUMED=`cmd /c typeperf -sc 1 "\processor(_total)\% user time" | grep -v processor | grep -v command | grep -v Exiting | cut -d, -f2 | tr -d "\"" | tr -dc '[:alnum:].'`
    

for V_SID in `echo $SIDS`
do
export ORACLE_SID=$V_SID
#if [ ! -z "$ORACLE_SID" ]; then
#if [ $V_SID = "$ORACLE_SID" ]; then
export ORACLE_HOME=`sc qc OracleService$V_SID | grep BINARY_PATH_NAME | awk '{ print $3 }' | rev | cut -c16- | rev`
export PATH=$ORACLE_HOME/bin:$VPATH
V_ORACLE_HOME_OWNER=`ls -ld $ORACLE_HOME | awk '{print $3}'`
V_ORACLE_HOME="$ORACLE_HOME"

O_HOME=`sc qc OracleService$V_SID | grep BINARY_PATH_NAME | awk '{ print $3 }'`
V_DB_BIT_FORMAT=`file $O_HOME | awk '{print $2}'`
#V_DB_BIT_FORMAT=0

echo "ORACLE_SID:$ORACLE_SID"


#====================================================


V_CLUSTER_DATABASE=0
export V_CLUSTER_DATABASE

V_CONNECTSTRING=0
FLAG=0

LOGFILE="$S_TNST.log"

export ASSES_ID=`$ORACLE_HOME/bin/sqlplus -s "$REP_CONNECT" << EOF 
set pagesize 0 heading off feedback off verify off;
select ltrim(assesid.nextval) from dual;
exit;
EOF
`

export FILENAME="$ORACLE_SID"."$ASSES_ID"
export S_TNST="$ORACLE_SID"
echo $ORACLE_SID $ORACLE_HOME
echo "" > "$FILENAME"
echo
echo "========================= Start ==================================="
echo
echo "Database Discovery is started for Database 	:$S_TNST .........."
echo
echo "Please refer logfile below to find the progress of preassesment executoin for Database :$S_TNST"
echo "$FILENAME"
echo

#loadMigDetails
$ORACLE_HOME/bin/sqlplus $S_CONNECTSTRING <<EOF >SrcConnection.log
exit;
EOF

if [ -f $ASSES_LOG_DIR/SrcConnection.log ]; then
    cat $ASSES_LOG_DIR/SrcConnection.log | grep "Connected to:" > /dev/null 2>&1
    if [ $? = "0" ]; then
        echo "Source database connectivity is successful ..." >> "$ASSES_LOG_DIR\$FILENAME"
    else
        echo "Source database connectivity parameters are incorrect ..." >> "$ASSES_LOG_DIR\$FILENAME"
        continue;
    fi
else
    echo "Source Database connectivity logfile not found ..."  >> "$ASSES_LOG_DIR\$FILENAME"
    #exitMigration
    continue;
fi


echo "select cpu_count_current from v\$license;"  >$ASSES_LOG_DIR/V_SQL.sql
cpucnt=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0
set heading off feedback off verify off;
@V_SQL
exit;
EOF
`

echo "select getlicense($cpucnt,'Enterprise') from dual;"  >$ASSES_LOG_DIR/V_SQL.sql
V_LICENSE=`$ORACLE_HOME/bin/sqlplus -s "$REP_CONNECT" << EOF
set pagesize 0
set heading off feedback off verify off;
@V_SQL
exit;
EOF
`

echo "select value from v\$parameter where name='cluster_database';" >$ASSES_LOG_DIR/V_SQL.sql
V_CLUSTER_DATABASE=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0
set heading off feedback off verify off;
@V_SQL
exit;
EOF
`

echo "select value from v\$parameter where name='spfile';" >$ASSES_LOG_DIR/V_SQL.sql
V_PFILE=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL
exit;
EOF
`

echo "select value/1024/1024/1024 from v\$parameter where name='sga_max_size';" >$ASSES_LOG_DIR/V_SQL.sql
V_SGA_SIZE=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL
exit;
EOF
`

echo "select value/1024/1024/1024 from v\$parameter where name='pga_aggregate_target';" >$ASSES_LOG_DIR/V_SQL.sql
V_PGA_SIZE=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL
exit;
EOF
`

echo "select value from v\$parameter where name ='background_dump_dest';" >$ASSES_LOG_DIR/V_SQL.sql
V_ALERTLOG=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL
exit;
EOF
`
V_ALERTLOG=""
V_CLUSTER_VERSION=0

V_DB_CHARACTERSET=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0
set heading off feedback off verify off;
select VALUE from nls_database_parameters where PARAMETER='NLS_CHARACTERSET';
exit;
EOF
`

V_NLS_CHARACTERSET=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0
set heading off feedback off verify off;
select VALUE from nls_database_parameters where PARAMETER='NLS_NCHAR_CHARACTERSET';
exit;
EOF
`

V_DB_SIZE=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
select ltrim((select to_number(round(sum(bytes/1024/1024/1024))) bytes from dba_data_files) + (select to_number(round(sum(bytes/1024/1024/1024))) bytes from dba_temp_files)) db_size
from dual;
exit;
EOF
`
#V_ORACLE_HOME=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
#set pagesize 0 heading off feedback off verify off;
#select substr(FILE_SPEC,1,instr(FILE_SPEC,'lib')-2) ORACLE_HOME from dba_libraries where library_name ='DBMS_SUMADV_LIB';
#exit;
#EOF
#`


echo "select ltrim(substr(version,1,instr(version,'.',1)-1)) from v\$instance;" >$ASSES_LOG_DIR/V_SQL.sql
V_DB_VERSION=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL
exit;
EOF
`

export V_DB_EDITION=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
select substr(product,1,instr(product,'Edition')+7)from product_component_version where product like '%Edition%';
exit;
EOF
`

echo "select substr(sys_connect_by_path(program ,','), 2) csv from (select program, row_number() over (order by program) rn, count(*) OVER() cnt  from (select distinct program from v\$session where program not like 'oracle%' and program not like 'sqlplus%') vs) where rn=cnt start with rn = 1 connect by rn = PRIOR rn + 1;" >$ASSES_LOG_DIR/V_SQL.sql
export V_PROGRAM=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL
exit;
EOF
`


echo "select substr(sys_connect_by_path(module ,','), 2) csv from (select module, row_number() over (order by module) rn, count(*) OVER() cnt  from (select distinct module from v\$session where program not like 'oracle%' and program not like 'sqlplus%') vs) where rn=cnt start with rn = 1 connect by rn = PRIOR rn + 1; ">$ASSES_LOG_DIR/V_SQL.sql
export V_MODULE=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL
exit;
EOF
`

echo "select HOST_NAME from v\$instance;" >$ASSES_LOG_DIR/V_SQL.sql
V_DBHOSTNAME=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL
exit;
EOF
`

#echo "select utl_inaddr.get_host_address('$V_DBHOSTNAME') from dual;" >$ASSES_LOG_DIR/V_SQL.sql
#V_HOST_IPADDRESS=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
#set pagesize 0 heading off feedback off verify off;
#@V_SQL
#exit;
#EOF
#`

V_HOST_IPADDRESS=`cmd /c ipconfig | egrep "^IP|IPv4 Address" | cut -d : -f2`

echo "select substr(substr(platform_name,1,(instr(platform_name,' '))),1,instr(platform_name,'-')-1) from v\$database ;" >$ASSES_LOG_DIR/V_SQL.sql
V_PLATFORM_NAME=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL
exit;
EOF
`

getTPS(){
echo "select ltrim(value) from v\$sysstat where name='user commits';" >$ASSES_LOG_DIR/V_SQL.sql
export V_TXT1=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL.sql
exit;
EOF
`

$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF > /dev/null 2>&1
dbms_lock.sleep(300);
exit;
EOF

export V_TXT2=`$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF
set pagesize 0 heading off feedback off verify off;
@V_SQL.sql
exit;
EOF
`
export V_TPS=`cmd /c set /a $V_TXT2 - $V_TXT1`
}

getTPS
echo "module" $V_MODULE
V_MODULE=""
V_PROGRAM=""

#Loading the data from database
if [ "$V_DB_VERSION" = "9" ]; then
echo "inif"
$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF > $ASSES_LOG_DIR/insert1.sql
set linesize 32676 feedback off heading off pagesize 0
select 'insert into mig_asses_master (assesid,dbid,dbname,DB_CHARACTERSET,NLS_CHARACTERSET,db_size_gb,created,log_mode,OPEN_MODE,PROTECTION_MODE,DATABASE_ROLE,DATAGUARD_BROKER,cluster_database,oracle_home,alertlog,v_flag,PLATFORM_NAME) values ( $ASSES_ID'||','||dbid||','''||name||''','||'''$V_DB_CHARACTERSET'',''$V_NLS_CHARACTERSET'',$V_DB_SIZE'||','''||created||''','''||log_mode||''','''||OPEN_MODE||''','''||PROTECTION_MODE ||''','''||DATABASE_ROLE||''','''||DATAGUARD_BROKER||''',''$V_CLUSTER_DATABASE'',''$V_ORACLE_HOME'',''$V_ALERTLOG'',''X'',''$V_PLATFORM_NAME'');' from v\$database;
exit
EOF
else
$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF > $ASSES_LOG_DIR/insert1.sql
set linesize 32676 feedback off heading off pagesize 0
select 'insert into mig_asses_master (assesid,dbid,dbname,DB_CHARACTERSET,NLS_CHARACTERSET,db_size_gb,created,log_mode,OPEN_MODE,PROTECTION_MODE,DATABASE_ROLE,DATAGUARD_BROKER,DB_UNIQUE_NAME,cluster_database,oracle_home,alertlog,Program,Module,v_flag) values ( $ASSES_ID'||','||dbid||','''||name||''','||'''$V_DB_CHARACTERSET'',''$V_NLS_CHARACTERSET'',$V_DB_SIZE'||','''||created||''','''||log_mode||''','''||OPEN_MODE||''','''||PROTECTION_MODE ||''','''||DATABASE_ROLE||''','''||DATAGUARD_BROKER||''','''||DB_UNIQUE_NAME||''','||'''$V_CLUSTER_DATABASE'',''$V_ORACLE_HOME'',''$V_ALERTLOG'',''$V_PROGRAM'',''$V_MODULE'',''X'');' from v\$database;
exit
EOF

fi



$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF > $ASSES_LOG_DIR/update1.sql
set linesize 32676 feedback off heading off pagesize 0
select 'update mig_asses_master set (INSTANCE_NUMBER,INSTANCE_NAME,HOST_NAME,db_VERSION,STARTUP_TIME,STATUS,sga_size,pga_size)=(select '|| ltrim(INSTANCE_NUMBER)||','''||INSTANCE_NAME||''','''||HOST_NAME||''','''||VERSION||''','''||STARTUP_TIME||''','''||STATUS ||''','''||$V_SGA_SIZE||''','''||$V_PGA_SIZE||''' from dual ) where assesid =$ASSES_ID;' from v\$instance; 

select 'update mig_asses_master set (LICENSEINFO)=(select ''$V_LICENSE'' from dual ) where assesid =$ASSES_ID;' from dual;
select 'update mig_asses_master set (Oracle_edition)=(select ''$V_DB_EDITION'' from dual ) where assesid =$ASSES_ID;' from dual; 

select 'update mig_asses_master set (Total_Sessions_Set)= ('|| ltrim(value) ||') where assesid =$ASSES_ID ;' from v\$parameter where name='sessions';
select 'update mig_asses_master set (No_Of_Sessions_Active)= ('|| ltrim(count(1)) ||') where assesid =$ASSES_ID ;' from v\$session;
select 'update mig_asses_master set (Total_No_Of_Tables)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_objects where OBJECT_TYPE='TABLE' and OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_Partition_Tables)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_objects where OBJECT_TYPE='TABLE PARTITION' and OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_Views)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_objects where OBJECT_TYPE='VIEW' and OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_Indexes)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_objects where OBJECT_TYPE='INDEX' and OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_Procedures)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_objects where OBJECT_TYPE='PROCEDURE' and OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_Functions)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_objects where OBJECT_TYPE='FUNCTION' and OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_Packages)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_objects where OBJECT_TYPE='PACKAGE' and OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_Triggers)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_objects where OBJECT_TYPE='TRIGGER' and OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_Mviews)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_objects where OBJECT_TYPE='MATERIALIZED VIEW' and OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_DB_Users)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_users where username not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_LOBs)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_lobs where OWNER not in ('SYS','SYSTEM');
select 'update mig_asses_master set (Total_No_Of_DB_Links)= ('|| count(1) ||') where assesid =$ASSES_ID ;' from dba_db_links ;
select 'update mig_asses_master set (HOST_IPADDRESS)= (select ''$V_HOST_IPADDRESS'' from dual) where assesid =$ASSES_ID ;' from dual;
select 'commit ;' from dual;

exit;
EOF

cd $ASSES_LOG_DIR
$ORACLE_HOME/bin/sqlplus -s "$REP_CONNECT" << EOF 
commit;
@insert1.sql
commit;
@update1.sql
commit;
exit;
EOF

loadObjectValidation(){
$ORACLE_HOME/bin/sqlplus -s $S_CONNECTSTRING << EOF > $ASSES_LOG_DIR/insert.1
set linesize 32676
set feedback off
set heading off
set pagesize 0
select 'insert into mig_asses_detailed values ($ASSES_ID,''$ASSES_ENV'''||','''||owner||''','''|| object_type||''','''|| status ||''','|| count(*) || ');' from dba_objects
group by owner, object_type, status  order by owner, object_type, status;
exit;
EOF

$ORACLE_HOME/bin/sqlplus -s $S_CONNECTSTRING << EOF > $ASSES_LOG_DIR/insert.2
set linesize 32676
set feedback off
set heading off
set pagesize 0
select 'insert into mig_asses_detailed values ($ASSES_ID,''$ASSES_ENV'''||',''REGISTRY'''||','''||substr(COMP_NAME,1,30)||''','''|| substr(VERSION,1,20)||''','''|| status ||''',NULL);' from dba_registry;
exit;
EOF

$ORACLE_HOME/bin/sqlplus -s $S_CONNECTSTRING << EOF > $ASSES_LOG_DIR/insert.3
set linesize 32676
set feedback off
set heading off
set pagesize 0
select 'insert into mig_asses_detailed values ($ASSES_ID,''$ASSES_ENV'',''TABLESPACE'''||','''|| substr(TABLESPACE_NAME,1,20)||''','''|| status ||''',NULL);' from dba_tablespaces;
select 'insert into mig_asses_detailed values ($ASSES_ID,''$ASSES_ENV'''||','''||TABLESPACE_NAME||''','''|| FILE_NAME||''','''|| status ||''',NULL);' from dba_data_files;
exit;
EOF

$ORACLE_HOME/bin/sqlplus -s "$REP_CONNECT" << EOF > /dev/null 2>&1
@insert.1
@insert.2
@insert.3
commit;
exit;
EOF
}

loadObjectValidation

# OS validations "===================================================================="
echo "before if"
#if [ `hostname` = "$V_DBHOSTNAME" ]; then
#echo "DB is running on the same server"
# OS Level parameters and values 
# space details on the server
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
echo "HOSTNAME:`hostname`" >>  "$ASSES_LOG_DIR\$FILENAME"
echo "OS Information:`uname -a`" >>  "$ASSES_LOG_DIR\$FILENAME"
echo "OS Version:$V_OS_VERSION" >>  "$ASSES_LOG_DIR\$FILENAME"
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
#V_CPU=`sh cores.sh`
#V_CPU_CONSUMED=`sh cores1.sh`
#V_MEM=`sh mem.sh`
#V_FREE_MEM=`sh mem1.sh`
echo "Number of CPU's:$V_CPU" >> "$ASSES_LOG_DIR\$FILENAME"
echo "CPU's Consumed :$V_CPU_CONSUMED" >> "$ASSES_LOG_DIR\$FILENAME"
echo "Memory         :$V_MEM" >> "$ASSES_LOG_DIR\$FILENAME"
echo "Free Memory    :$V_FREE_MEM" >> "$ASSES_LOG_DIR\$FILENAME"
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
#df -g >> "$ASSES_LOG_DIR\$FILENAME"
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
echo "ORACLE_HOME		:$V_ORACLE_HOME" >> "$ASSES_LOG_DIR\$FILENAME"
echo "ORACLE_HOME OS Owner	:$V_ORACLE_HOME_OWNER" >> "$ASSES_LOG_DIR\$FILENAME"
echo "Oracle Patch Details" >> "$ASSES_LOG_DIR\$FILENAME"
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
#$V_ORACLE_HOME/OPatch/opatch lsinventory all >> "$ASSES_LOG_DIR\$FILENAME"
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"


# Cluser home patch details
FLAG=`ps -ef | grep crsd.bin | grep -v grep | wc -l | tr -d ' '`
if [ $FLAG == "1" ]; then
    V_CLUSTER_HOME=`ps -ef | grep crsd.bin | grep -v grep | awk '{print $8}' | rev | cut -d '/' -f3-`
    V_CLUSTER_HOME_OWNER=`ls -ld $V_CLUSTER_HOME | awk '{print $3}'`
    V_CLUSTER_VERSION=`$V_CLUSTER_HOME/bin/crsctl query crs activeversion | cut -d "[" -f2 | cut -d "]" -f1`
    V_NOOFNODES=`$V_CLUSTER_HOME/bin/olsnodes | wc -l`
    echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
    echo "Clusterware Details   "		 	>> "$ASSES_LOG_DIR\$FILENAME"
    echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
    echo "Cluster Home 		: $V_CLUSTER_HOME "	>> "$ASSES_LOG_DIR\$FILENAME"
    echo "Clusterware Version   : $V_CLUSTER_VERSION" 	>> "$ASSES_LOG_DIR\$FILENAME"
    echo "Number of Nodes	: $V_NOOFNODES" 		>> "$ASSES_LOG_DIR\$FILENAME"
    echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
    echo "Clusterware Patch Details" >> "$ASSES_LOG_DIR\$FILENAME"
    $V_CLUSTER_HOME/OPatch/opatch lsinventory all >> "$ASSES_LOG_DIR\$FILENAME"
    echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"

$ORACLE_HOME/bin/sqlplus -s "$REP_CONNECT" << EOF > /dev/null 2>&1
    update mig_asses_master set rac_home='$V_CLUSTER_HOME', rac_home_owner='$V_CLUSTER_HOME_OWNER' where assesid =$ASSES_ID;
    commit;
    exit;
EOF


else
    echo "No Clusterware is running " >> "$ASSES_LOG_DIR\$FILENAME"
    echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
fi

#$ORACLE_HOME/bin/sqlplus -s "$REP_CONNECT" << EOF > /dev/null 2>&1 # test.log
$ORACLE_HOME/bin/sqlplus -s "$REP_CONNECT" << EOF 
    update mig_asses_master set HW_Make='$V_HW_MAKE',HW_Bit_Format='$V_HW_BIT_FORMAT', os_version='$V_OS_VERSION', total_cpu=$V_CPU, idle_cpu=$V_CPU_CONSUMED,
    total_memory='$V_MEM',free_memory='$V_FREE_MEM', oracle_home_owner='$V_ORACLE_HOME_OWNER',Total_No_Of_TransPerSec='$V_TPS', DB_BIT_FORMAT='$V_DB_BIT_FORMAT',
    PLATFORM_NAME='$V_OS', CPU_DB_CONSUMED='$V_DB_CONSUMED'
    where assesid =$ASSES_ID;
    commit;
    exit;
EOF

#Alert log errors
if [ -f $V_ALERTLOG/alert*.log ]; then
echo "Alert log errors" >> "$ASSES_LOG_DIR\$FILENAME"
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
echo "`cat $V_ALERTLOG/alert*.log | grep "ORA-" | grep -v "WARNING"`" >> "$ASSES_LOG_DIR\$FILENAME"
fi

echo " Ulimit Details" >> "$ASSES_LOG_DIR\$FILENAME"
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
echo "`ulimit -a`" >> "$ASSES_LOG_DIR\$FILENAME"
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
if [ -f ~/.profile ]; then
    echo "Profile Details" >> "$ASSES_LOG_DIR\$FILENAME"
    echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
    cat ~/.profile  >> "$ASSES_LOG_DIR\$FILENAME"
    echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
fi


if [ -f $V_PFILE ]; then
$ORACLE_HOME/bin/sqlplus -s "$S_CONNECTSTRING" << EOF > /dev/null 2>&1
create pfile='$ASSES_LOG_DIR/init$S_TNST.ora.$ASSES_DATE.$ASSES_ID' from spfile;
exit;
EOF
elif [ -f "$V_ORACLE_HOME/dbs/init$S_TNS.ora" ]; then
echo "Database is running with pfile"
cp "$V_ORACLE_HOME/dbs/init$S_TNS.ora" "$ASSES_LOG_DIR/init$S_TNST.ora.$ASSES_DATE"
fi

echo "$V_LINE" >> "$ASSES_LOG_DIR\$FILENAME"
#fi

$ORACLE_HOME/bin/sqlplus -s "$REP_CONNECT" << EOF > /dev/null 2>&1
update mig_asses_master set v_flag ='0',asses_date=sysdate where assesid=$ASSES_ID;
commit;
exit;
EOF

echo "Database Discovery is Ended for Database:$S_TNST .........."
echo "========================= End ==================================="
echo
done
