use strict;
use Test::More;

BEGIN {
    plan tests => 11;
}

use DBIx::Class::Loader;
use DBI;

eval { require DBD::SQLite };
my $class = $@ ? 'SQLite2' : 'SQLite';

my $dbh;
my $database = './t/sqlite_test';

my $dsn = "dbi:$class:dbname=$database";
$dbh = DBI->connect(
    $dsn, "", "",
    {
        RaiseError => 1,
        PrintError => 1,
        AutoCommit => 1
    }
);

$dbh->do(<<'SQL');
CREATE TABLE loader_test1 (
    id INTEGER NOT NULL PRIMARY KEY ,
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
    id INTEGER NOT NULL PRIMARY KEY,
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

$dbh->do(<<'SQL');
CREATE TABLE loader_test3 (
    id1 INTEGER,
    id2 INTEGER, --, id2 INTEGER REFERENCES loader_test1,
    dat TEXT,
    PRIMARY KEY (id1,id2)
)
SQL

$dbh->do("INSERT INTO loader_test3 (id1,id2,dat) VALUES (1,1,'aaa')");

$dbh->do(<<'SQL');
CREATE TABLE loader_test4 (
    id INTEGER NOT NULL PRIMARY KEY,
    id2 INTEGER,
    loader_test2 INTEGER REFERENCES loader_test2,
    dat TEXT,
    FOREIGN KEY (id, id2 ) REFERENCES loader_test3 (id1,id2)
)
SQL

$dbh->do("INSERT INTO loader_test4 (id2,loader_test2,dat) VALUES (1,1,'aaa')");

my $loader = DBIx::Class::Loader->new(
    dsn           => $dsn,
    namespace     => 'SQLiteTest',
    constraint    => '^loader_test.*',
    relationships => 1,
);

is( $loader->find_class("loader_test1"), "SQLiteTest::LoaderTest1" );
is( $loader->find_class("loader_test2"), "SQLiteTest::LoaderTest2" );
is( $loader->find_class("loader_test3"), "SQLiteTest::LoaderTest3" );
is( $loader->find_class("loader_test4"), "SQLiteTest::LoaderTest4" );

my $class1 = $loader->find_class("loader_test1");
my $obj    = $class1->find(1);
is( $obj->id,  1 );
is( $obj->dat, "foo" );
my $class2 = $loader->find_class("loader_test2");
is( $class2->count, 4 );
my ($obj2) = $class2->search( dat => 'bbb' );
is( $obj2->id, 2 );
my $class3 = $loader->find_class("loader_test3");
my $obj3 = $class3->find( id1 => 1, id2 => 1 );
is( ref( $obj3->id2 ), '' );    # fk def in comments should not be parsed
my $class4 = $loader->find_class("loader_test4");
my $obj4   = $class4->find(1);
is( $obj4->loader_test2->isa('SQLiteTest::LoaderTest2'), 1 );
is( ref( $obj4->id2 ), '' );    # mulit-col fk def should not be parsed

for ( $class1, $class2, $class3, $class4 ) {
    $_->storage->dbh->disconnect;
}

END {
    unlink './t/sqlite_test';
}
