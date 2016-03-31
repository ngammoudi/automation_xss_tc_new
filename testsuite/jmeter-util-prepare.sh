#!/bin/bash

EXO_WORKING_DIR=/java/exo-working

if [ -d $EXO_WORKING_DIR ]; then
  pushd $EXO_WORKING_DIR
  
  if [ ! -d automation_xss_tc_new ]; then
    echo "INFO: downloading automation_xss_tc_new"
    git clone https://github.com/nghinv/automation_xss_tc_new.git 
    ln -s automation_xss_tc_new automation_xss_tc
  fi

  if [ ! -d w3af_auto ]; then
    echo "INFO: w3af_auto"
    git clone https://github.com/nghinv/w3af_auto.git
    pushd w3af_auto

    mkdir tools
    git clone https://github.com/nghinv/w3af.git
    mkdir tools/dependencies
    cd tools/dependencies
    echo "... install w3af dependencies: "
    apt-get update
    echo "... install w3af dependencies: python-soappy python-lxml python-svn python-scapy"
    apt-get install python-soappy python-lxml python-svn python-scapy
    apt-get install python-openssl

    echo "... install w3af dependencies: nltk-2.0b9.tar.gz, pybloomfiltermmap-0.2.0.tar.gz, PyYAML-3.09.tar.gz"
    wget https://pypi.python.org/packages/source/n/nltk/nltk-2.0b9.tar.gz && tar xf nltk-2.0b9.tar.gz && cd nltk-2.0b9 && python setup.py install
    wget https://pypi.python.org/packages/source/p/pybloomfiltermmap/pybloomfiltermmap-0.2.0.tar.gz && tar xf pybloomfiltermmap-0.2.0.tar.gz && cd pybloomfiltermmap-0.2.0 && python setup.py install
    wget http://pyyaml.org/download/pyyaml/PyYAML-3.09.tar.gz && tar xf PyYAML-3.09.tar.gz && cd PyYAML-3.09 && python setup.py install

    popd
  fi

  #download firefox
  if [ ! -f firefox-21.0b7.tar.bz2 ]; then
    if [ ! -d firefox21 ]; then
      # remove firefox folder
      rm -frv current_firefox || true
      
      # download firefox21
      curl -fL https://download-installer.cdn.mozilla.net/pub/firefox/releases/21.0b7/linux-x86_64/en-US/firefox-21.0b7.tar.bz2  -o ${EXO_WORKING_DIR}/firefox-21.0b7.tar.bz2 
      tar xf ${EXO_WORKING_DIR}/firefox-21.0b7.tar.bz2
      
      # choose ff21
      mv firefox firefox21
      ln -s firefox21 current_firefox
    else
      echo "INFO: the folder firefox21 existing, abort the download process"
    fi
  fi
  
  if [ ! -f selenium-server-standalone-2.52.0.jar ]; then
    echo "INFO: downloading selenium-server-standalone-2.52.0.jar"
    curl -fL http://selenium-release.storage.googleapis.com/2.52/selenium-server-standalone-2.52.0.jar -o ${EXO_WORKING_DIR}/selenium-server-standalone-2.52.0.jar
  fi
  
  set -e
  if [ ! -f plf-community-tomcat-standalone-4.3.0.zip ]; then
    echo "INFO: downloading plf-community-tomcat-standalone-4.3.0.zip"
    curl -fL https://repository.exoplatform.org/service/local/repositories/exo-releases/content/org/exoplatform/platform/distributions/plf-community-tomcat-standalone/4.3.0/plf-community-tomcat-standalone-4.3.0.zip -o ${EXO_WORKING_DIR}/plf-community-tomcat-standalone-4.3.0.zip
  fi
  
  mkdir ${EXO_WORKING_DIR}/TC || true
  if [ -d ${EXO_WORKING_DIR}/TC/current ]; then
    echo "INFO: removing ${EXO_WORKING_DIR}/TC/current"
    rm -rf ${EXO_WORKING_DIR}/TC/current/*
  else
    mkdir ${EXO_WORKING_DIR}/TC/current
  fi
  rm -rf /tmp/PLF || true
  unzip -q ${EXO_WORKING_DIR}/plf-community-tomcat-standalone-4.3.0.zip -d /tmp/PLF
  TMP_PLF_DIR=`find /tmp/PLF -maxdepth 1 -mindepth 1`
  if [ $? -eq 0 ]; then
    mv $TMP_PLF_DIR/* ${EXO_WORKING_DIR}/TC/current/
    # extract dataset
    echo "INFO: Extracting dataset" # extract dataset
    
    pushd ${EXO_WORKING_DIR}/TC/current/
    mkdir DATASET
    pushd DATASET
    # this dataset contain conf/server.xml and webapps/eXoResources.war together with gatein/data
    tar xf ${EXO_WORKING_DIR}/automation_xss_tc/testsuite/plf_templates/datasets/plf43comm/PLF43_DATASET_HSQL.tar.bz2
    popd
    cp DATASET/* . -R
    rm -rf DATASET
    echo "INFO: ${EXO_WORKING_DIR}/TC/current/ is now ready to run"
    popd #to EXO_WORKING_DIR
    
    mkdir $HOME/.eXo/Platform/ || true
    cp ${EXO_WORKING_DIR}/automation_xss_tc/testsuite/plf_templates/datasets/plf43comm/license.xml $HOME/.eXo/Platform/
    echo "${EXO_WORKING_DIR}/TC/current/ RE_USE!SAMPLES 3600 SAMPLE_TEST_WITH_PLF43 SHOULD_WORK!eXoPLF.install.sh" > ${EXO_WORKING_DIR}/automation_xss_tc/testsuite/TEST_VIRGO_CURRENT_CONFIG
  fi
else
  echo "ERROR: Expect to have the folder $EXO_WORKING_DIR to exist"
  a=$((1/0))
fi