#!/bin/bash

DEBUG_MODE=${DEBUG_MODE:-"false"}

if [ "${DEBUG_MODE}" == "true" ]; then
  set -xv
fi

  export testplan=$2;#"KS_WIKI_BENCH_005"
  export stageresultfile=${testplan}_testresult.log;
  export stageresultfile_upload=${testplan}_upload_testresult.log;
  export application_process_info=${testplan}_process.info;
  export testplan_original_config="${testplan}_ORIGINAL_CONFIG"
  export testplan_current_config="${testplan}_CURRENT_CONFIG"
  export testplan_current_testconfig="${testplan}_CURRENT_TESTCONFIG"
  export testplan_current_upload_queue="${testplan}_CURRENT_UPLOAD"
  export testplan_upload_queue="${testplan}_UPLOAD_QUEUE"
  export testplan_upload_info="${testplan}_UPLOAD_INFO"
  export testplan_upload_info_tmp="${testplan}_UPLOAD_INFO_TMP"
  export last_status="0";
  export SUCCESS_STATE="success"
  export FAILURE_STATE="failure"
  export LONES="process_identification"
  export ORIGINAL_DIR=`pwd`
  export firstline=""
  
  export APPLICATION_PARAMS=""
  export INJECTOR_PARAMS=""
  export CONTROLLER_PARAMS=""
  export TESTPLAN=$testplan
  export APPLICATION_HOST=""
  export APPLICATION_PORT=""
  export APPLICATION_PATH=""
  export TEST_FOLDER_NAME=""
  export TEST_DURATION=""

  export APPLICATION_KILL_SIGNAL=""
  export TEST_GROUP_ID=""
  

  echo "--== remove test result file ==--"
  rm -rf ${stageresultfile}
  echo "--== create empty test result file ==--"
  touch ${stageresultfile}
  chmod 777 ${stageresultfile}
  
function system_infomation
{
  # disk information
  echo " ---------------------------------- SYSTEM INFORMATION ---------------------------------- "
  echo "`date` INFO:: Disk free information"
  df -h
  # memfree
  echo "`date` INFO:: Memory free information"
  free -m
  # users
  echo "`date` INFO:: users login"
  users
  # uptime
  echo "`date` INFO:: uptime"
  uptime
  echo " -----------------------------------------------------------------------------------------"
}

# reload config from testplan_original_config to testplan_current_config
function reloadconfig
{
  echo " ++ reloadconfig ${testplan_original_config} > ${testplan_current_config}"
  reloadconfig_timestamp=`date +%F"_"%T`
  mkdir -p backup/${testplan}/${reloadconfig_timestamp}
  echo " backup ${testplan_original_config} ${testplan_current_config} ${testplan_current_upload_queue} ${testplan_upload_queue} to backup/${testplan}/${reloadconfig_timestamp}"
  cp ${testplan_original_config} ${testplan_current_config} ${testplan_current_upload_queue} ${testplan_upload_queue} backup/${testplan}/${reloadconfig_timestamp}
  # reset testplan_current_config
  cat ${testplan_original_config}>${testplan_current_config}
  
  # reset testplan_current_testconfig
  echo "">${testplan_current_testconfig}
  echo "">${testplan_current_upload_queue}
  echo "">${testplan_upload_queue}
  
  echo " -- reloadconfig"
}

output_to_report()
{
  echo $1
  echo "$1">>${testplan_upload_info}
}

exit_upload()
{
  if [ ${last_status} -eq "0" ]; then
    echo ${SUCCESS_STATE}>${stageresultfile_upload};
  else
    echo ${FAILURE_STATE}>${stageresultfile_upload};
  fi
  exit
}


#load first line from testplan_current_config, save to testplan_current_testconfig
function loadfirstconfigline_to_testplan_current_testconfig
{
    firstline=""
    echo " ++ loadfirstconfigline_to_testplan_current_testconfig";
    firstline=`egrep ^.*$ ${testplan_current_config} -m 1 -o`;
    echo "firstline=${firstline}, RESET_CODE=${RESET_CODE}"
    if [[ "x${firstline}" == "x" && "${RESET_CODE}" == "REWIND" ]]; then
      reloadconfig
      firstline=`egrep ^.*$ ${testplan_current_config} -m 1 -o`;
      if [[ "x${firstline}" == "x" || -z ${firstline} ]]; then
	firstline="false"
      fi
    fi
    echo ${firstline}>${testplan_current_testconfig};
    echo " -- loadfirstconfigline_to_testplan_current_testconfig = [${firstline}] "
    if [[ "${firstline}" == "false" || "x${firstline}" == "x" || -z ${firstline} ]]; then
      last_status="1"
    else
      last_status="0"
    fi
    echo "last_status=${last_status}"
}

# load from testplan_current_testconfig, export to variables by awk '{ print $# }'
function load_testplan_current_testconfig
{
    echo " ++ load_testplan_current_testconfig";
    APPLICATION_PARAMS=`cat ${testplan_current_testconfig} | awk -F ! '{ print $1}' `;
    INJECTOR_PARAMS=`cat ${testplan_current_testconfig} | awk -F ! '{ print $2}' `;
    CONTROLLER_PARAMS=`cat ${testplan_current_testconfig} | awk -F ! '{ print $3}' `;

    APPLICATION_KILL_SIGNAL=`echo ${CONTROLLER_PARAMS} | awk '{ print $2}'`
    TEST_FOLDER_NAME=`echo ${INJECTOR_PARAMS} | awk '{ print $1}'`
    TEST_DURATION=`echo ${INJECTOR_PARAMS} | awk '{ print $2}'`
    TEST_GROUP_ID=`echo ${INJECTOR_PARAMS} | awk '{ print $3}'`
    TEST_NOTE=`echo ${INJECTOR_PARAMS} | awk '{ print $4}'`    
    DATASET_ROW_ID=`echo ${INJECTOR_PARAMS} | awk '{ print $5}'`    
    APPLICATION_PATH=`echo $APPLICATION_PARAMS | awk '{print $1}' `
    echo " -- load_testplan_current_testconfig"
}

function stop_jmeter_running_process
{
  LONES="selenium-server-standalone firefox-bin automation_xss_confirm_scripts.sh"
  stop_a_process
}

function stop_application_deployment
{
  stop_a_process
}

function stop_a_process
{
  for i in $LONES; do
    echo " looking for processes with name contains [$i] "
    JPID=`ps aux | grep java | grep $i | awk '{print $2}'`
    if [ ! -z "$JPID" ]; then
      echo "detected lone $i (pid $JPID), killing it"
      kill -9 $JPID
    else
	echo "found no process with name contain [$i]"
    fi
  done
}



function trimfirstline
{
  echo " ++ trimfirstline"
  sed -i  -e '1,1d' ${testplan_current_config} 
  enable_readwrite_mode_for_config_file
  echo " -- trimfirstline"
}

system_infomation

STAGE=$1
RESET_CODE=$3
echo "STAGE=${STAGE}, RESET_CODE=${RESET_CODE}"

sed -i '/^[ \t]*$/d' ${testplan_current_config}

# Stage START
if [ "${STAGE}" == "START" ]; then
  loadfirstconfigline_to_testplan_current_testconfig
  echo "last_status=${last_status}"

  if [ ${last_status} -eq "0" ]; then
    load_testplan_current_testconfig
    if [ "${APPLICATION_KILL_SIGNAL}" == "RE_USE" ]; then
        echo "!!! APPLICATION_KILL_SIGNAL=${APPLICATION_KILL_SIGNAL}, the previous application deployment are kept for this test, new deployment are skipped!!!"
    else
      STARTUP_SCRIPT=`echo ${CONTROLLER_PARAMS} | awk '{ print $1}'`;
      echo "CONTROLLER_PARAMS=${CONTROLLER_PARAMS}"
      bash ./${STARTUP_SCRIPT}
    fi
    echo ${SUCCESS_STATE}>${stageresultfile};
  else
    echo ${FAILURE_STATE}>${stageresultfile};
  fi
fi

if [ "${STAGE}" == "SECURITY_TEST" ]; then
  loadfirstconfigline_to_testplan_current_testconfig
  if [ ${last_status} -eq "0" ]; then
    load_testplan_current_testconfig
    TEST_DURATION=${SELENIUM_TEST_DURATION:-"${TEST_DURATION}"}
    export DATASET_ROW_ID
    if [[ ! "x${SELENIUM_TEST_SCRIPT}" == "x" && ! -z ${SELENIUM_TEST_SCRIPT} ]]; then
      # do test for all script folders or specified script folders
      if [ ${TEST_FOLDER_NAME} == "ALL_SCRIPT" ]; then
	./timeout.sh $(( TEST_DURATION /60 )):`readlink -f ${SELENIUM_TEST_SCRIPT}`
      else
	./timeout.sh $(( TEST_DURATION /60 )):`readlink -f ${SELENIUM_TEST_SCRIPT}` ${TEST_FOLDER_NAME}
      fi

      report_path=`readlink -f ./${TESTSCRIPT}_latestresult`
      report_fail_line=`grep -o -E "class=\"status_failed\".*Failed:.*>[0-9]+\(XSS=[0-9]+\)<" ./${TESTSCRIPT}_latestresult/TEST_RESULT_REPORT*.html | grep -o -E ">[0-9]+\(XSS=[0-9]+\)<"`
      
      report_total_count=`grep -o -E "Total:.*>[0-9]+<" ./${TESTSCRIPT}_latestresult/TEST_RESULT_REPORT*.html | grep -o -E "[0-9]+"`
      report_not_run_count=`grep -o -E "Not run yet:.*>[0-9]+<" ./${TESTSCRIPT}_latestresult/TEST_RESULT_REPORT*.html | grep -o -E "[0-9]+"`
      report_fail_total=`echo ${report_fail_line} | grep -o -E ">[0-9]+" | grep -o -E "[0-9]+" `
      report_fail_xss=`echo ${report_fail_line} | grep -o -E "XSS=[0-9]+\)"| grep -o -E "[0-9]+" `
      report_result_status=""
      report_result_status="${report_result_status}__${report_total_count}_TOTAL"
      if [ ${report_fail_total} -gt 0 ]; then
	report_result_status="__${report_result_status}__${report_fail_total}_FAILED"
	if [ ${report_fail_xss} -gt 0 ]; then
	  report_result_status="${report_result_status}__${report_fail_xss}_XSS"
	fi
      else
	report_result_status="${report_result_status}__PASSED"
      fi
      if [ ${report_not_run_count} -gt 0 ]; then
	report_result_status="${report_result_status}__${report_not_run_count}_UNDONE"
      fi
      
      echo "`date`,INFO::report_path=${report_path}"
      ln -s ${report_path} ${report_path}_${TEST_FOLDER_NAME}${report_result_status}
      report_path_basename="`basename ${report_path}_${TEST_FOLDER_NAME}${report_result_status}`"
      echo "${BUILD_ID}!${report_path}_${TEST_FOLDER_NAME}${report_result_status}!SECURITY_AUTOMATION_REPORT/${TEST_GROUP_ID}/${report_path_basename}">>${testplan_upload_queue}

      #mkdir ${report_path}/logs
      cp ${APPLICATION_PATH}/logs/catalina.out* ${report_path}/
      cp ${APPLICATION_PATH}/logs/local*access* ${report_path}/
      grep -n -A 5 -B 5 "MSG_CODE=" ${report_path}/local*access*
      gzip ${report_path}/local*access*
      gzip ${report_path}/catalina*
      pushd ${report_path}
      mkdir details
      mv * details
      mv details/TEST_RESULT_REPORT*.html .
      sed -i '0,/detailframe.src=src/s/detailframe.src=src/detailframe.src=".\/details\/"+src/g' TEST_RESULT_REPORT*.html
      find ./details -type f -name "RESULT_SUITE_*.html" | xargs -n 1 sed -i -r 's#<a href="[^>]+">([^<]+)</a></td></tr>#<a onclick="function showimage(){document.location.href=document.location.href.toString().replace('\''jmeter/results/'\'','\''jmeter/results/listdir.php?path=../results/'\'')+'\''_log'\'';}; showimage();" href="\#">\1</a></td></tr>#g'
      popd
      echo ${SUCCESS_STATE}>${stageresultfile};
      echo "Local report storage: ${report_path}"
      echo "The test report should be uploaded to: https://qaf-reports.exoplatform.org/archives/jmeter/results/listdir.php?path=../results/SECURITY_AUTOMATION_REPORT/${TEST_GROUP_ID}/${report_path_basename}"
    fi
  else
    echo ${FAILURE_STATE}>${stageresultfile};
  fi
fi

if [ "${STAGE}" == "STOP_APPLICATION" ]; then
    load_testplan_current_testconfig
    if [ "${APPLICATION_KILL_SIGNAL}" == "RE_USE" ]; then
	echo "!!! APPLICATION_KILL_SIGNAL=${APPLICATION_KILL_SIGNAL}, the previous application deployment will be kept for this test!!!"
    else
    	LONES="catalina.base=/java/exo-working Dexo.conf.dir.name jmxtrans program.name=run.sh /usr/lib/libreoffice/program/soffice.bin /opt/openoffice.org3/program/soffice.bin";
    	stop_application_deployment
    fi
    echo ${SUCCESS_STATE}>${stageresultfile};
fi

if [ "${STAGE}" == "STOP_TEST" ]; then
    load_testplan_current_testconfig
    stop_jmeter_running_process
    echo ${SUCCESS_STATE}>${stageresultfile};
fi

if [ "${STAGE}" == "COUNT_DOWN_TEST" ]; then
  loadfirstconfigline_to_testplan_current_testconfig
  if [ ${last_status} -eq "0" ]; then
    load_testplan_current_testconfig
    trimfirstline
    echo ${SUCCESS_STATE}>${stageresultfile};
  else
    echo ${FAILURE_STATE}>${stageresultfile};
  fi
fi


if [ "${STAGE}" == "UPLOAD_REPORT" ]; then

  upload_config=`egrep ^.*$ ${testplan_current_upload_queue} -m 1 -o`;
  REPORT_BUILD_ID=`echo ${upload_config} | awk -F ! '{ print $1 }' `
  export output_string=""
  if [ ! -z ${REPORT_BUILD_ID} ]; then
    echo "one upload with information [${upload_config}] existing, upload cancelled"
    last_status="1"
    exit_upload
  else
    sed -i '/^[ \t]*$/d' ${testplan_upload_queue}
    upload_config=`egrep ^.*$ ${testplan_upload_queue} -m 1 -o`;
    echo "${upload_config}">${testplan_current_upload_queue}
    REPORT_BUILD_ID=`echo ${upload_config} | awk -F ! '{ print $1 }' `
    REPORT_PATH=`echo ${upload_config} | awk -F ! '{ print $2 }' `
    FINAL_REPORT_PATH=`echo ${upload_config} | awk -F ! '{ print $3 }' `

    if [ -z ${REPORT_BUILD_ID} ]; then
      echo "no upload information found in the first line [${upload_config}]"
      last_status="1"
      exit_upload
    fi
    output_to_report "## ------------------ ------------------ ------------------ ------------------ "
    output_to_report "## uploading with information: [${upload_config}]"
    output_to_report "## ------------------ ------------------ ------------------ ------------------ "
    

    ssh qafreports@qaf02.exoplatform.org ! mkdir -p /srv/qafreports/var/www/archives/jmeter/results/${FINAL_REPORT_PATH}>/dev/null
    rsync -L --rsh='ssh' -az --exclude="logs/" --progress --partial ${REPORT_PATH}/*  qafreports@qaf02.exoplatform.org:/srv/qafreports/var/www/archives/jmeter/results/${FINAL_REPORT_PATH}
    ssh qafreports@qaf02.exoplatform.org ! " unzip /srv/qafreports/var/www/archives/jmeter/results/${FINAL_REPORT_PATH}/graphite-opennms-data.zip -d /srv/qafreports/var/www/archives/jmeter/results/${FINAL_REPORT_PATH}/graphite-opennms-data>/dev/null ; rm -f /srv/qafreports/var/www/archives/jmeter/results/${FINAL_REPORT_PATH}/graphite-opennms-data.zip>/dev/null"
    report_file_dir_files_count=`ls ${REPORT_PATH} | wc -l `
    report_file_dir_dirs_count=`find ${REPORT_PATH}/* -maxdepth 1 -type d | wc -l `
    report_file_dir_files_count=$(( report_file_dir_files_count - report_file_dir_dirs_count )) # exclude
    final_report_file_dir_file_count=`ssh qafreports@qaf02.exoplatform.org ! /bin/ls /srv/qafreports/var/www/archives/jmeter/results/${FINAL_REPORT_PATH} | wc -l  `;
    #ssh qafreports@qaf02.exoplatform.org ! rm -f /srv/qafreports/var/www/archives/jmeter/results/${FINAL_REPORT_PATH}/graphite-opennms-data.zip>/dev/null
    if [ $report_file_dir_files_count -gt $final_report_file_dir_file_count ]; then
      echo "${REPORT_BUILD_ID}_REDO!${REPORT_PATH}!${FINAL_REPORT_PATH}!local=${report_file_dir_files_count} not equal to remote${final_report_file_dir_file_count}) ">>${testplan_upload_queue}
      echo " ## the report has not been published successfully as the files count does not match (local=${report_file_dir_files_count} not equal to remote${final_report_file_dir_file_count}) "
      last_status="1"
    fi
    output_to_report "## The report of BUILD: ${REPORT_BUILD_ID} has been published to QAF: https://qaf-reports.exoplatform.org/archives/jmeter/results/listdir.php?path=../results/${FINAL_REPORT_PATH}"
    output_to_report "## Local report : ${FINAL_OUTPUT_DIR} and http://builder.testlab2.exoplatform.vn/job/ViewPerformanceTestResults/ws/performancetest-results/results/${FINAL_REPORT_PATH}"
    output_to_report "## ------------------ ------------------ ------------------ ------------------ "

    echo "								"
    echo "								"
    echo "######  ######  ####### #     # ### ####### #     #  #####     #     # ######  #       #######    #    ######   #####  "
    echo "#     # #     # #       #     #  #  #     # #     # #     #    #     # #     # #       #     #   # #   #     # #     # "
    echo "#     # #     # #       #     #  #  #     # #     # #          #     # #     # #       #     #  #   #  #     # #       "
    echo "######  ######  #####   #     #  #  #     # #     #  #####     #     # ######  #       #     # #     # #     #  #####  "
    echo "#       #   #   #        #   #   #  #     # #     #       #    #     # #       #       #     # ####### #     #       # "
    echo "#       #    #  #         # #    #  #     # #     # #     #    #     # #       #       #     # #     # #     # #     # "
    echo "#       #     # #######    #    ### #######  #####   #####      #####  #       ####### ####### #     # ######   #####  "
    echo "								"
    echo "								"


    tail -50 ${testplan_upload_info}

    # cut the first line anyway
    sed -i  -e '1,1d' ${testplan_upload_queue}
    # remove uploading flag
    echo "">${testplan_current_upload_queue}
  fi
  exit_upload
fi

