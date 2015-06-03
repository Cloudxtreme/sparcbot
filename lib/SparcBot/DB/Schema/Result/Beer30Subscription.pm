use utf8;
package SparcBot::DB::Schema::Result::Beer30Subscription;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table("Beer30Subscription");
__PACKAGE__->add_columns("channel", { data_type => "text", is_nullable => 0 });
__PACKAGE__->set_primary_key("channel");


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-06-02 20:19:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:v8wDq/fF7kH8ttc1d15Qcg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
