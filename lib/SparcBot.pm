package SparcBot;
use Mojo::Base 'Mojolicious';
use Mojo::Home;
use SparcBot::DB::Schema;

has home => sub {
   return Mojo::Home->new->detect;
};

has db => sub {
   my $schema = SparcBot::DB::Schema->connect(
      'dbi:SQLite:dbname=' . shift->config->{dbfile},
      '',
      '',
      { sqlite_unicode => 1 }
   ) or die "failed to connect to database\n";
   return $schema;
};

sub load_config {
   my $self = shift;

   my $configfile = $self->home->rel_file('config.pl');
   unless (-r $configfile) { die "failed to read config file $configfile\n" };

   $self->plugin(Config => {
      file => $configfile,
      default => {
         beer30_url  => 'https://beer30.sparcedge.com/status',
         dbfile      => $self->home->rel_file('sparcbot.db'),
      }
   });

   foreach my $key (qw/webhook_url slack_token/) {
      unless ($self->config->{$key}) { die "$key missing from config file\n" };
   }
}

sub startup {
   my $self = shift;

   $self->load_config;

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
