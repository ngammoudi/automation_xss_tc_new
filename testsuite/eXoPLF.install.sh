#!/bin/bash

if [ "${DEBUG}" == "true" ]; then
 set -xv
fi

# define databases
MONGO_DATABASE=${MONGO_DATABASE:-"chat"}
PLF_DATABASE="plf"

# Default settings
START_UP_WAIT_TIME=${START_UP_WAIT_TIME:-"108000"};
MYSQL_CONNECTION_PARAM=${MYSQL_CONNECTION_PARAM:-" -uroot -proot "}

alias ll='ls -lsa'

function clearcache
{
	echo "`date` before drop cache mem usage info:"
	free -m
	echo "`date` going to clear file system cache"
    	sudo sync
    	sudo echo 3 | sudo tee /proc/sys/vm/drop_caches
	echo "`date` after dropping cache mem usage info:"
	free -m
	
}

function backup_logs {
      rm -rf temp/* work/*
      backup_dir="backup_`date +%Y%m%d_%H%M`"
      if [ ! -d logs ]; then
	mkdir logs
      else
	mkdir logs/${backup_dir}
	zip -qr logs/quick_exceptiondb.zip logs/quick_exceptiondb
	rm -rf logs/quick_exceptiondb
	mv logs/*.* logs/${backup_dir}
	mv logs/catalina.out.* logs/catalina.out.${JMETER_SCRIPT_NAME}
	
	bzip2 logs/${backup_dir}/*log
	gzip logs/${backup_dir}/catalina.out*
      fi
}
if [ "`echo ${CONTROLLER_PARAMS} | awk '{print $4}' `" == "RE_USE" ]; then
      MODE_RE_USE="true"
    fi

    mysqladmin ${MYSQL_CONNECTION_PARAM} flush-hosts
    mysqladmin_status=$?
    if [ ${mysqladmin_status} -gt 0 ]; then
      sudo service mysql restart
      sleep 20
    fi
    MYSQL_SERVER=`mysqladmin ${MYSQL_CONNECTION_PARAM} variables | grep hostname | awk -F \| ' { print $3 } ' | sed 's| ||g'`

    if [[ -z $MYSQL_SERVER || "!$MYSQL_SERVER" == "!" ]]; then
      echo "WARNING: can not connect to the mysql server with MYSQL_CONNECTION_PARAM=$MYSQL_CONNECTION_PARAM"
      sudo service mysql restart
      sleep 20
    fi
    DATASET_TARGET_DIR=DATASET
    export LOG_FILE=logs/catalina.out.${JMETER_SCRIPT_NAME}
    export CATALINA_OUT=${LOG_FILE}
    LOG_PREFIX_INFO="[INFO]: "
    LOG_PREFIX_WARNING="[WARNING]: "
    SERVER_STARTUP_NOTIFICATION="Server startup in"

    
    unset WORKING_DIR ; export WORKING_DIR=""
    unset DATASET_FILE ; export DATASET_FILE=""
    unset DATASET_JCR_DB_NAME ; export DATASET_JCR_DB_NAME=""
    unset DATASET_IDM_DB_NAME ; export DATASET_IDM_DB_NAME=""
    WORKING_DIR=`echo ${APPLICATION_PARAMS} | awk '{ print $1}'`;
    DATASET_FILE=`echo ${APPLICATION_PARAMS} | awk '{ print $2}'`;

    echo "WORKING_DIR=${WORKING_DIR}"
    echo "DATASET_FILE=${DATASET_FILE}"
    unset JAVA_OPTS

    
    ORIGINAL_DIR=`pwd`
    echo "pushd "${WORKING_DIR}": $PWD/${WORKING_DIR}"
    ls -lsa ${WORKING_DIR}
    pushd ${WORKING_DIR}/
    iscontinue=$?
    if [ $iscontinue -eq 0 ]; then
      CURRENT_DIR=`pwd`;
      
      if [ "${MODE_RE_USE}" == "true" ]; then
	echo " ${LOG_PREFIX_INFO} backup logs then exit"
	backup_logs
	exit 0
      fi

      # restore dataset
      if [ -f "${DATASET_FILE}" ]; then
	echo " ${LOG_PREFIX_INFO} INIT DATASET  "
	if [ -d "${DATASET_TARGET_DIR}" ]; then
	  rm -rf ${DATASET_TARGET_DIR}
	fi
	mkdir ${DATASET_TARGET_DIR};
	
	unzip -q ${DATASET_FILE} -d ${DATASET_TARGET_DIR};
	echo "dataset dir: ${DATASET_TARGET_DIR}/"
	find ${DATASET_TARGET_DIR} -maxdepth 3 -type d ;

	pushd ${DATASET_TARGET_DIR}/*
	DATASET_TARGET_DIR=`pwd`;
	popd
	
	
	echo " ${LOG_PREFIX_INFO} REMOVE GATEIN DATA AND DBs "
	echo " ${LOG_PREFIX_INFO}   remove gatein data  "
	rm -rf gatein/data

	echo " ${LOG_PREFIX_INFO}   recreate database $PLF_DATABASE "
	mysqladmin -f ${MYSQL_CONNECTION_PARAM} drop -f ${PLF_DATABASE}
	mysqladmin -f ${MYSQL_CONNECTION_PARAM} create ${PLF_DATABASE}
	
	echo " ${LOG_PREFIX_INFO} RESTORE GATEIN DATA AND DBs "
	echo " ${LOG_PREFIX_INFO}   restore MONGODB "
	mongo ${MONGO_DATABASE} --eval "db.dropDatabase()"

	mongorestore -d ${MONGO_DATABASE} ${DATASET_TARGET_DIR}/data/mongo/* >> /dev/null

	rm -rf ${DATASET_TARGET_DIR}/data/mongo/

	echo " ${LOG_PREFIX_INFO}   restore gatein data  "
	mv ${DATASET_TARGET_DIR}/data gatein

	# restore data from mysql
	DATASET_DB_FILE=`ls ${DATASET_TARGET_DIR}/*.sql`
	echo " ${LOG_PREFIX_INFO} restoring databases to ${MYSQL_SERVER} from sql dump file: ${DATASET_DB_FILE} "
	mysql ${MYSQL_CONNECTION_PARAM} plf<${DATASET_DB_FILE}
	rm -rf ${WORKING_DIR}/${DATASET_TARGET_DIR:-"DATASET"}
      else
	  echo "!!!WARNING: Dataset file does not exists, no data restoration will be made"
      fi

      # clean up
      backup_logs

      echo " ${LOG_PREFIX_INFO} PLF STARTUP  "

      PLF_STARTUP_COMMAND="bash ./start_eXo.sh"

      rm -f ${DATASET_TARGET_DIR}/*.sql
      echo "Start the PLF with command: ${PLF_STARTUP_COMMAND}"
      mkdir -p ./logs
      nohup $PLF_STARTUP_COMMAND >${LOG_FILE} 2>&1 &
      export PLF_PID=$!

      wait_time_for_logfile=0;
      while [ true ]; do
	if [ ! -f ${LOG_FILE} ]; then
	  if [ $wait_time_for_logfile -le 120 ]; then
	    wait_time_for_logfile=$(( $wait_time_for_logfile + 1 ))
	    echo " ${LOG_PREFIX_INFO} Still wating for ${LOG_FILE} ... "
	    sleep 1;
	  else
	    echo " ${LOG_PREFIX_INFO} FAILED to load the application as ${LOG_FILE} does not appear after $wait_time_for_logfile seconds"
	    exit;
	    break;
	  fi
	else
	  break;
	fi
      done
      echo " ${LOG_PREFIX_INFO} Wating for the application to startup "

      for i in `eval echo {1..${START_UP_WAIT_TIME}}`; do
	  tail -150 ${LOG_FILE} | grep "${SERVER_STARTUP_NOTIFICATION}" >>/dev/null

	  if [ $? = "0" ]; then
	      START_ERROR=false
	      echo "The application started after $i seconds, follow its log file"
	      echo " -------------- APPLICATION STARTUP INFO ------------------------"
	      cat  ${LOG_FILE}
	      break;
	  fi
	  sleep 1
      done
      echo " -------------- APPLICATION PROCESS INFO ------------------------"
      ps aux | grep java | grep "${WORKING_DIR}">${ORIGINAL_DIR}/${TESTPLAN}_process.info
      
      #curl 'http://localhost:8080/trial/terms-and-conditions-action' -H 'Host: localhost:8080' --data 'checktc=true'
      #curl 'http://localhost:8080/registration/software-register-action' --data 'value=skip'

      cat ${ORIGINAL_DIR}/${TESTPLAN}_process.info
  fi
