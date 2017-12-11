# terraform-aws-openshift

This project shows you how to set up OpenShift Origin on AWS using Terraform. This the companion project to my article [Get up and running with OpenShift on AWS](http://www.dwmkerr.com/get-up-and-running-with-openshift-on-aws/).

![OpenShift Sample Project](./docs/openshift-sample.png)

I am also adding some 'recipes' which you can use to mix in more advanced features:

- [Recipe](./)

## Overview

Terraform is used to create infrastructure as shown:

![Network Diagram](./docs/network-diagram.png)

Once the infrastructure is set up an inventory of the system is dynamically
created, which is used to install the OpenShift Origin platform on the hosts.

## Prerequisites

You need:

1. [Terraform](https://www.terraform.io/intro/getting-started/install.html) - `brew update && brew install terraform`
2. An AWS account, configured with the cli locally -
```
if [[ "$unamestr" == 'Linux' ]]; then
        dnf install -y awscli || yum install -y awscli
elif [[ "$unamestr" == 'FreeBSD' ]]; then
        brew install -y awscli
fi
```

## Creating the Cluster

Create the infrastructure first:

```bash
# Make sure ssh agent is on, you'll need it later.
eval `ssh-agent -s`

# You may also need to do the following if you just installed terraform
terraform init

# And if you don't have an RSA keypair setup for ssh (replace <YOUR_USERNAME> with something like 'chris.marth')
ssh-keygen -t rsa -C "<YOUR_USERNAME>@pinksummit.com"

# Create the infrastructure.
make infrastructure
```

You will be asked for a region to deploy in, use `us-east-1` or your preferred region. You can configure the nuances of how the cluster is created in the [`main.tf`](./main.tf) file. Once created, you will see a message like:

```
$ make infrastructure
var.region
  Region to deploy the cluster into

  Enter a value: ap-southeast-1

...

Apply complete! Resources: 20 added, 0 changed, 0 destroyed.
```

That's it! The infrastructure is ready and you can install OpenShift. Leave about five minutes for everything to start up fully.

## Installing OpenShift

To install OpenShift on the cluster, just run:

```bash
make openshift
```

You will be asked to accept the host key of the bastion server (this is so that the install script can be copied onto the cluster and run), just type `yes` and hit enter to continue.

It can take up to 30 minutes to deploy. If this fails with an `ansible` not found error, just run it again.

When running this initially, the post-install scripts failed, and I had to run them manually. To do that just ssh into each machine (master or node) and manually run the commands from the post-install scripts. The admin password is set in the master post install script. If you don't change it, it'll be '123'. You can also log into the master after the fact and update the passwords manually using htpasswd. See this link for more information: https://docs.openshift.org/latest/install_config/configuring_authentication.html#HTPasswdPasswordIdentityProvider

Once the setup is complete, just run:

```bash
make browse-openshift
```

To open a browser to admin console, use the following credentials to login:

```
Username: admin
Password: 123
```

## Accessing and Managing OpenShift

There are a few ways to access and manage the OpenShift Cluster.

### OpenShift Web Console

You can log into the OpenShift console by hitting the console webpage:

```bash
make browse-openshift

# the above is really just an alias for this!
open $(terraform output master-url)
```

The url will be something like `https://a.b.c.d.xip.io:8443`.

### The Master Node

The master node has the OpenShift client installed and is authenticated as a cluter administrator. If you SSH onto the master node via the bastion, then you can use the OpenShift client and have full access to all projects:

```
$ make ssh-master # or if you prefer: ssh -t -A ec2-user@$(terraform output bastion-public_dns) ssh master.openshift.local
$ oc get pods
NAME                       READY     STATUS    RESTARTS   AGE
docker-registry-1-d9734    1/1       Running   0          2h
registry-console-1-cm8zw   1/1       Running   0          2h
router-1-stq3d             1/1       Running   0          2h
```

Notice that the `default` project is in use and the core infrastructure components (router etc) are available.

You can also use the `oadm` tool to perform administrative operations:

```
$ oadm new-project test
Created project test
```

### The OpenShift Client

From the OpenShift Web Console 'about' page, you can install the `oc` client, which gives command-line access. Once the client is installed, you can login and administer the cluster via your local machine's shell:

```bash
oc login $(terraform output master-url)
```

Note that you won't be able to run OpenShift administrative commands. To administer, you'll need to SSH onto the master node. Use the same credentials (`admin/123`) when logging through the commandline.

![Welcome Screenshot](./docs/welcome.png)

## Additional Configuration

The easiest way to configure is to change the settings in the [./inventory.template.cfg](./inventory.template.cfg) file, based on settings in the [OpenShift Origin - Advanced Installation](https://docs.openshift.org/latest/install_config/install/advanced_install.html) guide.

When you run `make openshift`, all that happens is the `inventory.template.cfg` is turned copied to `inventory.cfg`, with the correct IP addresses loaded from terraform for each node. Then the inventory is copied to the master and the setup script runs. You can see the details in the [`makefile`](./makefile).

## Choosing the OpenShift Version

To change the version, just update the version identifier in this line of the [`./install-from-bastion.sh`](./install-from-bastion.sh) script:

```bash
git clone -b release-3.6 https://github.com/openshift/openshift-ansible
```

Available versions are listed [here](https://github.com/openshift/openshift-ansible#getting-the-correct-version).

OpenShift 3.5 is fully tested, and has a slightly different setup. You can build 3.5 by checking out the [`release/openshift-3.5`](https://github.com/dwmkerr/terraform-aws-openshift/tree/release/openshift-3.5) branch.

## Destroying the Cluster

Bring everything down with:

```
terraform destroy
```

## Makefile Commands

There are some commands in the `makefile` which make common operations a little easier:

| Command                 | Description                                     |
|-------------------------|-------------------------------------------------|
| `make infrastructure`   | Runs the terraform commands to build the infra. |
| `make openshift`        | Installs OpenShift on the infrastructure.       |
| `make browse-openshift` | Opens the OpenShift console in the browser.     |
| `make ssh-bastion`      | SSH to the bastion node.                        |
| `make ssh-master`       | SSH to the master node.                         |
| `make ssh-node1`        | SSH to node 1.                                  |
| `make ssh-node2`        | SSH to node 2.                                  |
| `make sample`           | Creates a simple sample project.                |

## Pricing

You'll be paying for:

- 1 x m4.xlarge instance
- 2 x t2.large instances

## Recipe - Adding Splunk

To integrate with splunk, merge the `recipes/splunk` branch then run `make splunk` after creating the infrastructure and installing OpenShift:

```
git merge recipes/splunk
make infracture
make openshift
make splunk
```

There is a full guide at:

http://www.dwmkerr.com/integrating-openshift-and-splunk-for-logging/

You can quickly rip out container details from the log files with this filter:

```
source="/var/log/containers/counter-1-*"  | rex field=source "\/var\/log\/containers\/(?<pod>[a-zA-Z0-9-]*)_(?<namespace>[a-zA-Z0-9]*)_(?<container>[a-zA-Z0-9]*)-(?<conatinerid>[a-zA-Z0-9_]*)" | table time, host, namespace, pod, container, log
```

## Troubleshooting

**Image pull back off, Failed to pull image, unsupported schema version 2**

Ugh, stupid OpenShift docker version vs registry version issue. There's a workaround. First, ssh onto the master:

```
$ ssh -A ec2-user@$(terraform output bastion-public_dns)

$ ssh master.openshift.local
```

Now elevate priviledges, enable v2 of of the registry schema and restart:

```bash
sudo su
oc set env dc/docker-registry -n default REGISTRY_MIDDLEWARE_REPOSITORY_OPENSHIFT_ACCEPTSCHEMA2=true
systemctl restart origin-master.service
```

You should now be able to deploy. [More info here](https://github.com/dwmkerr/docs/blob/master/openshift.md#failed-to-pull-image-unsupported-schema-version-2).

## References

 - https://www.udemy.com/openshift-enterprise-installation-and-configuration - The basic structure of the network is based on this course.
 - https://blog.openshift.com/openshift-container-platform-reference-architecture-implementation-guides/ - Detailed guide on high available solutions, including production grade AWS setup.
 - https://access.redhat.com/sites/default/files/attachments/ocp-on-gce-3.pdf - Some useful info on using the bastion for installation.
 - http://dustymabe.com/2016/12/07/installing-an-openshift-origin-cluster-on-fedora-25-atomic-host-part-1/ - Great guide on cluster setup.
 - [Deploying OpenShift Container Platform 3.5 on AWS](https://access.redhat.com/documentation/en-us/reference_architectures/2017/html-single/deploying_openshift_container_platform_3.5_on_amazon_web_services/)
