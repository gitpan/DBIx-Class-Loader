package DBIx::Class::Loader;

use strict;

our $VERSION = '0.04';

=head1 NAME

DBIx::Class::Loader - Dynamic definition of DBIx::Class sub classes.

=head1 SYNOPSIS

  use DBIx::Class::Loader;

  my $loader = DBIx::Class::Loader->new(
    dsn                     => "dbi:mysql:dbname",
    user                    => "root",
    password                => "",
    namespace               => "Data",
    additional_classes      => qw/DBIx::Class::Foo/,
    additional_base_classes => qw/My::Stuff/,
    left_base_classes       => qw/DBIx::Class::Bar/,
    constraint              => '^foo.*',
    relationships           => 1,
    options                 => { AutoCommit => 1 }, 
    inflect                 => { child => 'children' }
  );
  my $class = $loader->find_class('film'); # $class => Data::Film
  my $obj = $class->find(1);

use with mod_perl

in your startup.pl

  # load all tables
  use DBIx::Class::Loader;
  my $loader = DBIx::Class::Loader->new(
    dsn       => "dbi:mysql:dbname",
    user      => "root",
    password  => "",
    namespace => "Data",
  );

in your web application.

  use strict;

  # you can use Data::Film directly
  my $film = Data::Film->retrieve($id);


=head1 DESCRIPTION

DBIx::Class::Loader automate the definition of DBIx::Class sub-classes.
scan table schemas and setup columns, primary key.

class names are defined by table names and namespace option.

 +-----------+-----------+-----------+
 |   table   | namespace | class     |
 +-----------+-----------+-----------+
 |   foo     | Data      | Data::Foo |
 |   foo_bar |           | FooBar    |
 +-----------+-----------+-----------+

DBIx::Class::Loader supports MySQL, Postgres and SQLite.

See L<DBIx::Class::Loader::Generic> for more, and
L<DBIx::Class::Loader::Writing> for notes on writing your own db-specific
subclass for an unsupported db.

L<Class::DBI::Loader> and L<Class::DBI> are now obsolete, use L<DBIx::Class> and this module instead. ;)

=cut

sub new {
    my ( $class, %args ) = @_;
    my $dsn = $args{dsn};
    my ($driver) = $dsn =~ m/^dbi:(\w*?)(?:\((.*?)\))?:/i;
    $driver = 'SQLite' if $driver eq 'SQLite2';
    my $impl = "DBIx::Class::Loader::" . $driver;
    eval qq/use $impl/;
    die qq/Couldn't require loader class "$impl", "$@"/ if $@;
    return $impl->new(%args);
}

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

Based upon the work of IKEBE Tomohiro

=head1 THANK YOU

Adam Anderson, Andy Grundman, Autrijus Tang, Dan Kubb, David Naughton,
Randal Schwartz, Simon Flack and all the others who've helped.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<DBIx::Class>

=cut

1;
