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

## ToDo's

* Edit housekeeper script so that all regions are runned at once.
* Consider a complete automation (housekeeper to detect problems, followed by deleters to clean them). Is it possible? How difficult is it?
* Total cost
* Check for dependences
* Update README
* Add modules for old AMIs

* The cleanup must be handled by region, which is extremely inefficient.
  * We will try to add the resources from all region, and just let the deletion fail on those resources that do not belong there.

# N.B. 
When adding functionality, please use separate files connected to the main one.
<hr />
