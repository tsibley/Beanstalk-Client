use strict;
use warnings;

use Test::More;
use Beanstalk::Client;

my $client = Beanstalk::Client->new;

plan skip_all => "Need local beanstalkd server running"
  unless $client->connect;

#$client->debug(1);

# Try to trigger a short sysread() of just the first line which leaves the
# second response line waiting to be read from the socket instead of in our
# internal buffer (where it would be wiped out by the next command).
my $job;
my ($i, $max) = (1, 100);
do {
  $job = $client->put({ priority => -1 }, "some data");
  die "got a job?!" if $job;
  die "error isn't BAD_FORMAT?! got: " . $client->error
    if $client->error ne "BAD_FORMAT";
} while $i++ <= $max and length $client->{_recv_buffer};

plan skip_all => "Can't trigger desync via short sysread() on your system in less than $max tries"
  if $i > $max;

diag "Triggered desync via short sysread() in $i tries";

ok !$job, "no job returned on bad priority of -1";
is $client->error, "BAD_FORMAT", "error is BAD_FORMAT";

if (not ok $client->use("another_tube"), "use another_tube") {
  is $client->error, '', "no error from use cmd"
    or diag "An error of UNKNOWN_COMMAND indicates desync";
} else {
  ok 1, "no error from use cmd";
}

done_testing;
