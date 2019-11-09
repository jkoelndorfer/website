---
title: "Amazon EC2 Provisioning: Building for Consistency and Resiliency"
date: 2019-11-09T12:26:00-05:00
tags:
    - aws
    - devops
    - ec2
---

A couple years ago I started working on self-hosted backup infrastructure in AWS after
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
The first is by [specifying user data for the instance][3]. The second is
[by adding scripts to one of the directories in `/var/lib/cloud/scripts`][4]
(which isn't clearly spelled out in the documentation).

For simple cases, cloud-init is likely sufficient. However, as your team
and infrastructure grow you may find it difficult to test efficiently and
maximize configuration reuse. The canonical cloud-init strategy of configuring
via user data means that changes to an auto scaling group can cause massive
changes to how your instances handle provisioning themselves, which (in my
opinion) are clearly separate concerns.

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

### Enter Ansible

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

Packer helpfully provides support for using Ansible as a provisioner, too.
Specify it like so:

{{< highlight json "linenos=table" >}}
{
  [...]
  "provisioners": [
    {
      "type": "ansible",
      "playbook_file": "your-playbook.yml",
      "extra_arguments": []
    }
  ]
}
{{< /highlight >}}

If you have any extra arguments you'd like to pass to Ansible, specify
them in `extra_arguments`.

With this configuration, Packer will seamlessly invoke Ansible to build
your AMI. Pretty slick!

Creating Consistency
--------------------

We've now got a basic AMI and a way to build it reproducibly via Ansible,
but that only gets us halfway to consistent deployments. There is still
plenty of room to do it wrong! Unfortunately, there is no one right answer
for any organization; try and think about all of the variables that might
change on the way from dev to prod. For example:

* If AMIs are not promoted, a rebuild may cause an updated version of a
  package to change the behavior of your EC2 instance. A full hard disk
  is the classic systems "oopsie", and it's certainly possible to do
  that inadvertently with changes to your syslog configuration.
* If Docker images are not promoted, a rebuild may cause packages inside
  your container to be updated. If you base your container on something
  stable, like Debian, that risk is reduced. Mistakes do happen, though;
  even security fixes can negatively impact your application.
* Your production environment almost certainly is not an exact replica
  of your staging or development environments. Generally development
  and staging have less redundancy at the app node and database level.
  They also have tend to have more lax security than what you find in
  production. Lastly, they tend to not contain an exact copy of the
  data as it exists in production.  Think about how lower environments differ
  between development, staging, and production and what you can do to mitigate
  the risk of breakage as an application is prepared for release.
* Does the AMI you built depend on the availability of third-party services
  to function properly? Can you reduce or eliminate this dependence by
  modifying your build process and/or runtime provisioning process?

### How to Leverage User Data

A common practice is to use user data to contain runtime provisioning code.
The problem with doing this is that an AMI, even a very basic one, is going
to require the end user to know a lot about how the AMI was constructed
in order for user data provsioning to be successful.

Whoever deploys an autoscaling group and configures the user data for launched
instances will have to know:

* What distribution is the AMI based on? That will influence what package manager
  you use, what software and libraries are available (and their versions), the location
  of configuration files, etc.
* What software is available on the AMI?
* Are there any custom configuration file paths? Is there anything that _must_ be configured?

You can mitigate the above issues by using a centralized configuration
management tool, like Puppet, Chef, or Salt, but then of course you lose out on
some of the consistency described before. Packages on mirrors can change.  Code
in common config management modules can sometimes have unintended side effects
that break previously working production app deployments.

Instead, treat user data only as metadata and let the AMI provision itself using Ansible.
If provisioning is baked into the AMI, an instance typically doesn't need very much
information at all to get up and running.

I recommend creating minimal standard set of metadata that all instances can rely
on at runtime. This will include at least the environment, but you might find
you need some other things too. Present your user data as JSON so that encoding
and decoding are easy.

Additionally, include an `extra` key which is a dictionary that includes ad-hoc,
optional keys. It will allow you to pass additional, instance-specific data or
could act as a feature flag for common functionality you're not ready to deploy
to all of your instances yet.

I've used the `extra` key for both of these purposes. A really neat use
for instance-specific data is passing an EBS volume ID that the instance can
attach to itself when it boots. As a feature flag, I have used `extra` to
enable/disable logging to a centralized service to minimize our bill during the
proof-of-concept phase.

The Downsides and How to Mitigate Them
--------------------------------------

So far we've examined how to provision for consistency and what the benefits are.
This strategy isn't without drawbacks, however.

### Lots of AMIs

Every new version of a service you release is going to have an associated AMI, and
those AMIs aren't going to clean themselves up. You're going to have to lifecycle
them yourself. There are a number of ways to skin this cat, but my preferred approach
is to run two Lambda functions on CloudWatch schedules.

One function runs every 20 minutes and takes an inventory of AMIs used by
currently running EC2 instances.  For those AMIs, it updates a tag called
`LastUsed` with a timestamp for the current time.  For _all_ AMIs, it updates a
tag called `LastUsedRuntime` with a timestamp for the current time. This tag
indicates when the scan process last ran.

The other function performs AMI cleanup, and it runs once per day. It scans all
AMIs that have a tag `AutoCleanup` set to `true`. For each of the discovered
AMIs, it looks at the `LastUsed` tag. If `LastUsed` is more than a week old
_and_ `LastUsedRuntime` is within the last hour, the AMI and its associated
volume snapshots are deleted.

The `AutoCleanup` tag ensures AMIs not built using our normal process are never
automatically deleted, e.g. if someone snapshots a running instance. The
`LastUsedRuntime` tag protects you in case the inventory script stops running
for some reason. Without it, your cleanup script may delete AMIs you are
actually using.

### Deploying Common Changes Requires AMI Rebuilds

Changing any common configuration for your EC2 instances would require you to
rebuild _every_ service AMI in order to fully deploy it. I'm of the opinion
that this isn't actually a bad thing since it gives you the opportunity to
test common changes and roll them out slowly. It does add some administrative
overhead, though, so how best to minimize it?

A well-oiled CI/CD system is the best strategy for deploying common changes
with minimal overhead. You can let the changes roll out organically as your
services are updated, or fire off all your builds to push changes quickly.

Because each service independently be rolled back to a previous AMI, you
can deploy your common configuration changes with more confidence.

The Final Product
-----------------

If you heed all the advice above, you'll end up with something roughly like this:

* An AMI build process that leverages Packer and Ansible for repeatability.
* Common, reusable Ansible roles so that core functionality, like configuring user
  logins, centralized logging, and monitoring, is consistent across every instance.
* An AMI that is built for each service you have running in EC2 and can be promoted
  from dev to higher-level environments.
* EC2 instances that are almost entirely self contained and have very little
  dependence on third-party services when they launch.
* EC2 instances whose behavior will not change between launches, except for the limited
  set of passed-in parameters that you configure (either via user data or something
  like Parameter Store).

This solution has served me well over the last couple of years in both a
personal and professional capacity. What are your thoughts? Do you employ a
similar strategy?  How does it work for your organization? Feel free to reach
out to me via [e-mail][9] or [LinkedIn][10].

[1]: https://cloudinit.readthedocs.io/en/latest/
[2]: https://docs.ansible.com/ansible/latest/index.html
[3]: https://cloudinit.readthedocs.io/en/latest/topics/format.html
[4]: https://stackoverflow.com/a/10455027
[5]: https://docs.ansible.com/ansible/latest/plugins/lookup/aws_ssm.html
[6]: https://docs.ansible.com/ansible/latest/user_guide/guide_rolling_upgrade.html#the-rolling-upgrade
[7]: https://www.packer.io
[8]: https://www.packer.io/docs/builders/amazon-ebs.html
[9]: mailto:jkoelndorfer@gmail.com
[10]: https://www.linkedin.com/in/jkoelndorfer
