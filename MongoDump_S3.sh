#!/bin/bash

# Set up necessary variables
S3DIR="$1"
ENV="$2"
MONGODUMP_PATH="/usr/bin/mongodump"
BUCKET_NAME="ENETR-BUCKET-NAME"
TIMESTAMP=`date +%Y-%m-%d `
SENDER='EMAIL-ID'
RECIPIENTS='EMAIL-ID'
SUBJECT="[$ENV][Alert][Info][Server]: MongoDB Dump Information"

#Instance Metadata
HOST=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
PublicIpAddress=$(curl http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
InstanceId=$(curl  http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)

MESSAGE=$(echo -e "
<p> MongoDB Dump Stated at `date +%Y-%m-%d:%H:%M:%S`     </p>
Host : $S3DIR Server       	    <br/>
Public IP Address : $PublicIpAddress 	    <br/>
Local Ip Address : $HOST	<br/>
Instance ID : $InstanceId           <br/>
Description : MongoDB Backup Status: Dumped Collections")

#Function To Send Email Notification
send_email() {
	/usr/bin/aws ses send-email --from "${SENDER}" --destination "ToAddresses=${RECIPIENTS}" --message "Subject={Data=\"$SUBJECT $PARTITION\", Charset=utf8},Body={Html={Data=`echo -e $MESSAGE`, Charset=utf8}}" --region="us-east-1"
}

# Check Arg passed or not
if [ -z "$1" ];
then
	echo "No arguments supplied. Please pass bucket folder name as argument."
	exit 
fi

# Create Mongo Backup Directory
BackupDIR=MongoDump-`date +%H-%M-%S`
mkdir  $BackupDIR

#Force file syncronization and lock writes
mongo --quiet admin --eval "printjson(db.fsyncLock())" > /dev/null 

# Dump databases
$MONGODUMP_PATH --out  $BackupDIR --quiet

if [ $? -eq 1 ];
then
	echo "Error when taking the mongodump"
fi

#Unlock database writes
mongo --quiet admin --eval "printjson(db.fsyncUnlock())"  > /dev/null

# Creating Archive	
tar czf $BackupDIR.tar.gz $BackupDIR

#Copy Dump To S3
aws s3 cp $BackupDIR.tar.gz s3://$BUCKET_NAME/$S3DIR/$TIMESTAMP/

if [ $? -eq 0 ]; then
send_email;
fi

# Remove Archive DIR
rm -rf $BackupDIR
rm $BackupDIR.tar.gz

