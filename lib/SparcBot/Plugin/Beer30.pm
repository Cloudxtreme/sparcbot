package SparcBot::Plugin::Beer30;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new;

sub register {
   my ($self, $app) = @_;

   $app->helper('beer30.poll_and_notify' => sub {
      return sub {
         state $last_status = undef;

         # get current beer30 status
         my $tx = $ua->get($app->config->{beer30_url});
         if (my $err = $tx->error) {
            print "error polling Beer30 API: $err->{message}\n";
            return;
         };
         my $beerdata = $tx->res->json;
         my $current_status = $beerdata->{statusType};

         # if the status has changed, notify all subscribed channels
         if (defined $last_status and $current_status ne $last_status) {
            my $rs = $app->db->resultset('Beer30Subscription');
            while (my $subscription = $rs->next) {
               # TODO: send message to channel
            }
         }

         # update the saved status (persisted between invocations)
         $last_status = $current_status;
      };
   });
}

1;
