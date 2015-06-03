SparcBot
===============

Installation
----------------------
Make sure you have a non-ancient Perl (I recommend [perlbrew](http://perlbrew.pl)).

Install the necessary dependencies:

`cpanm --notest Mojolicious IO::Socket::SSL Try::Tiny DBI DBIx::Class::Schema::Loader`

Generate the SQLite database:

`./script/generate_db`

Configuration
----------------------
Copy `script/config.sample.pl` to `script/config.pl` and edit the new file. At
the very least, you'll need to provide the authentication token of your Slack
integration and the URL of your Slack web hook.

Running the Server
----------------------
In the parent folder of the project, run `./script/sparcbot daemon -l http://0.0.0.0:3000 -m production`
