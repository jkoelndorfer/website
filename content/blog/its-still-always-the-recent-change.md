---
title: "It's _Still_ Always The Thing That Changed"
date: 2022-03-16T15:06:00-05:00
tags:
    - aws
    - devops
    - troubleshooting
---

aeris incident:
    * new release went out
    * ok for 15 minutes
    * downsized Mongo DB
    * most requests started timing out as soon as the primary was stepped down
    * nginx is getting requests, but they are timing out because PHP-FPM is not responding
    *
    * issue: Aeris API update changed batch endpoint behavior so it split batch into
      multiple async requests. it would then issue those requests against the Aeris API
      again. Sub-requests can get stuck in a queue behind the primary request, causing
      the service to eventually deadlock.
