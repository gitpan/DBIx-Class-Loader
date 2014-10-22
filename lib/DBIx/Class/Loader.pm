package DBIx::Class::Loader;

use strict;
use UNIVERSAL::require;

our $VERSION = '0.14';

=head1 NAME

DBIx::Class::Loader - Dynamic definition of DBIx::Class sub classes.

=head1 SYNOPSIS

  use DBIx::Class::Loader;

  my $loader = DBIx::Class::Loader->new(
    dsn                     => "dbi:mysql:dbname",
    user                    => "root",
    password                => "",
    namespace               => "Data",
    additional_classes      => [qw/DBIx::Class::Foo/],
    additional_base_classes => [qw/My::Stuff/],
    left_base_classes       => [qw/DBIx::Class::Bar/],
    constraint              => '^foo.*',
    relationships           => 1,
    options                 => { AutoCommit => 1 }, 
    inflect                 => { child => 'children' },
    debug                   => 1,
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

DBIx::Class::Loader automate the definition of DBIx::Class sub-classes by
scanning table schemas and setting up columns and primary keys.

Class names are defined by table names and the namespace option, which is
required.

 +---------+-----------+--------------+
 | table   | namespace | class        |
 +---------+-----------+--------------+
 | foo     | Data      | Data::Foo    |
 | foo_bar | MyDB      | MyDB::FooBar |
 +---------+-----------+--------------+

DBIx::Class::Loader supports MySQL, Postgres, SQLite and DB2.  See
L<DBIx::Class::Loader::Generic> for more, and L<DBIx::Class::Loader::Writing>
for notes on writing your own db-specific subclass for an unsupported db.

L<Class::DBI::Loader> and L<Class::DBI> are now obsolete, use L<DBIx::Class> and this module instead. ;)

=cut

=head1 METHODS

=head2 new

Example in Synopsis above demonstrates the available arguments.  For
detailed information on the arguments, see the
L<DBIx::Class::Loader::Generic> documentation.

=cut

sub new {
    my ( $class, %args ) = @_;
    my $dsn = $args{dsn};
    my ($driver) = $dsn =~ m/^dbi:(\w*?)(?:\((.*?)\))?:/i;
    $driver = 'SQLite' if $driver eq 'SQLite2';
    my $impl = "DBIx::Class::Loader::" . $driver;
    $impl->require or
    die qq/Couldn't require loader class "$impl", "$UNIVERSAL::require::ERROR"/;
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
