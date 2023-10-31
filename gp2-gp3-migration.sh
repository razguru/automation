#! /bin/bash
# Author : @razguru
# Version : 1.0
# Desc : Discover or/and modify GP2 volumes with/without snapshot

reg="$1"
region="$2"
file_name="$3"
snap="$4"
dt=`date +%F-%T`

# Ensure region is provided
if [ -z $region ] || [[ $reg != --region ]] || [ -z $file_name ]; then
	echo "Please provide region/all, target volume-list/all and optional snapshot option .."
	echo ""
	echo "To create list of all GP2 volumes in a region or all regions ::  $0 --region <region_name>/all discover"
	echo "To migrate listed GP2 volumes from a file w/o snapshot ::  $0 --region <region_name> <volume_list_file.txt>"
        echo "To migrate all GP2 volumes in a region w/o snapshot ::  $0 --region <region_name> migrate"
	echo "To migrate all GP2 volumes across all regions w/o snapshot ::  $0 --region all migrate"
	echo "Optional : To include snapshot creation before migration call --snapshot as last option ::  $0 --region <region_name>/all volume_list/migrate --snapshot"
	echo ""
exit 1
fi

if [[ $region != all ]]; then gp2_vol_id="$region"-"$dt"-gp2-vol-id.txt
fi

if [[ $region != all ]] && [[ $file_name == discover ]]; then  disc="discover"
fi

if [[ $file_name != migrate ]] && [[ $file_name != discover ]] && [ $region == all ]; then
        echo "To target listed GP2 volumes from $file_name pls use - $0 region <region_name> <volume_list_file.txt>"
exit 1
fi

if [[ $file_name != migrate ]] && [[ $file_name != discover ]] && [ ! -s "$file_name" ] ; then
         echo "Provided file "$file_name" is either empty or does not exist !"
         exit 1
fi

if [ ! -z "$file_name" ] && [[ $file_name != migrate ]] && [[ $file_name != discover ]] && [ -s "$file_name" ] ; then
        manual="conversion"
fi
if [ ! -z "$file_name" ] && [[ $file_name != migrate ]] && [[ $file_name != discover ]] && [ -s "$file_name" ] && [[ $snap = --snapshot ]]; then
        manual="snap_conversion"
fi

if [[ $region != all ]] && [[ $file_name = migrate ]] && [[ $file_name != discover ]] && [[ $snap != --snapshot ]]; then
	action="auto_conversion"
fi

# Find all GP2 volumes within the given list
manual-disc()
{
      if [ ! -z "$file_name" ] && [ -s "$file_name" ] ; then 
	 /bin/cp "$file_name" "$gp2_vol_id" &> /dev/null
	 echo "Discovered ....( `egrep vol "$gp2_vol_id"|wc -l` ).... GP2 volumes from "$file_name""
 else
	 echo "Provided file "$file_name" is either empty or does not exist !"
	 exit 1
      fi
}

# Find all GP2 volumes within the given region
auto-disc()
{
gp2_vol_id="$region"-"$dt"-gp2-vol-id.txt
gp2_vol_error="$region"-"$dt"-gp2-vol-error.txt
/usr/bin/aws ec2 describe-volumes --region "${region}" --filters Name=volume-type,Values=gp2 > /dev/null  2> "$gp2_vol_error"
if [ -s "$gp2_vol_error" ]; then
        echo -n "$region -- error -- " && echo `cat $gp2_vol_error`
	echo ""
else
	rm -f $gp2_vol_error &> /dev/null
	/usr/bin/aws ec2 describe-volumes --region "${region}" --filters Name=volume-type,Values=gp2 | jq -r '.Volumes[].VolumeId' > "$gp2_vol_id"
if [ -s "$gp2_vol_id" ]; then
       	echo -n "$region -- Discovered ....( `egrep vol "$gp2_vol_id"|wc -l` ).... GP2 volumes in $region" && echo " || GP2 volume-ids list : $gp2_vol_id"
	echo ""	
else
       echo "$region -- No GP2 volume found in $region" && rm -f $gp2_vol_id &> /dev/null
       echo ""
fi
fi
}

# Converting discovered GP2 volumes to GP3
convert()
{
if [ -s "$gp2_vol_id" ]; then 
	for vol_id in `cat "$gp2_vol_id"`;do echo "Modifying volume ${vol_id} to GP3"
	result=$(/usr/bin/aws ec2 modify-volume --region "${region}" --volume-type=gp3 --volume-id "${vol_id}" | jq '.VolumeModification.ModificationState' | sed 's/"//g')
    if [ $? -eq 0 ] && [ "${result}" == "modifying" ];then
        echo "`date +%F-%T` SUCCESS: volume ${vol_id} changed to GP3 .. state 'modifying'" |tee -a "$region"-"$dt"-modify-vol.log
	echo ""
    else
        echo -n "`date +%F-%T` ERROR: couldn't change volume ${vol_id} type to GP3!" |tee -a "$region"-"$dt"-modify-vol.log
        echo ""
	exit 1
    fi
done

echo ""
echo "To track the progress of migration, please run -    bash gp2-gp3-migration-progress.sh $gp2_vol_id $region" 
echo ""
echo "GP2 volume-ids list : $gp2_vol_id"
echo ""
echo "GP2-GP3 volume modification logs : $region-$dt-modify-vol.log"
echo "~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~"
echo ""
fi
}

snap-convert()
{
if [ -s "$gp2_vol_id" ]; then
	for vol_id in `cat "$gp2_vol_id"`;do
	/usr/bin/aws ec2 create-snapshot --region "${region}" --volume-id "${vol_id}" --description 'Pre GP3 migration' --tag-specifications 'ResourceType=snapshot,Tags=[{Key=state,Value=pre-gp3}]' &>> "$region-$dt-snapshot-vol.log"
	if [ $? -ne 0 ]; then
	       echo ERROR: "snapshot creation failed for volume_id $vol_id, skipping this volume ! check "$region"-"$dt"-snapshot-vol.log"
       else
               echo "Creating snapshot for "${vol_id}""

        sleep 10 ; snap_state=$(/usr/bin/aws ec2 describe-snapshots --region "${region}" --filters Name=volume-id,Values="${vol_id}" Name=tag:state,Values=pre-gp3| jq -r '.Snapshots[].State')

	while [ "${snap_state}" != "completed" ];do
        echo "`date +%F-%T` : waiting for snapshot completion .. .. "
	sleep 10
	snap_state=$(/usr/bin/aws ec2 describe-snapshots --region "${region}" --filters Name=volume-id,Values="${vol_id}" Name=tag:state,Values=pre-gp3| jq -r '.Snapshots[].State')
        done
	snapshot_id=$(/usr/bin/aws ec2 describe-snapshots --region "${region}" --filters Name=volume-id,Values="${vol_id}" Name=tag:state,Values=pre-gp3 --query "reverse(sort_by(Snapshots, &StartTime))[0].SnapshotId")
        echo "`date +%F-%T` SUCCESS: snapshot $snapshot_id completed for  "${vol_id}"" |tee -a "$region"-"$dt"-snapshot-vol.log
	
	echo "Modifying volume ${vol_id} to GP3"
	result=$(/usr/bin/aws ec2 modify-volume --region "${region}" --volume-type=gp3 --volume-id "${vol_id}" | jq '.VolumeModification.ModificationState' | sed 's/"//g')
    if [ $? -eq 0 ] && [ "${result}" == "modifying" ];then
        echo "`date +%F-%T` SUCCESS: volume ${vol_id} changed to GP3 .. state 'modifying'" |tee -a "$region"-"$dt"-modify-vol.log
	echo ""
	echo "~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~"
    else
        echo "`date +%F-%T` ERROR: couldn't change volume ${vol_id} type to GP3!" |tee -a "$region"-"$dt"-modify-vol.log
        echo ""
    fi
	fi
done
echo "To track the progress of migration, please run -    bash gp2-gp3-migration-progress.sh $gp2_vol_id $region"
echo ""
echo "GP2 volume-ids list : $gp2_vol_id"
echo ""
echo "Snapshot logs before GP3 migration : "$region-$dt"-snapshot-vol.log"
echo ""
echo "GP2-GP3 volume modification logs : $region-$dt-modify-vol.log"
echo "~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~*~~~~~~"
echo ""
fi
}

# Calling functions based on conditions ..
if [ $region = all ] && [[ $file_name == discover ]]; then
        /usr/bin/aws ec2 describe-regions --all-regions --filters Name=opt-in-status,Values=opt-in-not-required,opted-in --query "Regions[].{Name:RegionName}" --output text > region_list.txt
        for region in `cat region_list.txt`; do auto-disc ; done
	exit
fi

if [ $region = all ] && [[ $file_name == migrate ]] && [[ $snap != --snapshot ]]; then
        /usr/bin/aws ec2 describe-regions --all-regions --filters Name=opt-in-status,Values=opt-in-not-required,opted-in --query "Regions[].{Name:RegionName}" --output text > region_list.txt
        for region in `cat region_list.txt`; do auto-disc ; convert ; done
exit
fi

if [ $region = all ] && [[ $file_name == migrate ]] && [[ $snap == --snapshot ]]; then
        /usr/bin/aws ec2 describe-regions --all-regions --filters Name=opt-in-status,Values=opt-in-not-required,opted-in --query "Regions[].{Name:RegionName}" --output text > region_list.txt
        for region in `cat region_list.txt`; do auto-disc ; snap-convert ; done
exit
fi

case $disc in
	discover )
		auto-disc
		exit 0
		;;
esac

case $manual in
        conversion )
                manual-disc
                convert
		exit 0
                ;;
esac

case $manual in
        snap_conversion )
                manual-disc
                snap-convert
                exit 0
                ;;
esac

case $snap in
        --snapshot ) echo "Discovering all GP2 volumes in $region ... " && echo "..  ...  ....  .....  ...... " && sleep 1 && echo "..  ...  ....  .....  ......  .......  ........  ........."
                auto-disc
                snap-convert
                exit 0
		;;
esac

case $action in
        auto_conversion ) echo "Discovering all GP2 volumes in $region ... " && echo "..  ...  ....  .....  ...... " && sleep 1 && echo "..  ...  ....  .....  ......  .......  ........  ........."
                auto-disc
                convert
                ;;
        * ) echo "invalid response";
                exit 1;;
esac
# -- END --
