# swarm-info

## Purpose
Just give an example about how to find swarm cluster info deployed on Azure VMs.
It's based on the docker remote API :
 - GET /info
 - GET /services
 - GET /services{id}
 - GET /tasks?service=name
 - ...

## Requirements
 - Need to install [azure-cli-tool](https://www.opsgility.com/blog/2016/01/20/install-azure-cli-tool-ubuntu/)
 - Logging into Azure with the CLI Tool
 - The docker nodes need to be accessible through http 2375 (unsecure API, don't forget it's just a tutorial)

## Execution
Give a resource group name in parameter like this : ./swarm.info.sh my-resource-group

![alt tag](https://github.com/scizeron/swarm-info/blob/master/output.jpg)
