use strict;
use Test::More tests => 6;

use DBIx::Class::Loader;
use DBI;

my $dbh;
my $database = $ENV{PG_NAME};
my $user     = $ENV{PG_USER};
my $password = $ENV{PG_PASS};

SKIP: {
    skip
      'You need to set the PG_NAME, PG_USER and PG_PASS environment variables',
      6
      unless ( $database && $user );

    my $dsn = "dbi:Pg:dbname=$database";
    $dbh = DBI->connect(
        $dsn, $user,
        $password,
        {
            RaiseError => 1,
            PrintError => 1,
            AutoCommit => 1
        }
    );

    $dbh->do(<<'SQL');
CREATE TABLE loader_test1 (
    id SERIAL NOT NULL PRIMARY KEY ,
    dat TEXT
)
SQL

    my $sth = $dbh->prepare(<<"SQL");
INSERT INTO loader_test1 (dat) VALUES(?)
SQL
    for my $dat (qw(foo bar baz)) {
        $sth->execute($dat);
        $sth->finish;
    }

    $dbh->do(<<'SQL');
CREATE TABLE loader_test2 (
    id SERIAL NOT NULL PRIMARY KEY,
    dat TEXT
)
SQL

    $sth = $dbh->prepare(<<"SQL");
INSERT INTO loader_test2 (dat) VALUES(?)
SQL
    for my $dat (qw(aaa bbb ccc ddd)) {
        $sth->execute($dat);
        $sth->finish;
    }

    my $loader = DBIx::Class::Loader->new(
        dsn        => $dsn,
        user       => $user,
        password   => $password,
        namespace  => 'PgTest',
        constraint => '^loader_test.*'
    );
    is( $loader->find_class("loader_test1"), "PgTest::LoaderTest1" );
    is( $loader->find_class("loader_test2"), "PgTest::LoaderTest2" );
    my $class1 = $loader->find_class("loader_test1");
    my $obj    = $class1->find(1);
    is( $obj->id,  1 );
    is( $obj->dat, "foo" );
    my $class2 = $loader->find_class("loader_test2");
    is( $class2->count, 4 );
    my ($obj2) = $class2->find( dat => 'bbb' );
    is( $obj2->id, 2 );

    $class1->storage->dbh->disconnect;
    $class2->storage->dbh->disconnect;
}

END {
    if ($dbh) {
        $dbh->do("DROP TABLE loader_test1");
        $dbh->do("DROP TABLE loader_test2");
        $dbh->disconnect;
    }
}