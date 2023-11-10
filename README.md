# Discover EBS volume type GP2 and modify them to type GP3 with/without snapshot

This example demonstrates how to modify EBS volume type GP2 to GP3 across a given region or all regions where customer has workload. It can auto scan all GP2 volumes or read the volume_ids input from any .text file in case modification needed only on user provided volumes.
Elastic volumes supports online modification of EBS volume type GP2 to GP3, it does not bring any outage to instance. 

Files

    gp2_gp3_migration.sh - main script to perform modification
    gp2_gp3_migration_progress.sh - side script to track progress of modification triggered by main script
   

Purpose

The main script file contains the several function that perform the following tasks based on parameters used with the script :

   - Discover and create list of all GP2, GP3, io1, io2 volumes in any single region or all regions.

   - Modify listed GP2 volumes from a file with or without snapshot.

   - Discover all GP2 volumes in a region and modify all of them with or without snapshot.

   - Discover all GP2 volumes in all regions and modify all of them with or without snapshot.

   - Perform any of the above action on cross accounts where AWS configuration profile, IAM role and permissions are already setup.

Prerequisites

    An Amazon Web Services (AWS) account.
    AWS CLI setup - http://docs.aws.amazon.com/cli/latest/userguide/installing.html 
    IAM policy/role that allows to perform volume discovery, modification and snapshot creation - Refer: IAM_permission.txt).
    Configuration profile for cross account access - Refer : AWS_profile.txt


Script execution

- To create list of all GP2, GP3, io1, io2 volumes in any single region or all regions ::  gp2_gp3_migration.sh --region <region_name>/all discover

- To migrate listed GP2 volumes from a file w/o snapshot ::  gp2_gp3_migration.sh --region <region_name> <volume_list_file.txt> no-snapshot

- To migrate listed GP2 volumes from a file with snapshot ::  gp2_gp3_migration.sh --region <region_name> <volume_list_file.txt> snapshot

- To migrate all GP2 volumes in a region w/o snapshot ::  gp2_gp3_migration.sh --region <region_name> migrate no-snapshot

- To migrate all GP2 volumes in a region with snapshot ::  gp2_gp3_migration.sh --region <region_name> migrate snapshot

- To migrate all GP2 volumes across all regions w/o snapshot ::  gp2_gp3_migration.sh --region all migrate no-snapshot

- To migrate all GP2 volumes across all regions with snapshot ::  gp2_gp3_migration.sh --region all migrate snapshot

- To perform any of the above action on cross accounts where IAM role, permission and profile is already setup, add last 2 parameters --profile <profile_name>

- To track the progress of volume modification :: gp2_gp3_migration_progress.sh <gp2_vol_id.txt> <region_name>

Note - snapshot created by this script will have description: "Pre GP3 migration" and tag: key=state, value=pre-gp3


Additional Information

    As an AWS best practice, grant this code least privilege, or only the permissions required to perform a task. For more information, see Grant Least Privilege in the AWS Identity and Access Management (IAM) User Guide.
    This code has not been tested in all AWS Regions. Some AWS services are available only in specific Regions. For more information, see Service Endpoints and Quotas in the AWS General Reference Guide.
    Running this code can result in charges to your AWS account. It's your responsibility to ensure that any resources created by this script are removed when you are done with them.
