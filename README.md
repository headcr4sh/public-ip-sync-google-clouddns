# Public IP address sync with Google Cloud DNS

This repository contains a simple shell script that can be used to synchronize a volatile public IP address with the Google Cloud DNS system.

It represents a DynDNS-like approach to keeping a volatile IP address synchronized and accessible from the Internet in environments where a static IP address is not present.

Long story short: if you want to make your private home's network accessible from the outside world and you already have a DNS zone that is managed by Google Cloud DNS, this project might be for you.

## Installation

The script itself is written using bash-specific shell script syntax. It utilizes the `gcloud-sdk` command line, `curl`, `dig` and a bunch of other dependencies.

For your convinience, it is is possible to run the script as a container (e.g. by using Docker).

It is possible to run the script as CronJob inside your on-prem home Kubernetes cluster, if you are about to try something fancy... ;-)
