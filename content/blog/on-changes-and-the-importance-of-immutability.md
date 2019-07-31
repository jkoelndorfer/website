---
title: "On Changes and the Importance of Immutability"
date: 2019-07-30T20:51:00-05:00
description: "Turns out, a Dockerfile is not an artifact."
tags:
    - aws
    - devops
    - tech
    - troubleshooting
---

Yesterday morning at work we had a routine deployment for a new version of our
customer-facing API. Shortly after, we noticed that our load balancer reported
it was responding to a handful of requests with HTTP 502s. The number of
impacted requests was small-ish: roughly one to ten for every 20,000 requests.
Since our API generally does not return 5XX errors (and we want to keep it
that way) we dug into it.

Application logs and load balancer target group metrics are the obvious first
stop. The application is the thing that changed, so we likely broke something
there, right?

Well, The application logs didn't reveal anything out of the ordinary. No
strange errors, only the normal assortment of bad requests from end users.
The metrics for the target group containing our app servers were no help either.
According to our stats, our application was returning no HTTP 500s whatsoever.
We spent much of the rest of the day digging through logs to try and figure
out what the problem was.

We turned up empty handed, so we resigned ourselves to rolling back the
release. We did. Much to our dismay, that did not solve the problem.

It is at this point of the story that I would like to underscore an important
lesson I have learned multiple times throughout my career: when something
breaks, it's (almost) always the change that broke it. Even when you think you
have ruled out a recent change as the culprit of breakage, there is a really
good chance you haven't. You just haven't thought of everything.

So here we sit, with a release rolled back and a small number of failing
requests on our hands. The failing requests coincided prefectly with the
start of the deployment but the rollback didn't fix it. What could the
problem possibly be?

Well, the load balancer is the thing throwing out 502s and our application
isn't. The target group metrics even said so! Some Google-fu found a couple of
[posts on Reddit][1] by users who claimed to have problems with their AWS
load balancers randomly failing with 502s. Then I started to wonder: could it
be the load balancer? I supposed so. Theoretically there could have been
some sort of weird glitch with the target group when the new instances rolled
out.

A comment by /u/KaOSoFt from the linked Reddit thread said his team has worked
around the problem by recreating the load balancer when they start to see
errors:

> We still believe it’s on AWS side, so we just started recreating the
> balancers whenever the issue comes up again. It helps for a month or two. It
> happens like once every two months now, so it’s not a big deal.

That was pretty much all the validation I needed. It must have a weird load
balancer glitch and we just needed a new one.

Since it was getting late in the evening and a less than 0.01% error rate
is no great cause for alarm, we decided to wait until this morning to deploy
a new load balancer.

After an hour of Terraform surgery and quadruple-checking that everything was
right, I stood us up another production load balancer pointing at the same
backend instances so that we could simply change the relevant DNS records for a
zero-downtime cutover. We moved over to the new load balancer and everything
went as expected. It picked up all of the traffic and after a few minutes of
watching it, we hadn't seen any 502s. Hurrah! We fixed it. Or at least we
thought we had for the next two minutes.

The problem persisted. The little voice in the back of my head -- I think they
call it "experience" -- reminded me it was the deployment that broke things.
Back to the application logs I went.

This time, I gleaned something interesting (and purely by luck, too). Amidst
thousands of other log entries, a few of nginx quietly whispered:

    [alert] 7#7: *44694 zero size buf in writer t:1 r:1 f:0 000055BFBC01A700 000055BFBC01A700-000055BFBC01A700 0000000000000000 0-0 while sending to client, client: 10.0.11.155 [...]

I knew when I saw this message that it was suspect. I'm salty about it too, because who
prefixes their error or warning logs with "alert"? "Alert" isn't a log level. Thanks,
nginx.

A bit of cross referencing revealed that the `zero size buf in writer` message
appeared once for every 502 reported by our load balancer. Now we're on to
something.  I was excited for this new bit of information but it also gave me
pause. We had been running nginx as a proxy on our application nodes for
months. Why would it stop working now? Well, it's simple really:

> Even when you think you have ruled out a recent change as the culprit of
> breakage, there is a really good chance you haven't. You just haven't thought
> of everything.

The problem, in short:

1. A new version of nginx had recently been released which seemed to introduce
   a bug.

2. The Dockerfile for the nginx container was not explicit enough in what tag
   it was based on in the `FROM` instruction. We were building on `nginx:1-alpine`.
   That doesn't offer a whole lot in terms of stability guarantees.

3. The CI/CD system for our API always rebuilds Docker images instead of deploying
   existing artifacts.

When we rolled back to the previous release, the nginx container was rebuilt. The
rebuilt container did not contain the same version of nginx as before, and so
the rollback was ineffective.  After locking in the version of nginx to what we
were using previously, the handful of 502s went away.

There are two key lessons to take from this experience. The first is, you
guessed it: it's pretty much always the recent change that breaks stuff, even
when it doesn't seem so. Second, immutability in your artifacts is really,
really important. And a Dockerfile ain't an artifact.

[1]: https://www.reddit.com/r/aws/comments/9wcgqi/what_could_cause_502_errors_in_our_load_balancer/
