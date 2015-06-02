SparcBot
===============

Required Perl Modules
----------------------
  * Mojolicious
  * IO::Socket::SSL
  * Try::Tiny

Configuration
----------------------
Copy `script/config.sample.pl` to `script/config.pl` and edit the new file. At
the very least, you'll need to provide the authentication token of your Slack
integration and the URL of your Slack web hook.

Running the Server
----------------------
In the parent folder of the project, run `./script/sparcbot daemon -l http://0.0.0.0:3000 -m production`
