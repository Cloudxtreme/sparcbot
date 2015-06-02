package SparcBot;
use Mojo::Base 'Mojolicious';
use Mojo::Home;

has home => sub {
   return Mojo::Home->new->detect;
};

sub load_config {
   my $self = shift;

   my $configfile = $self->home->rel_file('config.pl');
   unless (-r $configfile) { die "failed to read config file $configfile\n" };

   $self->plugin(Config => {
      file => $configfile,
      default => {
         beer30_url => 'https://beer30.sparcedge.com/status'
      }
   });

   unless ($self->config->{webhook_url})   { die "webhook_url missing from config file\n" };
   unless ($self->config->{slack_token})   { die "slack_token missing from config file\n" };
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
