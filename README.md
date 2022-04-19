## Kubernetes Setup using AWS and Terraform

<img src="https://github.com/surfd4wg/alice-aws-terraform-ec2-kubernetes/blob/main/pictures/kube.png?raw=true">

This repository is copied from opencredo/k8s-terraform-ansible-sample and alicek106/aws-terraform-kubernetes

> https://github.com/opencredo/k8s-terraform-ansible-sample
this one did not use kubespray
and
> https://github.com/alicek106/aws-terraform-kubernetes
this one forgot to install ansible 

Also, This repository will create 3 workers, 3 master, and 3 etcd Kubernetes cluster by default. You can adjust the number of each node by changing below **Variables**. 



## Step 1. Install Terraform

1. All steps will be conducted under Docker container for beginners.

   ```
   # sudo chmod 666 /var/run/docker.sock
   # docker run -it --name terraform-aws-kube -h terraform-aws-kube ubuntu:21.10
   ```

2. Install required packages.

   ```
   $ export DEBIAN_FRONTEND=noninteractive 
   $ apt-get update 
   $ apt-get -y install tzdata
   $ apt-get -y install iputils-ping net-tools jq nano telnet
   $ # set your timezone
   $ ln -fs /usr/share/zoneinfo/US/Mountain /etc/localtime
   $ dpkg-reconfigure --frontend noninteractive tzdata
   $ apt update && apt install git python3 python3-pip unzip wget vim -y && \
       apt install software-properties-common -y && \
       add-apt-repository --yes --update ppa:ansible/ansible && \
       apt install ansible -y && \
       git clone https://github.com/surfd4wg/alice-aws-terraform-ec2-kubernetes.git && \
       cd alice-aws-terraform-ec2-kubernetes/terraform
   ```

3. Download terraform binary (amd64 | arm64).

   ```
   $ wget https://releases.hashicorp.com/terraform/1.0.11/terraform_1.1.8_linux_amd64.zip && \
       unzip terraform_1.1.8_linux_amd64.zip && \
       rm terraform_1.1.8_linux_amd64.zip && \
       mv terraform /usr/bin && chmod +x /usr/bin/terraform
   ```
   ```
   $ wget https://releases.hashicorp.com/terraform/1.1.8/terraform_1.1.8_linux_arm64.zip && \
       unzip terraform_1.1.8_linux_arm64.zip && \
       rm terraform_1.1.8_linux_arm64.zip && \
       mv terraform /usr/bin && chmod +x /usr/bin/terraform
   ```

4. Export your own AWS Access / Secret keys

   ```
   $ export AWS_ACCESS_KEY_ID=<Your Access Key in AWS>
   $ export AWS_SECRET_ACCESS_KEY=<Your Access Key in Secret>
   ```

5. Initialize terraform and generate your SSH key pair for aws_key_pair

   ```
   $ ssh-keygen -t rsa -N "" -f ../keys/tf-kube
   $ terraform init
   $ terraform plan 
   ```

6. Adjust the number of ```etcd```, ```worker```, and ```master``` nodes using **Step 2** as shown below.
7. Create all objects in AWS. It will trigger to create VPC, Subnet, EC2 instances, etc.

   ```
   $ terraform apply -auto-approve
   ```
   Keep track of the output for the api dns name, workers public ip's
   ssh -i ../keys/tf-kube ubuntu@<worker public ip address>


## Step 2. Set Variables in variables.tf 

You can change configuration of file ```variables.tf```, such as the number of each node.

- **number_of_controller** : The number of master nodes that act only as a master role. 
- **number_of_etcd** : The number of etcd nodes that act only as a etcd role. 
- **number_of_controller_etcd** : The number of nodes that run etcd and master **at the same time**.
- **number_of_worker** : The number of workers. 

It is recommended that the number of **[etcd + controller_etcd]**, **[controller + controller_etcd]** to be odd. For example, below setting is desirable and can be converted into inventory as shown below. Note that below inventory and setting is just example, not really written configuration.

```
number_of_controller = 2

number_of_etcd = 2

number_of_controller_etcd = 1
```

.. is same to

```
[kube_control_plane:children]
Instnace-A # (1st master)
Instnace-B # (2nd master)
Instnace-C # (3rd master)  (1st etcd)

[etcd:children]
Instnace-C # (3rd master)  (1st etcd)
Instnace-D #               (2nd etcd)
Instnace-E #               (3rd etcd)

[etcd:children]
...

```

Above example is just example. In [groups](./ansible/hosts/groups), instances are represented as `group`, such as `_controller`. These groups are filtered by [inventory_aws_ec2.yml](./ansible/hosts/inventory_aws_ec2.yml) using `filters`. If you want to change filters to choose instance correctly (e.g. because of change of Owner tag, or change of region, default to ap-northeast-2), edit inventory_aws_ec2.yml file.

[Optional] if you want to change ClusterID, set ```cluster_id_tag``` to another value, not ```alice```.

## Step 3. Ansible and Kubespray

First of all, edit `inventory_aws_ec2.yml` file to match your own configurations, e.g. region and other tags.

1. In ansible directory, install all dependencies package.

   ```
   $ cd ..
   $ cd ansible
   $ pip3 install -r requirements.txt
   ```

2. Install python related modules using **raw** ansible module to all EC2 instances.

   ```
   $ ansible-playbook --private-key ../keys/tf-kube infra.yaml
   ```

   To check whether it works, use below ansible **ping** module

   ```
   $ ansible --private-key ../keys/tf-kube -m ping all
   ```

3. Download kubespray. You can adjust proper version, but I used v2.18.1 kubespray :D

   ```
   $ wget https://github.com/kubernetes-sigs/kubespray/archive/v2.18.1.zip && \
       unzip v2.18.1.zip && rm v2.18.1.zip
   ```
----
**Warning!** Variables of Kubespray (ansible/hosts/group_vars/) is copied from v2.18.1. **If you want to use another version of kubespray**, you have to remove ansible/hosts/group_vars directory and copy sample variables directory from specific kubespray version. It is usally located in kubespray-x.x.x/inventory/sample/group_vars.


4. Install Kubernetes. This could generate a lot of output, so you might want to do the second option to output to a file.

   Output to the terminal:

   ```
   $ ansible-playbook -b --private-key \
     ../keys/tf-kube kubespray-2.18.1/cluster.yml
   ```

   Output to a file:
   ```
   $ ansible-playbook -b --private-key \
     ../keys/tf-kube kubespray-2.18.1/cluster.yml >> kubernetes_kubespray_install.txt
   ```


## Test

SSH to your master instance, and get nodes.

```
root@aws-kube:/aws-terraform-kubernetes/ansible# ssh -i ../keys/tf-kube ubuntu@<Master IP>

...
Last login: Mon Mar 25 10:03:32 2019 from 13.124.49.60
ubuntu@ip-10-43-0-40:~$ sudo su
root@ip-10-43-0-40:/home/ubuntu# kubectl get nodes
NAME                                                      STATUS   ROLES                  AGE     VERSION
ec2-13-125-117-199.ap-northeast-2.compute.amazonaws.com   Ready    <none>                 4m13s   v1.22.8
ec2-13-125-54-209.ap-northeast-2.compute.amazonaws.com    Ready    control-plane,master   5m34s   v1.22.8
ec2-13-209-20-227.ap-northeast-2.compute.amazonaws.com    Ready    <none>                 4m12s   v1.22.8
ec2-3-34-94-130.ap-northeast-2.compute.amazonaws.com      Ready    control-plane,master   6m1s    v1.22.8
ec2-3-38-165-142.ap-northeast-2.compute.amazonaws.com     Ready    control-plane,master   5m22s   v1.22.8
ec2-52-79-249-245.ap-northeast-2.compute.amazonaws.com    Ready    <none>                 4m13s   v1.22.8
```

<p align="center"><img src="https://github.com/surfd4wg/alice-aws-terraform-ec2-kubernetes/blob/main/pictures/kube2.png?raw=true" width="570" height="350"></p>

## Cleanup

In terraform directory, use below command. It will destroy all objects, including EC2 Instances

```
$ terraform destroy -auto-approve
```
## If you get disconnected from the Docker Container
```
$ sudo chmod 666 /var/run/docker.sock
$ docker ps -a
$ docker container restart <container id>
$ docker exec -it <container id> /bin/bash
```
## Exiting and removing the Docker Container

Exit the docker container and kill it

CAUTION: Do not remove the docker container unless you have done a terraform destroy, or have backedup your terraform state file onto s3 or some other storage outside of the docker container.

```
$ exit
$ sudo chmod 666 /var/run/docker.sock
$ docker ps -a
$ docker stop <CONTAINER ID>
$ docker rm <CONTAINER ID>
```

- It assumes that **master** acts as an **etcd** node. It should be modified to separate **etcd** and **master** role.(solved)
- Health check of master node is impossible using https:6443 in ELB. (It is recommended to use another proxy such as nginx in Master Node for healthcheck. Health check proxy should be deployed by yourself :D)
- Node IP range is limited beacuse node IP is allocated between VPC CIDR + 10, 20, 30... etc.  It should be changed if you want to use in production environment.
