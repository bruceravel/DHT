#!/bin/bash
source /home/bruce/.bashrc.local-lib
source /home/bruce/play/DHT/ssh-agent.cf
/usr/bin/perl /home/bruce/perl5/bin/dht_update
/usr/local/bin/aws s3 sync /home/bruce/.mydht/web/ s3://bruce-ravel-site/weewx
