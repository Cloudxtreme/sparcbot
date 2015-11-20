package SparcBot::Controller::Beer30;

use Mojo::Base 'Mojolicious::Controller';
no warnings 'experimental::smartmatch';
use Mojo::UserAgent;
use Mojo::JSON qw/true false/;
use Try::Tiny;

my $ua = Mojo::UserAgent->new;

# extract command from the /beer30 arg and call appropriate function
sub dispatch {
   my $self = shift;
   my ($cmd, $args) = split ' ', $self->req->param('text'), 2;

   try {
      for (lc $cmd) {
         when ('status')      { $self->_status           };
         when ('request')     { $self->_request($args)   };
         when ('ontap')       { $self->_ontap            };
         when ('subscribe')   { $self->_subscribe        };
         when ('unsubscribe') { $self->_unsubscribe      };
         when ('help')        { $self->_help             };
         default {
            $self->render(text => 'commands: status|request [status] [reason]|ontap|subscribe|unsubscribe|help', status => 400);
         };
      }
   } catch {
      $self->render(text => $_, status => 500);
   };
}


# Get beer30 status and return a string to the caller. Repsonse will be
# diplayed to user as a private Slackbot message.
sub _status {
   my $self = shift;

   my $tx = $ua->get($self->config->{beer30_status_url});
   if (my $err = $tx->error) { die "failed to access Beer30 API: $err->{message}\n" };
   my $beerstatus = $tx->res->json;

   $self->render(text => "$beerstatus->{statusType}: $beerstatus->{description}");
}

sub _request {
   my ($self, $args) = @_;
   my $channel_name = $self->req->param('channel_name');
   my $channel_id   = $self->req->param('channel_id');
   my $user_name    = $self->req->param('user_name');
   my $user_id      = $self->req->param('user_id');
   my $api_user     = $self->config->{beer30_api_user};
   my $api_pass     = $self->config->{beer30_api_password};

   my ($status, $reason) = split ' ', $args, 2;
   $status = uc $status;

   die "a status must be supplied\n" unless ($status);
   die "status must be either STOP, CAUTION, or GO\n" unless ($status =~ /^(STOP|CAUTION|GO)$/);
   die "a reason must be supplied\n" unless ($reason);

   my $annotated_reason = "[Beer30 Bot] User $user_name via Slack channel $channel_name has requested a status change. Reason: $reason";

   my $tx = $ua->post($self->config->{beer30_request_url} => json => {
      userName   => $api_user,
      password   => $api_pass,
      statusType => $status,
      reason     => $annotated_reason
   });
   if (my $err = $tx->error) {
      die "could not post to Beer30 API: $err->{message}\n";
   }

   $tx = $ua->post($self->config->{webhook_url} => json => {
      channel     => $channel_id,
      username    => 'Beer30 Bot',
      icon_emoji  => ':beer:',
      attachments => [{
         fallback  => "<\@$user_id> has requested Beer30 status be changed to $status. Reason: $reason",
         title     => 'Status Change Requested!',
         text      => "Beer30 status change request for $status has been submitted.",
         mrkdwn_in => ['text'],
         fields    => [{
            title => 'Requested By',
            value => "<\@$user_id>",
            short => true
         },{
            title => 'Reason',
            value => $reason,
            short => true

         }]
      }]
   });
   if (my $err = $tx->error) {
      die "could not post to slack: $err->{message}\n";
   }

   $self->render(text => '');
}


# Get the current beers on tap. Is this exposed in the API?
sub _ontap {
   my $self    = shift;
   my $channel = $self->req->param('channel_id');
   my $user    = $self->req->param('user_id');

   my $tx = $ua->get($self->config->{beer30_tap_url});
   if (my $err = $tx->error) { die "failed to access Beer30 API: $err->{message}\n" };
   my $tapdata = $tx->res->json;

   # generate attachments list
   my $attachments = [];
   foreach my $beer (@$tapdata) {
      push @$attachments, {
         fallback   => "$beer->{beerName}" . ($beer->{dry} == true ? ' (dry)' : ''),
         title      => "$beer->{beerName}" . ($beer->{dry} == true ? ' (dry)' : ''),
         title_link => "$beer->{beerAdvocateURL}",
         color      => $beer->{dry} == true ? 'danger' : 'good',
         thumb_url  => 'http://cdn.beeradvocate.com/im/beers' . substr($beer->{beerAdvocateURL}, rindex($beer->{beerAdvocateURL}, '/')) . '.jpg',
         fields     => [{
            title => 'Brewery',
            value => "$beer->{brewery}",
            short => true
         },{
            title => 'Style',
            value => "$beer->{style}",
            short => true
         }]
      };
   }

   # send tap info to channel
   $tx = $ua->post($self->config->{webhook_url} => json => {
      channel     => $channel,
      username    => 'Beer30 Bot',
      icon_emoji  => ':beer:',
      text        => "As requested by <\@$user>, the following beers are currently on tap:",
      attachments => $attachments
   });
   if (my $err = $tx->error) {
      die "could not post to slack: $err->{message}\n";
   }

   $self->render(text => '');
}


# subscribe the channel to beer30 updates
sub _subscribe {
   my $self    = shift;
   my $channel = $self->req->param('channel_id');
   my $user    = $self->req->param('user_id');

   if ($self->req->param('channel_name') eq 'directmessage') {
      die "only channels can subscribe to Beer30 updates\n";
   }

   my $subscription = $self->db->resultset('Beer30Subscription')->find_or_new(channel => $channel);
   if ($subscription->in_storage) {
      die(($channel =~ /^G/ ? 'this group' : "<#$channel>") . " is already subscribed to Beer30 updates\n");
   }

   $subscription->insert;

   # notify channel of subscription
   my $tx = $ua->post($self->config->{webhook_url} => json => {
      channel     => $subscription->channel,
      username    => 'Beer30 Bot',
      icon_emoji  => ':beer:',
      attachments => [{
         fallback  => "<\@$user> subscribed <#$channel> to Beer30 updates",
         color     => 'good',
         title     => ($channel =~ /^G/ ? 'Group' : 'Channel') . ' subscribed!',
         text      => ($channel =~ /^G/ ? 'This group' : "<#$channel>") . ' is now subscribed to Beer30 updates. To unsubscribe, type `/beer30 unsubscribe`.',
         mrkdwn_in => ['text'],
         fields    => [{
            title => 'Requested By',
            value => "<\@$user>",
            short => true
         }]
      }]
   });
   if (my $err = $tx->error) {
      die "could not post to slack: $err->{message}\n";
   }

   $self->render(text => '');
}


# unsubscribe the channel from beer30 updates
sub _unsubscribe {
   my $self    = shift;
   my $channel = $self->req->param('channel_id');
   my $user    = $self->req->param('user_id');

   if ($self->req->param('channel_name') eq 'directmessage') {
      die "only channels can unsubscribe from Beer30 updates\n";
   }

   my $subscription = $self->db->resultset('Beer30Subscription')->find_or_new(channel => $channel);
   unless ($subscription->in_storage) {
      die(($channel =~ /^G/ ? 'this group' : "<#$channel>") . " is not subscribed to Beer30 updates\n");
   }

   $subscription->delete;

   # notify channel of unsubscription
   my $tx = $ua->post($self->config->{webhook_url} => json => {
      channel     => $subscription->channel,
      username    => 'Beer30 Bot',
      icon_emoji  => ':beer:',
      attachments => [{
         fallback  => "<\@$user> unsubscribed <#$channel> from Beer30 updates",
         color     => 'danger',
         title     => ($channel =~ /^G/ ? 'Group' : 'Channel') . ' unsubscribed!',
         text      => ($channel =~ /^G/ ? 'This group' : "<#$channel>") . ' is now unsubscribed from Beer30 updates. To re-subscribe, type `/beer30 subscribe`.',
         mrkdwn_in => ['text'],
         fields    => [{
            title => 'Requested By',
            value => "<\@$user>",
            short => true
         }]
      }]
   });
   if (my $err = $tx->error) {
      die "could not post to slack: $err->{message}\n";
   }

   $self->render(text => '');
}

sub _help {
   shift->render(text =>
      "*Available commands:* `status, ontap, subscribe, unsubscribe`\n" .
      "Maintained by <\@cullum>\n" .
      "Contribute on <https://github.com/cullum/sparcbot|GitHub>!"
   );
}

1;
