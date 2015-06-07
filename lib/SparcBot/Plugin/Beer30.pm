package SparcBot::Plugin::Beer30;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::UserAgent;
use Mojo::JSON qw/true false/;

my $ua = Mojo::UserAgent->new;
my %status_colors = (
   STOP    => 'danger',
   CAUTION => 'warning',
   GO      => 'good'
);

sub register {
   my ($self, $app) = @_;

   $app->helper('beer30.poll_and_notify' => sub {
      return sub {
         state $last_status = undef;

         # don't spam channels with updates on the weekends
         my $weekday = (localtime)[6];
         if ($weekday == 6 or $weekday == 0) {
            return;
         }

         # get current beer30 status
         my $tx = $ua->get($app->config->{beer30_status_url});
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
               $tx = $ua->post($app->config->{webhook_url} => json => {
                  channel     => $subscription->channel,
                  username    => 'Beer30 Bot',
                  icon_emoji  => ':beer:',
                  attachments => [{
                     fallback => "$beerdata->{statusType}: $beerdata->{description}",
                     color    => $status_colors{$beerdata->{statusType}},
                     title    => "Status Update: $beerdata->{statusType}",
                     text     => $beerdata->{description},
                     fields => [{
                        title => 'Changed By',
                        value => "$beerdata->{changedBy}->{firstName} $beerdata->{changedBy}->{lastName}",
                        short => true
                     }, {
                        title => 'Reason',
                        value => $beerdata->{reason} || "None",
                        short => true
                     }]
                  }]
               });
               if (my $err = $tx->error) {
                  print "could not post to slack: $err->{message}\n";
               }
            }
         }

         # update the saved status (persisted between invocations)
         $last_status = $current_status;
      };
   });
}

1;
