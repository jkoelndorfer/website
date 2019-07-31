---
title: "Amazon EC2 Provisioning: Building for Consistency and Resiliency"
date: 2019-06-28T18:05:43-05:00
tags:
    - aws
    - devops
    - ec2
draft: true
---

About a year ago I started working on self-hosted backup infrastructure in AWS after
I dropped my CrashPlan subscription. As many dedicated developers do with their pet
projects, I completely overengineered the solution. I've had some time to refine
my EC2 provisioning strategy, both at home and in the workplace, and it's in a spot
now where I am happy with it. This post will walk through the EC2 provisioning
process and describe the strategy and its benefits.

How EC2 Instances Are Configured
--------------------------------

EC2 instances begin from an Amazon Machine Image (AMI). AMIs reference an EBS
snapshot, which is a block-level copy of the root disk (and possibly other
disks). AMIs provide pre-packaged functionality for instances. The
functionality may be as bare as a basic operating system install or may deploy
services like Kubernetes or Mongo.

When EC2 instances launch in AWS there are several configuration tasks that
are performed by a tool called [cloud-init][1]. cloud-init is baked
into many of the public AMIs you find on AWS. Among the tasks cloud-init
is responsible for are expanding the root partition to fill available space
and deploying the SSH public key so that the user can log into the instance.

[cloud-init][1] provides a couple of options for provisioning EC2 instances.
The first is by [specifying user-data for the instance][3]. The second is
[by adding scripts to one of the directories in `/var/lib/cloud/scripts`][4]
(which isn't clearly spelled out in the documentation).

For simple cases, cloud-init is likely sufficient. However, as your team
and infrastructure grow you may find it difficult to test efficiently and
maximize configuration reuse. The canonical cloud-init strategy of configuring
via user data means that changes to an auto scaling group can cause massive
changes to how your instances handle provisioning themselves, which (in my
opinion) are clearly separate concerns.

Creating Consistency
--------------------

Building an AMI
---------------

In order to meet the goal of providing a consistently behaving deployment, we
need to build our own AMI. Building an AMI ensures that the service we deploy
always starts from a known-good state. The image includes everything from the
kernel up to the application. Building an AMI also has the side benefit of
insulating us from third-party service outages, e.g. Docker Hub or Artifactory.

HashiCorp's [Packer][7] can help us build an AMI. Packer is a simple, effective
tool for creating a variety of different types of system images. In its
simplest configuration, Packer requires a builder and provisioner to describe
how images get created.

Packer provides AMI building functionality out of the box. The simplest
way to get started is to use the [EBS backend][8]. A source AMI, AWS region,
admin username, and destination AMI name are all that are required to build
your own AMI. A basic example follows:

{{< highlight json "linenos=table" >}}
{
    "builders": [{
    "type": "amazon-ebs",
    "region": "us-east-1",
    "source_ami_filter": {
      "filters": {
        "name": "debian-stretch-hvm-x86_64-gp2*"
      },
      "owners": ["679593333241"],
      "most_recent": true
    },
    "instance_type": "t3.micro",
    "ssh_username": "admin",
    "ami_name": "yourami {{isotime \"2006-01-02 1504\"}}"
  }],
  "provisioners": [...]
}
{{< /highlight >}}

This will get you an AMI based on the most recent Debian Stretch in
the us-east-1 region.

With a builder established, you need a provisioner to do the instance
configuration. There are myriad options here but in my view only one
clear winner.

Enter Ansible
-------------

My provisioning strategy leans heavily on [Ansible][2]. Ansible is part of
the configuration management class of tools, which includes the likes of
Puppet, Chef, and Salt. What makes Ansible great, though, is its exceptional
flexibility.

Ansible is designed from the ground up as an agentless tool that executes
against remote nodes, which makes testing changes a breeze. If local testing
is sufficient, fire up a virtual machine in Vagrant and point Ansible at it.
If you need to test something cloud-specific, spin up a test instance and
point Ansible at that. You don't need to push a cookbook to a Chef server
to see how your changes fare, and there is no special
configuration required for local testing.

Many of the modules provided by Ansible are idempotent, so with minimal
effort you can test a new role or a change and run it until you are
confident it is bulletproof. Tag your tasks and run only those you
want to test to go even faster.

Ansible also provides some nifty operations features: [trivially look up
the value of an AWS SSM parameter][5] and [perform a rolling upgrade
of your application][6].

### Ansible as a Packer Provisioner

Packer helpfully provides support for using Ansible as a provisioner
out of the box.

[1]: https://cloudinit.readthedocs.io/en/latest/
[2]: https://docs.ansible.com/ansible/latest/index.html
[3]: https://cloudinit.readthedocs.io/en/latest/topics/format.html
[4]: https://stackoverflow.com/a/10455027
[5]: https://docs.ansible.com/ansible/latest/plugins/lookup/aws_ssm.html
[6]: https://docs.ansible.com/ansible/latest/user_guide/guide_rolling_upgrade.html#the-rolling-upgrade
[7]: https://www.packer.io
[8]: https://www.packer.io/docs/builders/amazon-ebs.html
