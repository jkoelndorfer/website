john.koelndorfer.com
====================

This repository contains the complete source for my personal site
and blog, https://john.koelndorfer.com

Use `./deploy prod` to deploy to the live version of the site, or
`./test` to run `hugo` in local testing mode.

Deploying requires a `default` AWS profile that can list accounts and
their tags in the organization. The script finds the account tagged
`env=<environment>` and `function=personal-website`, then assumes its
`OrganizationAccountAccessRole`. Objects are uploaded privately, so
CloudFront must be granted read access to the bucket.
