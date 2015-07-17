# SLA enforcement script for Supportbee

[Supportbee](https://supportbee.com/) is a helpdesk software as a service. Unfortunately, it does not support SLA (Service Level Agreement) management.

Phusion needs SLA management features because we have signed support contracts with customers, with guaranteed response times. For example, [Passenger Enterprise](https://www.phusionpassenger.com/enterprise) customers can expect a default response time of 3 business days. Customers who signed up for premium support can expect shorter response times.

This script uses the Supportbee API to put an "overdue" label on unarchived support tickets that haven't been responded to within the response time window. That way, our support agents can give these tickets high priority.

## Usage

This is a Ruby script, and it is supposed to be run every hour from a cron job.

First, install gem dependencies:

    bundle install

Next, edit the config file and define your SLA requirements.

    cp config.yml.example config.yml
    chmod 600 config.yml
    editor config.yml

Finally, install a cron job for this script. For example:

    0 * * * * /path-to/enforcer.rb
