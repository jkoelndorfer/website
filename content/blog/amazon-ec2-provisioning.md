---
title: "Amazon EC2 Provisioning: Building for Consistency and Resiliency"
date: 2019-06-28T18:05:43-05:00
tags:
    - aws
    - devops
    - ec2
categories:
    - technology
draft: true
---

About a year ago I started working on self-hosted backup infrastructure in AWS after
I dropped my CrashPlan subscription. As many dedicated developers do with their pet
projects, I completely overengineered the solution. I've had some time to refine
my EC2 provisioning strategy, both at home and in the workplace, and it's in a spot
now where I am happy with it. This post will walk through the EC2 provisioning
process and describe the strategy and its benefits.

Applying Configuration to an EC2 Instance
-----------------------------------------

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
(which isn't explicitly spelled out in the documentation).

My provisioning strategy hands more complex configuration tasks over to
[Ansible][2]. When the instance boots, cloud-init fires and performs
its default, minimal set of tasks. Then it invokes an Ansible playbook


[1]: https://cloudinit.readthedocs.io/en/latest/
[2]: https://docs.ansible.com/ansible/latest/index.html
[3]: https://cloudinit.readthedocs.io/en/latest/topics/format.html
[4]: https://stackoverflow.com/a/10455027
