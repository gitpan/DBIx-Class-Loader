package DBIx::Class::Loader::Pg;

use strict;
use base 'DBIx::Class::Loader::Generic';
use DBI;
use Carp;

our $SCHEMA = 'public';

=head1 NAME

DBIx::Class::Loader::Pg - DBIx::Class::Loader Postgres Implementation.

=head1 SYNOPSIS

  use DBIx::Class::Loader;

  # $loader is a DBIx::Class::Loader::Pg
  my $loader = DBIx::Class::Loader->new(
    dsn       => "dbi:Pg:dbname=dbname",
    user      => "postgres",
    password  => "",
    namespace => "Data",
  );
  my $class = $loader->find_class('film'); # $class => Data::Film
  my $obj = $class->retrieve(1);

=head1 DESCRIPTION

See L<DBIx::Class::Loader>.

=cut

sub _db_classes {
    return qw/DBIx::Class::PK::Auto::Pg/;
}

sub _tables {
    my $self = shift;
    my $dbh = DBI->connect( @{ $self->{_datasource} } ) or croak($DBI::errstr);
    my @tables;
    if ( $DBD::Pg::VERSION >= 1.31 ) {
        return $dbh->tables( undef, $SCHEMA, "", "table",
            { noprefix => 1, pg_noprefix => 1 } );
    }
    else { return $dbh->tables }
}

sub _table_info {
    my ( $self, $table ) = @_;
    my $dbh = DBI->connect( @{ $self->{_datasource} } ) or croak($DBI::errstr);
    my $catalog = "";
    if ( $self->_pg_version($dbh) >= 7.3 ) {
        $catalog = 'pg_catalog.';
    }

    # find primary key
    my $sth = $dbh->prepare(<<"SQL");
SELECT indkey FROM ${catalog}pg_index
WHERE indisprimary=true AND indrelid=(
SELECT oid FROM ${catalog}pg_class
WHERE relname = ?)
SQL
    $sth->execute($table);
    my %prinum = map { $_ => 1 } split ' ', $sth->fetchrow_array;
    $sth->finish;

    # find all columns
    $sth = $dbh->prepare(<<"SQL");
SELECT a.attname, a.attnum
FROM ${catalog}pg_class c, ${catalog}pg_attribute a
WHERE c.relname = ?
  AND a.attnum > 0 AND a.attrelid = c.oid
ORDER BY a.attnum
SQL
    $sth->execute($table);
    my $columns = $sth->fetchall_arrayref;
    $sth->finish;

    my ( @cols, @primary );
    foreach my $col (@$columns) {

        # skip dropped column.
        next if $col->[0] =~ /^\.+pg\.dropped\.\d+\.+$/;
        push @cols, $col->[0];
        next unless $prinum{ $col->[1] };
        push @primary, $col->[0];
    }
    _croak("$table has no primary key") unless @primary;
    return ( \@cols, \@primary );
}

sub _pg_version {
    my $class = shift;
    my $dbh   = shift;
    my $sth   = $dbh->prepare("SELECT version()");
    $sth->execute;
    my ($ver_str) = $sth->fetchrow_array;
    $sth->finish;
    my ($ver) = $ver_str =~ m/^PostgreSQL ([\d\.]{3})/;
    return $ver;
}

=head1 SEE ALSO

L<DBIx::Class::Loader>

=cut

1;
