---
title: "Glue It Together With Parameter Store"
date: 2019-06-28T19:17:06-05:00
description: Why AWS Parameter Store is awesome.

draft: no
---

[AWS Parameter Store][1] has got to be one of my favorite things for gluing
automation bits together. It's a simple, hierarchical key-value service
that can be access controlled with IAM.

I have found it useful to store these in SSM:

* Passwords to be fetched at runtime by applications.
* Secrets that are required for ad-hoc scripts run by members
  of your team. Rather than have team members set an environment
  variable or stash a config file, fetch the secrets from SSM!
* Runtime parameters whose values depend on provisioning other
  infrastructure, e.g. an EBS volume ID or SNS topic ARN.
  Terraform can put those values into SSM for you.

At work, I configured an Ansible playbook that provisions users in our
database. The password for each user is randomly generated and set on
the database user, if it does not exist already. Then Ansible puts the
value into Parameter Store (be sure to use a `SecureString`!).

Applications can fetch the secrets directly from Parameter Store by
being granted an IAM role with appropriate permissions. The configuration
"just happens" and there are no secrets in version control.

Magnificent!

[1]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
