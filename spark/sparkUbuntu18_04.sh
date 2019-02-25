#!/bin/bash
#******************************************************************************
#    PySpark and Jupyter Installation Script for Ubuntu 18.04
#******************************************************************************
#
# SYNOPSIS
#    Automates the installation of PySpark and Jypyter Notebook.
#
# DESCRIPTION
#    This script installs Jupyter, Spark and all dependencies on AWS ubuntu 18_04.
#    SCP/SFTP this script to EC2 instance and change mod to 744 to execute.
#    The instance must have a security group allowing inbound on port 22 and 8888.
#    It uses find spark hence the first 3 lines in any notebook should be 
# 	import findspark
#       findspark.init('/home/ubuntu/spark-2.4.0-bin-hadoop2.7')
#       import pyspark
#    Test everything is working by 
#	dir(pyspark)
#
#==============================================================================
#
# NOTES
#   VERSION:   0.1.0
#   LASTEDIT:  02/26/2019
#   AUTHOR:    Swagata De Khan
#   EMAIL:     swagata.dekhan@yahoo.com
#   REVISIONS:
#       0.1.0  02/26/2019 - first release
#
#==============================================================================
#   MODIFY THE SETTINGS BELOW
#==============================================================================
#
CERT=certs
CERT_NAME=mycert.pem
PROJ=projects
SUBJ='/C=IN/ST=Karnataka/L=Bangalore/O=dekhan/OU=swagata/CN=swagatadekhan.com'
#
#==============================================================================
#   DO NOT MODIFY THE SETTINGS BELOW
#==============================================================================
#
J_CFG=jupyter_notebook_config.py
APACHE_DIST=http://archive.apache.org/dist
SPARK_DIST=spark/spark-2.4.0
SPARK_HADOOP=spark-2.4.0-bin-hadoop2.7
#
#==============================================================================
#   DO NOT MODIFY CODE BELOW
#==============================================================================
#
#
cd $HOME
echo "Current location: `pwd`"
#
echo "Updating existing libraries..."
sudo apt update
#
echo "Updating pip..."
sudo apt install python3-pip python3-dev -y
python3 -version
#
echo "creating certificates..."
cd $HOME
mkdir $CERT
cd $CERT
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout $CERT_NAME -out $CERT_NAME \
-subj $SUBJ
cd $HOME
#
echo "Installing jupyter..."
mkdir $PROJ
sudo apt install jupyter -y
#
echo "Creating Jupyter config file"
jupyter notebook --generate-config
cd ~/.jupyter/
echo "c = get_config()" >> $J_CFG
echo "c.NotebookApp.certfile = u'$HOME/$CERT/mycert.pem'" >> $J_CFG
echo "c.NotebookApp.allow_origin = '*'" >> $J_CFG
echo "c.NotebookApp.ip = '0.0.0.0'" >> $J_CFG
echo "c.NotebookApp.open_browser = False" >> $J_CFG
echo "c.NotebookApp.port = 8888" >> $J_CFG
cd $HOME
#
echo "Installing jre..."
sudo apt-get install default-jre -y
java -version
#
echo "Installing scala..."
sudo apt-get install scala -y
scala -version
#
echo "Installing py4j..."
pip3 install py4j
#
echo "Getting Spark..."
wget $APACHE_DIST/$SPARK_DIST/$SPARK_HADOOP.tgz
tar -zxvf $SPARK_HADOOP.tgz
#
echo "Installing FindSpark..."
cd $SPARK_HADOOP
pip3 install findspark
cd $HOME