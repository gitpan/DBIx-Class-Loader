package DBIx::Class::Loader::mysql;

use strict;
use base 'DBIx::Class::Loader::Generic';
use DBI;
use Carp;

=head1 NAME

DBIx::Class::Loader::mysql - DBIx::Class::Loader mysql Implementation.

=head1 SYNOPSIS

  use DBIx::Class::Loader;

  # $loader is a DBIx::Class::Loader::mysql
  my $loader = DBIx::Class::Loader->new(
    dsn       => "dbi:mysql:dbname",
    user      => "root",
    password  => "",
    namespace => "Data",
  );
  my $class = $loader->find_class('film'); # $class => Data::Film
  my $obj = $class->retrieve(1);

=head1 DESCRIPTION

See L<DBIx::Class::Loader>.

=cut

sub _db_classes {
    return qw/DBIx::Class::PK::Auto::MySQL/;
}

# Very experimental and untested!
sub _relationships {
    my $self   = shift;
    my @tables = $self->tables;
    my $dbh    = $self->find_class( $tables[0] )->storage->dbh;
    my $dsn    = $self->{_datasource}[0];
    my %conn   =
      $dsn =~ m/\Adbi:\w+(?:\(.*?\))?:(.+)\z/i
      && index( $1, '=' ) >= 0
      ? split( /[=;]/, $1 )
      : ( database => $1 );
    my $dbname = $conn{database} || $conn{dbname} || $conn{db};
    die("Can't figure out the table name automatically.") if !$dbname;
    my $quoter = $dbh->get_info(29);

    foreach my $table (@tables) {
        my $query = "SHOW TABLE STATUS FROM $dbname LIKE '$table'";
        my $sth   = $dbh->prepare($query)
          or die("Cannot get table status: $table");
        $sth->execute;
        my $comment = $sth->fetchrow_hashref->{comment};
        $comment =~ s/$quoter//g if ($quoter);
        while ( $comment =~ m!\(`?(\w+)`?\)\sREFER\s`?\w+/(\w+)`?\(`?\w+`?\)!g )
        {
            eval { $self->_belongs_to_many( $table, $1, $2 ) };
            warn qq/\# belongs_to_many failed "$@"\n\n/ if $@ && $self->debug;
        }
        $sth->finish;
    }
}

sub _tables {
    my $self = shift;
    my $dbh = DBI->connect( @{ $self->{_datasource} } ) or croak($DBI::errstr);
    my @tables;
    foreach my $table ( $dbh->tables ) {
        my $quoter = $dbh->get_info(29);
        $table =~ s/$quoter//g if ($quoter);
        push @tables, $1
          if $table =~ /\A(\w+)\z/;
    }
    $dbh->disconnect;
    return @tables;
}

sub _table_info {
    my ( $self, $table ) = @_;
    my $dbh = DBI->connect( @{ $self->{_datasource} } ) or croak($DBI::errstr);
    my $query = "DESCRIBE '$table'";
    my $sth = $dbh->prepare($query) or die("Cannot get table status: $table");
    $sth->execute;
    my ( @cols, @pri );
    while ( my $hash = $sth->fetch_hash ) {
        my ($col) = $hash->{field} =~ /(\w+)/;
        push @cols, $col;
        push @pri, $col if $hash->{key} eq "PRI";
    }
    $self->_croak("$table has no primary key") unless @pri;
    return ( \@cols, \@pri );
}

=head1 SEE ALSO

L<DBIx::Class::Loader>

=cut

1;