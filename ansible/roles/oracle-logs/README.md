# oracle-logs
A role to template and install a configuration for Amazon CloudWatch Agent that will capture Oracle log files and push them to CloudWatch log groups.

The JSON-formatted configuration file is rendered via a template that loops through the `oracle_logs_log_export_list` hash to define both the log group name and path to the target log files. Any changes to the configration file will trigger a restart of the AWS CloudWatch Agent service.

## Variables

| Name                            | Description                                                                                           | Type   |
|---------------------------------|-------------------------------------------------------------------------------------------------------|--------|
| oracle_logs_cwagent_service     | Defines the name of the CloudWatch Agent service, used to restart the CloudWatch Agent                | string |
| oracle_logs_cwagent_config_file | The full path to the CloudWatch Agent configuration file that will be installed                       | string |
| oracle_logs_log_group_prefix    | Defines a prefix for each log group defined in the templated configuration file                       | string |
| oracle_logs_log_export_list     | A hash defining the log group `name` and the `path` to the logs that will be pushed to that log group | hash   |


### Example variables

```yaml
oracle_logs_cwagent_service: amazon-cloudwatch-agent
oracle_logs_cwagent_config_file: "/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/file_oracle_logs.json"
oracle_logs_log_group_prefix: "oracle"
oracle_logs_log_export_list:
  - name: "alert"
    path: "/u01/app/oracle/diag/rdbms/orasid/ORASID/trace/alert_ORASIDlog"
```
