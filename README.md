# dbaops

A repository for Ansible code and resources for use by the DBA Ops team.

## ansible

The `ansible` directory contains all the code necessary to deploy configuration to the Chips DB EC2 instances. It is configured in a way to be executed via CI tooling and not directly.


### roles

The repository contains the following Ansible roles
* `dbaops-scripts`: Installs common scripts and configures cron schedules as required
* `oracle-logs`: Installs an Amazon CloudWatch Agent log file configuration to capture and push common Oracle log files
