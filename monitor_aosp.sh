#!/bin/bash


function w_log()
{
  s=`date "+%y%m%d_%H%M%S"`
  echo  "$s:$1" |tee -a  /root/task_monitor.log
}

aliyun configure switch --profile default
  instance_id=$(aliyun ecs DescribeInstances --RegionId us-east-1 --InstanceName openfde_aosp_make \
            --PageSize 1 \
            | jq -r '.Instances.Instance[0].InstanceId')

          if [[ -z "$instance_id" || "$instance_id" == "null" ]]; then
		  w_log "instance id not found, exit"
            exit 0
          fi


	    invoke_id=`aliyun ecs RunCommand \
            --Type "RunShellScript" \
            --CommandContent "ps -ef |grep -w "wrapper_img.sh" |grep -v grep " \
            --InstanceId.1 "$instance_id" \
            --Name "monitor-command" \
            | jq -r '.InvokeId'`

          if [[ -z "$invoke_id" || "$invoke_id" == "null" ]]; then
		  w_log "invoke id not found or exec command failed, exit"
            exit 0
          fi


	      for i in {1..10}; do
            result=`aliyun ecs DescribeInvocationResults \
              --InvokeId "$invoke_id"`

            status=$(echo "$result" | jq -r '.Invocation.InvocationResults.InvocationResult[0].InvokeRecordStatus')
            output=$(echo "$result" | jq -r '.Invocation.InvocationResults.InvocationResult[0].Output')
            invocationStatus=$(echo "$result" | jq -r '.Invocation.InvocationResults.InvocationResult[0].InvocationStatus')

	    w_log "current status: $status"
            if [ "$status" = "Finished" ]; then
              if [ "$invocationStatus" = "Success" ]; then
		      w_log "success"
		      w_log "output:"
		      out=`echo $output |base64 -d`
		      w_log "$out"
			echo "$output" | base64 -d |grep "wrapper_img.sh" 
			if [[ $? -eq 0 ]]; then
				w_log "compile task is still running"
				  exit 0
			else
				w_log "compile task finished"
				  exit 0
			fi
              else
		w_log "query failed $invocationStatus, wrapper must exit"
			  exit 0
              fi
            elif [ "$status" = "Failed" ]; then
		w_log "exec query command failed "
              exit 1
            fi
            sleep 10
          done
