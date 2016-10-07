#!/bin/sh
PROG=`basename "$0"`

if [ $# -eq 0 ]
then
 echo "The resource group is mandatory :  $PROG <resource_group_name>"
 exit 1
else 
 RESOURCE_GRP_NAME=$1
fi

HOSTS=$(azure vm list --json -g $RESOURCE_GRP_NAME | jq .[].name | sed ':a;N;$!ba;s/\n/ /g' | sed 's/"//g')

echo ""

for HOST in $HOSTS
do
 HOST_INFO=$(curl -s $HOST:2375/info)
 NODE_ID=$(echo $HOST_INFO | jq .Swarm.NodeID | sed 's/"//g')

 if [ -z $NODE_ID ]
 then
  continue
 fi

 NODE_ADDR=$(echo $HOST_INFO | jq .Swarm.NodeAddr | sed 's/"//g')
 CLUSTER_ID=$(echo $HOST_INFO | jq .Swarm.Cluster.ID | sed 's/"//g')

 echo "========================================================================"
 echo " - HOST       : $HOST"
 echo " - NODE_ID    : $NODE_ID"
 echo " - NODE_ADDR  : $NODE_ADDR"

 if [ "$CLUSTER_ID" != "" ]
 then
   echo " - CLUSTER_ID : $CLUSTER_ID"
   SERVICES=$(curl -s $HOST:2375/services)
   SERVICES_LEN=$(echo $SERVICES | jq length)
   SERVICE_IDS=$(echo $SERVICES | jq .[].ID | sed ':a;N;$!ba;s/\n/ /g' | sed 's/"//g')
   echo " - SERVICES   : $SERVICES_LEN"

   for SERVICE_ID in $SERVICE_IDS
   do
     SERVICE=$(curl -s $HOST:2375/services/$SERVICE_ID)
     SERVICE_NAME=$(echo $SERVICE | jq .Spec.Name | sed 's/"//g')
     IMAGE=$(echo $SERVICE | jq .Spec.TaskTemplate.ContainerSpec.Image | sed 's/"//g')
     REPLICAS=$(echo $SERVICE | jq .Spec.Mode.Replicated.Replicas | sed 's/"//g')
     MODE=$(echo $SERVICE | jq .Endpoint.Spec.Mode | sed 's/"//g')
     
     echo "  - SERVICE   : '$SERVICE_NAME' [$IMAGE] - replicas: $REPLICAS, mode:  $MODE}"
    
     if [ "vip" = $MODE ]
     then
      PORT_LEN=$(echo $SERVICE | jq '.Endpoint.Ports | length')
      PORT_IDX=0
      while [ $PORT_IDX -lt $PORT_LEN ]
      do
       PORT=$(echo $SERVICE | jq .Endpoint.Ports[$PORT_IDX])
       PUB_PORT=$(echo $PORT | jq .PublishedPort)
       TARGET_PORT=$(echo $PORT | jq .TargetPort)
       echo "    - PORT    : $PUB_PORT -> $TARGET_PORT"
       PORT_IDX=$(expr $PORT_IDX + 1)
      done    
      VIP_LEN=$(echo $SERVICE | jq '.Endpoint.VirtualIPs | length')
      VIP_IDX=0
      while [ $VIP_IDX -lt $VIP_LEN ]
      do
       VIRTUAL_IP=$(echo $SERVICE | jq .Endpoint.VirtualIPs[$VIP_IDX])
       ADDR=$(echo $VIRTUAL_IP | jq .Addr | sed 's/"//g')
       echo "    - VIP     : $ADDR"
       VIP_IDX=$(expr $VIP_IDX + 1)
      done
     fi

     ##########################################################################
     # TASKS
     #########################################################################
     TASKS=$(curl -s $HOST:2375/tasks?service=$SERVICE_NAME)
     TASKS_LEN=$(echo $TASKS | jq '. | length')
     TASK_IDX=0
     while [ $TASK_IDX -lt $TASKS_LEN ]
     do
      TASK=$(echo $TASKS | jq .[$TASK_IDX])
      NODE_ID=$(echo $TASK | jq .NodeID | sed 's/"//g')
      STATUS=$(echo $TASK | jq .Status.State | sed 's/"//g')
      ADDRESSES=$(echo $TASK | jq '.NetworksAttachments[].Addresses' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/ //g' | sed 's/"//g')
       echo "    - TASK     : '$STATUS' on '$NODE_ID' - IPs: $ADDRESSES"
      TASK_IDX=$(expr $TASK_IDX + 1)
     done 
 
   done
 fi
  
done

echo "========================================================================"
echo ""

exit 0
