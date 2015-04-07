# stackexchange-superfirewall
A facade for firewall{} that adds enhanced functionality.

####Table of Contents


##Overview

This module makes it easy to firewall bidirectional IP connections
without using "connection tracking".

Normally Linux firewall rules are stateful, otherwise known as
"connection tracked" or "CONNTRACK".  This permits one rule to
permit traffic bidirectionally.  Tracking each "connection"
requires RAM and additional CPU resources.  For most sites this is
fine, as the number of concurrent "connections" is low.

However for high-volume websites, with hundreds of thousands
of concurrent "connections", the burden of CONNTRACK is too high.
The RAM used to store the connections is limited. The CPU spends
a lot of time searching the huge list of connections.

To avoid this resource problem, firewalls with many concurrent connections
need to use some other way to permit IP packets in both directions.
There are two common techniques.

The first technique is to do include the equivalent stateless
rules.

Typically this requires 4 stateless rules: One to permit the
incoming packets, one to permit the outgoing packets, and two more
rules which mark the packets as not needing connection tracking.

Specifically the 4 rules are:

  1. the raw table, chain=PREROUTING, same source and destination, jump=NOTRACK.
  2. the raw table, chain=OUTPUT, swap the source and destination, jump=NOTRACK.
  3. the filter table, chain=INPUT, same source and destination.
  4. the filter table, chain=OUTPUT, swap the source and destination.

However if this is an OUTPUT rule, swap the chain in 1 and 2, and 3 and 4.
If you are using ipsets, reverse them in rules 2 and 4.  Easy, right?

You can generate these 4 rules by hand, but it is error prone... especially if you are making many such rules.
When testing the rules, we found it extremely difficult to switch between the old and new rules and not make a mess of things.

Therefore, we created `firewall_enhanced{}` which does all that
work for you by just adding the parameter `track => false`.  It not
only gets all the details correct, but it does the right thing if
you toggle `track` back and forth. It also does error checking to prevent you from
using this in situations that wouldn't make sense.

I mentioned that there are 2 alternate techniques one can use.  The other
alternative technique is to throw this crap away and install a
real firewall solution like OpenBSD's PF, or buy a Cisco, or just
use anything that wasn't designed by someone who willfully ignored
all the lessons learned from the literally dozens of firewalls that
existed before Linux Ipchains. Heck, even the original Cisco PIX
was easier to configure.  Sadly many people's first experience with
firewalls has been with Linux thus they think this kind of crap is
normal and when they see a system with a decent firewall language
they get confused.  Seriously, people, why do we put up with this?

##Module Description

Normally one creates a firewall rule using the `firewall{}` provider in the puppetlabs-firewall module.

If you decide that your CONNTRACK table is getting overloaded and
you would benefit from using some other technique, simply
replace `firewall{}` with ``superfirewall::firewall_enhanced{}`
and add the parameter `track => false`.

A more judicious use of the module involves a slightly slower roll-out. We recommend:

Step 1: Measure the "before":

Use `wc -l /proc/net/nf_conntrack` to see how many connections are currently held.  Better yet, collect this data with a monitoring system so you can see the change over time.

Step 2: Adopt the new module.

Install the stackexchange-superfirewall. It requires the puppetlabs-firewall module.  It does not replace it.  Select 1 rule as a test and change
`firewall{}` to ``superfirewall::firewall_enhanced{}` 

Run puppet (possibly with `--noop`) to verify that no actual changes happen.  In this mode there should be no changes. It should generate the exact same rule as firewall{}.

Add the parameter `track => false`.  Run puppet and watch what changes carefully.  Verify that you are receiving the same firewalling behavior. If you need to roll back, simply change `track => false` to `track => true`

Step 3: Measure the "after":

Use `wc -l /proc/net/nf_conntrack` or visit your monitoring system to verify that no new connections are being tracked, and that old connections are expiring. Depending on your defaults, it can take many days for the old connections to expire.  They are held in memory for a long time after the connection is closed.

If you don't see significant changes in connection track counts, or if the firewall does not perform as expected, simply change `track => false` to `track => true`.

##Caveates

firewall_enhanced{} will protect against obvious mistakes such as using it for `action => drop` or with chains other than `INPUT` and `OUTPUT`.  However it can't stop you from all situations where the "4 stateless rules" trick is inappropriate.

We recommend using it on the few rules that create the most connections. For example, at Stack Exchange, Inc. we don't use it for rules that trigger rarely.

##Implementation notes

The name of the class is intentionally selected to make it easy to merge into puppetlabs-firewall if they want to adopt it.


