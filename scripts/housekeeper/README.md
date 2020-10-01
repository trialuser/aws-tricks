# The scripts for monitoring and clearing unused or suspected resources

The scripts here provided are used to detect and delete unused resources.
*aws_housekeeper.sh* is a script to detect unused resources and it also calculates the respective monthly price.
The remaining scripts are used to delete the unused resources. 

<hr/>

## aws_housekeeper.sh

### Description

This script collects the information for AWS environment, such as: 
  * Orphaned Elastic IPs
  * Orphaned EBS Volumes
  * Aged EBS Snapshots
  * Orphaned EBS Snapshots
  * Aged RDS DB Snapshots
  * Orphaned Load Balancers
  * Expired certificates
The script also calculates approximate cost/benefit of removing these resources.

### Requirements

  * aws-cli - https://aws.amazon.com/cli/
  * jq - https://stedolan.github.io/jq/

### Usage

```
bash ./aws_housekeeper.sh
```
or
```
AWS_REGION=us-east-1 bash ./aws_housekeeper.sh
```
or 
```
AWS_CLI_PROFILE=project-dev AWS_REGION=us-east-1 bash ./aws_housekeeper.sh
```


### Configuration

By default the script uses the price for the region 'us-east-1' and default AWS profile. 
The parameters can be customized in external file `settings.conf` placed in the same directory
with the script. 

Please, make sure you set the next parameters properly:

  * AWS_CLI_PROFILE - the profile to use
  * AWS_REGION - the region to check
  * AWS_EBS_SNAP_DAYS - number of days to count aged EBS snapshots 
  * AWS_DB_SNAP_DAYS - number of days to count aged RDS snapshots
Other variables are set as the constant vairables and define the price for different regions/zones.


<hr/>

# Deletion scripts  


## delete-ebs-volumes.sh

* This script is used to delete  Elastic Block Volumes (EBS) volumes.

  * **Use on unattached EBS volumes only.**

* Usage:

   * Edit `./ebs-volumes/ebs-unattached.txt` so that each line has a the ID of the volume to be deleted.
   * Run `REGION=eu-west-1 PROFILE=project-staging ./delete-ebs-volumes.sh`

<hr/>



## delete-ebs-snaps.sh

* This script is used to delete Elastic Block Volumes (EBS) snapshots.

  * All orphaned snaps are deleted.

  * All **aged snaps are deleted, unless they are the most recent** snap available.

* Usage:

  * Edit `./ebs-snaps/ebs-aged.txt` and  `./ebs-snaps/ebs-orphaned.txt` so that each line has an EBS ID that is to be deleted.
  * Run `REGION=eu-west-1 PROFILE=project-staging ./delete-ebs-snaps.sh`

<hr/>



## delete-rbs-snaps.sh

* This script is used to delete Relational Database Systems (RDS) snapshots.

  * All **aged snaps are deleted, unless they are the most recent** snap available.

* Usage:

  * Edit `./rds-snaps/rds-aged.txt` so that each line has an EBS ID that is to be deleted.
  * Run `REGION=eu-west-1 PROFILE=project-staging ./delete-rds-snaps.sh`

<hr/>



## ToDo's

* Edit housekeeper script so that all regions are runned at once.
* Consider a complete automation (housekeeper to detect problems, followed by deleters to clean them). Is it possible? How difficult is it?

* The cleanup must be handled by region, which is extremely inefficient.
  * We will try to add the resources from all region, and just let the deletion fail on those resources that do not belong there.

<hr />

# Monitoring Scripts

## check_certificates.sh

This script is used to check and monitor the expiration date for domains listed in data-to-check/$PROFILE_domains.txt.

### Usage

Update PROFILE in `./check_certificates.sh`, then edit the list in `data-to-check/$PROFILE_domains.txt`, 
e.g. in `data-to-check/microsites_domains.txt`. The script can be setup in cron and will send 
the notifications via email automatically.

Make sure you also set correctly some other parameters in this script: `SENDMAIL_BIN` - full path to sendmail 
(if this is installed), `OPENSSL_BIN` - full path to openssl binary, `TIMEOUT_BIN` - full path to timeout 
utility (coreutils). Next parameters: `ALERT` - the number of days when the SSL is marked as expired for 
alerting, `SHOW_HTTP_WARNS` - set to 1 when you need to see the notifications about domains from teh list 
that don't have HTTPS configured, `EMAIL_TO` - list of emails (comma separated) for sending notifications 
via email. Both `EMAIL_TO` and `SENDMAIL_BIN` should be set to send the notifications.
