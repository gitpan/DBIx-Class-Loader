use strict;
use Test::More tests => 7;

use DBIx::Class::Loader;
use DBI;

my $dbh;
my $database    = $ENV{MYSQL_NAME};
my $user        = $ENV{MYSQL_USER};
my $password    = $ENV{MYSQL_PASS};
my $test_innodb = $ENV{MYSQL_TEST_INNODB};

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

    if($test_innodb) {
        $dbh->do(<<'SQL');
CREATE TABLE loader_test3 (
    id INTEGER NOT NULL PRIMARY KEY,
    dat VARCHAR(32)
)
ENGINE='InnoDB'
SQL

        $sth = $dbh->prepare(<<"SQL");
INSERT INTO loader_test3 (id,dat) VALUES(?,?)
SQL
        my $i = 1;
        for my $dat (qw(aaa bbb ccc ddd)) {
            $sth->execute($i++,$dat);
            $sth->finish;
        }
        $sth->finish;

        $dbh->do(<<'SQL');
CREATE TABLE loader_test4 (
    id INTEGER NOT NULL PRIMARY KEY,
    fkid INTEGER NOT NULL,
    dat VARCHAR(32),
    FOREIGN KEY (fkid) REFERENCES loader_test3 (id)
)
ENGINE='InnoDB'
SQL

        $sth = $dbh->prepare(<<"SQL");
INSERT INTO loader_test4 (id,fkid,dat) VALUES(?,?,?)
SQL
        $i = 1;
        my $j = 123;
        for my $dat (qw(aaa bbb ccc ddd)) {
            $sth->execute($j++,$i++,$dat);
            $sth->finish;
        }
        $sth->finish;
    }

    my $loader = DBIx::Class::Loader->new(
        dsn           => $dsn,
        user          => $user,
        password      => $password,
        constraint    => '^loader_test.+',
        namespace     => 'MysqlTest',
        relationships => 1,
    );
    is( $loader->find_class("loader_test1"), "MysqlTest::LoaderTest1" );
    is( $loader->find_class("loader_test2"), "MysqlTest::LoaderTest2" );
    my $class1 = $loader->find_class("loader_test1");
    my $obj    = $class1->find(1);
    is( $obj->id,  1 );
    is( $obj->dat, "foo" );
    my $class2 = $loader->find_class("loader_test2");
    is( $class2->count, 4 );
    my ($obj2) = $class2->find( dat => 'bbb' );
    is( $obj2->id, 2 );
    SKIP: {
        skip 'You need to set the MYSQL_TEST_INNODB environment variable to test relationships', 1
          unless $test_innodb;

        my $class3 = $loader->find_class("loader_test3");
        my $class4 = $loader->find_class("loader_test4");
        my $obj4 = $class4->find(123);
        is( ref($obj4->fkid), $class3);
    }
}

END {
    if ($dbh) {
        $dbh->do("DROP TABLE loader_test1");
        $dbh->do("DROP TABLE loader_test2");
        if($test_innodb) {
            $dbh->do("DROP TABLE loader_test4");
            $dbh->do("DROP TABLE loader_test3");
        }
        $dbh->disconnect;
    }
}
