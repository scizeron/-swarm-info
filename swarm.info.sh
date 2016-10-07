#!/bin/bash

declare -r prog=`basename "$0"`
declare -r dockerRemoteApiPort=2375
declare -A hostsMap

if [ $# -eq 0 ]
then
 echo "The resource group is mandatory :  $prog <resource_group_name>"
 exit 1
else
 resourceGroupName=$1
fi

hosts=$(azure vm list --json -g $resourceGroupName | jq .[].name | sed ':a;N;$!ba;s/\n/ /g' | sed 's/"//g')

echo ""

for host in $hosts
do
 hostInfo=$(curl -s $host:$dockerRemoteApiPort/info)
 nodeId=$(echo $hostInfo | jq .Swarm.NodeID | sed 's/"//g')

 if [ -z $nodeId ]
 then
  continue
 fi

 nodeAddr=$(echo $hostInfo | jq .Swarm.NodeAddr | sed 's/"//g')
 clusterId=$(echo $hostInfo | jq .Swarm.Cluster.ID | sed 's/"//g')

 echo "========================================================================"
 echo " - host       : $host"
 echo " - nodeId     : $nodeId"
 echo " - nodeAddr   : $nodeAddr"

 if [ "$clusterId" != "" ]
 then
   echo " - clusterId  : $clusterId"

   ##########################################################################
   # NODES
   ##########################################################################
   nodes=$(curl -s $host:$dockerRemoteApiPort/nodes)
   nodesLen=$(echo $nodes | jq length)
   echo " - nodes      : $nodesLen"
   nodeIdx=0
   while [ $nodeIdx -lt $nodesLen ]
   do
    nodeName=$(echo $nodes | jq .[$nodeIdx].Description.Hostname | sed 's/"//g')
    nodeId=$(echo $nodes | jq .[$nodeIdx].ID | sed 's/"//g')
    declare "node$nodeId"=$nodeName    
    echo "  - node      : $nodeName  - id: $nodeId"
    nodeIdx=$(expr $nodeIdx + 1)
   done

   ##########################################################################
   # SERVICES
   ##########################################################################
   services=$(curl -s $host:$dockerRemoteApiPort/services)
   servicesLen=$(echo $services | jq length)
   serviceIds=$(echo $services | jq .[].ID | sed ':a;N;$!ba;s/\n/ /g' | sed 's/"//g')
   echo " - services   : $servicesLen"

   for serviceId in $serviceIds
   do
     service=$(curl -s $host:$dockerRemoteApiPort/services/$serviceId)
     serviceName=$(echo $service | jq .Spec.Name | sed 's/"//g')
     image=$(echo $service | jq .Spec.TaskTemplate.ContainerSpec.Image | sed 's/"//g')
     replicas=$(echo $service | jq .Spec.Mode.Replicated.Replicas | sed 's/"//g')
     mode=$(echo $service | jq .Endpoint.Spec.Mode | sed 's/"//g')

     echo "  - service   : '$serviceName' [$image] - replicas: $replicas, mode:  $mode}"

     if [ "vip" = $mode ]
     then
      portsLen=$(echo $service | jq '.Endpoint.Ports | length')
      portIdx=0
      while [ $portIdx -lt $portsLen ]
      do
       port=$(echo $service | jq .Endpoint.Ports[$portIdx])
       pubPort=$(echo $port | jq .PublishedPort)
       targetPort=$(echo $port | jq .TargetPort)
       echo "   - port     : $pubPort -> $targetPort"
       portIdx=$(expr $portIdx + 1)
      done
      vipsLen=$(echo $service | jq '.Endpoint.VirtualIPs | length')
      vipIdx=0
      while [ $vipIdx -lt $vipsLen ]
      do
       virtualIp=$(echo $service | jq .Endpoint.VirtualIPs[$vipIdx])
       addr=$(echo $virtualIp | jq .Addr | sed 's/"//g')
       echo "   - vip      : $addr"
       vipIdx=$(expr $vipIdx + 1)
      done
     fi

     ##########################################################################
     # TASKS
     #########################################################################
     tasks=$(curl -s -G -XGET $host:$dockerRemoteApiPort/tasks --data-urlencode "filters={\"service\":[\"$serviceName\"]}")
     tasksLen=$(echo $tasks | jq '. | length')
     taskIdx=0
     while [ $taskIdx -lt $tasksLen ]
     do
      task=$(echo $tasks | jq .[$taskIdx])
      nodeId=$(echo $task | jq .NodeID | sed 's/"//g')
      nodeNameVar="node$nodeId"
      nodeName=${!nodeNameVar}
      status=$(echo $task | jq .Status.State | sed 's/"//g')
      addresses=$(echo $task | jq '.NetworksAttachments[].Addresses' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/ //g' | sed 's/"//g')
      echo "   - task     : '$status' - node: $nodeName - ip(s): $addresses"
      taskIdx=$(expr $taskIdx + 1)
     done

   done
 fi

done

echo "========================================================================"
echo ""

exit 0

