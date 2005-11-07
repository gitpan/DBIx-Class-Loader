package DBIx::Class::Loader::Generic;

use strict;
use base 'DBIx::Class::Componentised';
use Carp;
use Lingua::EN::Inflect;
use UNIVERSAL::require;
require DBIx::Class::DB;
require DBIx::Class::Core;

=head1 NAME

DBIx::Class::Loader::Generic - Generic DBIx::Class::Loader Implementation.

=head1 SYNOPSIS

See L<DBIx::Class::Loader>

=head1 DESCRIPTION

=head2 OPTIONS

Available constructor options are:

=head3 additional_base_classes

List of additional base classes your table classes will use.

=head3 left_base_classes

List of additional base classes, that need to be leftmost.

=head3 additional_classes

List of additional classes which your table classes will use.

=head3 constraint

Only load tables matching regex.

=head3 exclude

Exclude tables matching regex.

=head3 debug

Enable debug messages.

=head3 dsn

DBI Data Source Name.

=head3 namespace

Namespace under which your table classes will be initialized.

=head3 password

Password.

=head3 relationships

Try to automatically detect/setup has_a and has_many relationships.

=head3 inflect

An hashref, which contains exceptions to Lingua::EN::Inflect::PL().
Useful for foreign language column names.

=head3 user

Username.

=head2 METHODS

=cut

sub new {
    my ( $class, %args ) = @_;
    if ( $args{debug} ) {
        no strict 'refs';
        *{"$class\::debug"} = sub { 1 };
    }
    my $additional = $args{additional_classes} || [];
    $additional = [$additional] unless ref $additional eq 'ARRAY';
    my $additional_base = $args{additional_base_classes} || [];
    $additional_base = [$additional_base]
      unless ref $additional_base eq 'ARRAY';
    my $left_base = $args{left_base_classes} || [];
    $left_base = [$left_base] unless ref $left_base eq 'ARRAY';
    my $self = bless {
        _datasource =>
          [ $args{dsn}, $args{user}, $args{password}, $args{options} ],
        _namespace       => $args{namespace},
        _additional      => $additional,
        _additional_base => $additional_base,
        _left_base       => $left_base,
        _constraint      => $args{constraint} || '.*',
        _exclude         => $args{exclude},
        _relationships   => $args{relationships},
        _inflect         => $args{inflect},
        CLASSES          => {},
    }, $class;
    warn qq/\### START DBIx::Class::Loader dump ###\n/ if $self->debug;
    $self->_load_classes;
    $self->_relationships                            if $self->{_relationships};
    warn qq/\### END DBIx::Class::Loader dump ###\n/ if $self->debug;
    $self;
}

=head3 find_class

Returns a tables class.

    my $class = $loader->find_class($table);

=cut

sub find_class {
    my ( $self, $table ) = @_;
    return $self->{CLASSES}->{$table};
}

=head3 classes

Returns a sorted list of classes.

    my $@classes = $loader->classes;

=cut

sub classes {
    my $self = shift;
    return sort values %{ $self->{CLASSES} };
}

=head3 debug

Overload to enable debug messages.

=cut

sub debug { 0 }

=head3 tables

Returns a sorted list of tables.

    my @tables = $loader->tables;

=cut

sub tables {
    my $self = shift;
    return sort keys %{ $self->{CLASSES} };
}

# Overload in your driver class
sub _db_classes { croak "ABSTRACT METHOD" }

# Setup has_a and has_many relationships
sub _belongs_to_many {
    my ( $self, $table, $column, $other ) = @_;
    my $table_class = $self->find_class($table);
    my $other_class = $self->find_class($other);
    warn qq/\# Belongs_to relationship\n/ if $self->debug;
    warn qq/$table_class->belongs_to( '$column' => '$other_class' );\n\n/
      if $self->debug;
    $table_class->belongs_to( $column => $other_class );
    my ($table_class_base) = $table_class =~ /.*::(.+)/;
    my $plural = Lingua::EN::Inflect::PL( lc $table_class_base );
    $plural = $self->{_inflect}->{ lc $table_class_base }
      if $self->{_inflect}
      and exists $self->{_inflect}->{ lc $table_class_base };
    warn qq/\# Has_many relationship\n/ if $self->debug;
    warn
      qq/$other_class->has_many( '$plural' => '$table_class', '$column' );\n\n/
      if $self->debug;
    $other_class->has_many( $plural => $table_class, $column );
}

# Load and setup classes
sub _load_classes {
    my $self            = shift;
    my @tables          = $self->_tables();
    my @db_classes      = $self->_db_classes();
    my $additional      = join '', map "use $_;\n", @{ $self->{_additional} };
    my $additional_base = join '', map "use base '$_';\n",
      @{ $self->{_additional_base} };
    my $left_base  = join '', map "use base '$_';\n", @{ $self->{_left_base} };
    my $constraint = $self->{_constraint};
    my $exclude    = $self->{_exclude};

    my $namespace = $self->{_namespace};
    my $dbclass   = "$namespace\::_db";
    $self->inject_base( $dbclass, 'DBIx::Class::DB' );
    $dbclass->connection( @{ $self->{_datasource} } );

    foreach my $table (@tables) {
        next unless $table =~ /$constraint/;
        next if ( defined $exclude && $table =~ /$exclude/ );
        my $class = $self->_table2class($table);
        $self->inject_base( $class, $dbclass, 'DBIx::Class::Core' );
        $_->require for @db_classes;
        $self->inject_base( $class, $_ ) for @db_classes;
        warn qq/\# Initializing table "$table" as "$class"\n/ if $self->debug;
        $class->table($table);
        my ( $cols, $pks ) = $self->_table_info($table);
        $class->add_columns(@$cols);
        $class->set_primary_key(@$pks);
        $self->{CLASSES}->{$table} = $class;
        my $code = "package $class;\n$additional_base$additional$left_base";
        warn qq/$code/                        if $self->debug;
        warn qq/$class->table('$table');\n/ if $self->debug;
        my $columns = join "', '", @$cols;
        warn qq/$class->add_columns('$columns')\n/ if $self->debug;
        my $primaries = join "', '", @$pks;
        warn qq/$class->set_primary_key('$primaries')\n/ if $self->debug;
        eval $code;
        croak qq/Couldn't load additional classes "$@"/ if $@;
        unshift @{"$class\::ISA"}, $_ foreach ( @{ $self->{_left_base} } );
    }
}

# Find and setup relationships
sub _relationships {
    my $self = shift;
    foreach my $table ( $self->tables ) {
        my $dbh = $self->find_class($table)->storage->dbh;
        if ( my $sth = $dbh->foreign_key_info( '', '', '', '', '', $table ) ) {
            for my $res ( @{ $sth->fetchall_arrayref( {} ) } ) {
                my $column = $res->{FK_COLUMN_NAME};
                my $other  = $res->{UK_TABLE_NAME};
                $column =~ s/"//g;
                $other =~ s/"//g;
                eval { $self->_belongs_to_many( $table, $column, $other ) };
                warn qq/\# belongs_to_many failed "$@"\n\n/
                  if $@ && $self->debug;
            }
        }
    }
}

# Make a class from a table
sub _table2class {
    my ( $self, $table ) = @_;
    my $namespace = $self->{_namespace} || "";
    $namespace =~ s/(.*)::$/$1/;
    my $subclass = join '', map ucfirst, split /[\W_]+/, $table;
    my $class = $namespace ? "$namespace\::" . $subclass : $subclass;
}

# Overload in driver class
sub _tables { croak "ABSTRACT METHOD" }

sub _table_info { croak "ABSTRACT METHOD" }

=head1 SEE ALSO

L<DBIx::Class::Loader>

=cut

1;
