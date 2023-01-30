![Alvis](alvis_logo.svg)
# Alvis OnDemand Dashboard DiskQuota
Alvis OnDemand dashboard app for displaying live disk quota at [Alvis OnDemand](https://portal.c3se.chalmers.se).

> **Passenger vs Dashboard app**: This is the **dashboard** version of the diskquota app! You can find the passenger plugin version at https://github.com/c3se/ood_diskquota.

![diskquota](diskquota.png)

## Prerequisites
This Ruby on Rails application is developed for Alvis OnDemand and relies on
(albeit few) local data containing information about quota and usage.  The app
requires `getfattr` (from the `attr`-package in EL8) to read statistics from
CephFS as well as modification of the dashboard application itself.

## Install
The dasboard app needs to do slight modification to the dashboard app and new
files must be added to
`ondemand/apps/dashboard/app/{models,views,controllers}/`.

```
$ git clone https://github.com/c3se/ood_dashboard_diskquota.git
```

## Customizations
You can customize the app by changing the ERB-files inside `views`.

## Debugging
User logs is found at `<ood_logs>/ondemand-nginx/<user>`, usually
`/var/log/ondemand-nginx/<user>`.
