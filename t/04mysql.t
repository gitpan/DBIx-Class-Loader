use strict;
use Test::More tests => 6;

use DBIx::Class::Loader;

my $dbh;
my $database = $ENV{MYSQL_NAME};
my $user     = $ENV{MYSQL_USER};
my $password = $ENV{MYSQL_PASS};

SKIP: {
    skip
'You need to set the MYSQL_NAME, MYSQL_USER and MYSQL_PASS environment variables',
      6
      unless ( $database && $user );

    my $dsn = "dbi:mysql:$database";
    $dbh = DBI->connect(
        $dsn, $user,
        $password,
        {
            RaiseError => 1,
            PrintError => 1
        }
    );

    $dbh->do(<<'SQL');
CREATE TABLE loader_test1 (
    id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    dat VARCHAR(32)
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
    id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    dat VARCHAR(32)
)
SQL

    $sth = $dbh->prepare(<<"SQL");
INSERT INTO loader_test2 (dat) VALUES(?)
SQL
    for my $dat (qw(aaa bbb ccc ddd)) {
        $sth->execute($dat);
        $sth->finish;
    }
    $sth->finish;

    my $loader = DBIx::Class::Loader->new(
        dsn        => $dsn,
        user       => $user,
        password   => $password,
        constraint => '^loader_test.+'
    );
    is( $loader->find_class("loader_test1"), "LoaderTest1" );
    is( $loader->find_class("loader_test2"), "LoaderTest2" );
    my $class1 = $loader->find_class("loader_test1");
    my $obj    = $class1->find(1);
    is( $obj->id,  1 );
    is( $obj->dat, "foo" );
    my $class2 = $loader->find_class("loader_test2");
    is( $class2->count, 4 );
    my ($obj2) = $class2->find( dat => 'bbb' );
    is( $obj2->id, 2 );
}

END {
    if ($dbh) {
        $dbh->do("DROP TABLE loader_test1");
        $dbh->do("DROP TABLE loader_test2");
        $dbh->disconnect;
    }
}
