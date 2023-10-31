#!/bin/bash
# Author : @razguru
# Version : 1.0
# Desc : Track modification status of volumes ..
#
vol_id_list="$1"
region="$2"
dt=`date +%F-%T`
log="$region-$dt-vol-modification-progress.log"

#Ensure vol_id_list is provided
if [ -z $vol_id_list ] || [ ! -s $vol_id_list ] ; then
        echo "Please provide a file name listing target volume_ids .. example - $0 vol_id_list us-east-1"
exit 1
fi

#Ensure region is provided
if [ -z $region ]; then
	echo "Please provide a region .. example - $0 vol_id_list us-east-1"
exit 1
fi


for vol_id in `cat "$vol_id_list"`;do
	echo `date +%F-%T` >> $log && /usr/bin/aws ec2 describe-volumes-modifications --region "${region}" --volume-ids "${vol_id}" --query "VolumesModifications[*].{ID:VolumeId,STATE:ModificationState,Progress:Progress}"; done| tee -a $log
if [ $? -eq 0 ]; then
	echo " Logged the output to $log"
else
	echo "Failed to run ec2 describe-volumes-modifications, pls investigate"
fi
