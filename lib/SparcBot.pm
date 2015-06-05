package SparcBot;
use Mojo::Base 'Mojolicious';
use Mojo::Home;
use Mojo::IOLoop;
use SparcBot::DB::Schema;

has home => sub {
   return Mojo::Home->new->detect;
};

has db => sub {
   my $schema = SparcBot::DB::Schema->connect(
      'dbi:SQLite:dbname=' . shift->config->{dbfile},
      '',
      '',
      { sqlite_unicode => 1, RaiseError => 1 }
   ) or die "failed to connect to database\n";
   return $schema;
};

sub load_config {
   my $self = shift;

   my $configfile = $self->home->rel_file('../config/config.pl');
   unless (-r $configfile) { die "failed to read config file $configfile\n" };

   $self->plugin(Config => {
      file => $configfile,
      default => {
         dbfile               => $self->home->rel_file('../config/sparcbot.db'),
         beer30_poll_interval => 60,
         beer30_status_url    => 'https://beer30.sparcedge.com/status',
         beer30_tap_url       => 'https://beer30.sparcedge.com/tap'
      }
   });

   foreach my $key (qw/webhook_url slack_token/) {
      unless ($self->config->{$key}) { die "$key missing from config file\n" };
   }
}

sub startup {
   my $self = shift;

   $self->load_config;

   $self->helper(db => sub { shift->app->db });

   # enable channel notifications for beer30 updates
   my $interval = $self->config->{beer30_poll_interval};
   $self->plugin('SparcBot::Plugin::Beer30');
   Mojo::IOLoop->recurring($interval => $self->beer30->poll_and_notify);

   my $r = $self->routes;

   my $if_authed = $r->under('/' => sub {
      my $c = shift;
      return 1 if $c->param('token') eq $self->config->{slack_token};
      $c->render(text => 'not authorized', status => 401);
      return undef;
   });

   $if_authed->post('/beer30')->to('beer30#dispatch');

   $if_authed->any('*' => sub {
      shift->render(text => 'not found', status => 404);
   });
}

1;
