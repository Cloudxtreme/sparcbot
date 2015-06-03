package SparcBot::Controller::Beer30;

use Mojo::Base 'Mojolicious::Controller';
no warnings 'experimental::smartmatch';
use Mojo::UserAgent;
use Try::Tiny;

my $ua = Mojo::UserAgent->new;

# extract command from the /beer30 arg and call appropriate function
sub dispatch {
   my $self = shift;
   my ($cmd) = split ' ', $self->req->param('text');

   try {
      for (lc $cmd) {
         when ('status')      { $self->_status      };
         when ('ontap')       { $self->_ontap       };
         when ('subscribe')   { $self->_subscribe   };
         when ('unsubscribe') { $self->_unsubscribe };
         default {
            $self->render(text => 'commands: status|ontap|subscribe|unsubscribe', status => 400);
         };
      }
   } catch {
      $self->render(text => $_, status => 500);
   };
}


# Get beer30 status and return a string to the caller. Repsonse will be
# diplayed to user as a private Slackbot message.
sub _status {
   my ($self, $caller) = @_;

   my $tx = $ua->get($self->config->{beer30_url});
   if (my $err = $tx->error) { die "failed to access Beer30 API: $err->{message}\n" };
   my $beerstatus = $tx->res->json;

   $self->render(text => "$beerstatus->{statusType}: $beerstatus->{description}");
}


# Get the current beers on tap. Is this exposed in the API?
sub _ontap {
   die "not implemented\n";
}


# We still need some kind of long-running process that will poll beer30
# for changes and then push updates to each of the subscribed channels.
sub _subscribe {
   my $self    = shift;
   my $channel = $self->req->param('channel');

   my $subscription = $self->db->resultset('Beer30Subscription')->find_or_new(channel => $channel);
   if ($subscription->in_storage) {
      die "#$channel is already subscribed to Beer30 updates\n";
   }

   $subscription->insert;
   $self->render(text => "#$channel subscribed to Beer30 updates");
}

sub _unsubscribe {
   my $self    = shift;
   my $channel = $self->req->param('channel');

   my $subscription = $self->db->resultset('Beer30Subscription')->find_or_new(channel => $channel);
   unless ($subscription->in_storage) {
      die "#$channel is not subscribed to Beer30 updates\n";
   }

   $subscription->delete;
   $self->render(text => "#$channel unsubscribed from Beer30 updates");
}

1;
