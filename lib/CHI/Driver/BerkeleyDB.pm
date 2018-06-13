# COPYRIGHT

package CHI::Driver::BerkeleyDB;

# ABSTRACT: BerkeleyDB Cache Driver for CHI

use strict;
use warnings;
use BerkeleyDB 0.30;
use CHI::Util 0.25 qw(read_dir);
use File::Path qw(mkpath);
use Moose;

extends 'CHI::Driver';

has db => (is => 'ro', lazy_build => 1);

has db_class => (is => 'ro', default => 'BerkeleyDB::Hash');

has dir_create_mode => (is => 'ro', isa => 'Int', default => oct(775));

has env => (is => 'ro', lazy_build => 1);

has filename => (is => 'ro', init_arg => undef, lazy_build => 1);

has root_dir => (is => 'ro');

sub _build_filename {
    my $self = shift;
    return $self->escape_for_filename( $self->namespace ) . ".db";
}

sub _build_env {
    my $self = shift;

    my $root_dir = $self->root_dir;

    unless (defined $root_dir) {
        die "must specify one of env or root_dir";
    }

    unless (-d $root_dir) {
        mkpath( $root_dir, 0, $self->dir_create_mode );
    }

    my $env = BerkeleyDB::Env->new(
        '-Home'   => $self->root_dir,
        '-Config' => {},
        '-Flags'  => DB_CREATE | DB_INIT_CDB | DB_INIT_MPOOL)
      or die sprintf( "cannot open Berkeley DB environment in '%s': %s",
        $root_dir, $BerkeleyDB::Error );

    return $env;
}

sub _build_db {
    my $self = shift;

    my $filename = $self->filename;
    my $db       = $self->db_class->new(
        '-Filename' => $filename,
        '-Flags'    => DB_CREATE,
        '-Env'      => $self->env)
      or die
      sprintf( "cannot open Berkeley DB file '%s' in environment '%s': %s",
        $filename, $self->root_dir, $BerkeleyDB::Error );

    return $db;
}

sub fetch {
    my ($self, $key) = @_;

    my $data;

    return ( $self->db->db_get( $key, $data ) == 0 ) ? $data : undef;
}

sub store {
    my ($self, $key, $data) = @_;

    $self->db->db_put( $key, $data ) == 0
      or die $BerkeleyDB::Error;
}

sub remove {
    my ($self, $key) = @_;

    $self->db->db_del($key) == 0
      or die $BerkeleyDB::Error;
}

sub clear {
    my $self = shift;

    my $count = 0;
    $self->db->truncate($count) == 0
      or die $BerkeleyDB::Error;
}

sub get_keys {
    my $self = shift;

    my @keys;
    my $cursor = $self->db->db_cursor();
    my ($key, $value) = ('', '');

    while ( $cursor->c_get( $key, $value, BerkeleyDB::DB_NEXT() ) == 0 ) {
        push( @keys, $key );
    }

    return @keys;
}

sub get_namespaces {
    my $self = shift;

    my @contents = read_dir( $self->root_dir );

    my @namespaces =
      map { $self->unescape_for_filename( substr( $_, 0, -3 ) ) }
      grep { /\.db$/ } @contents;

    return @namespaces;
}

__PACKAGE__->meta->make_immutable;

__END__

=pod

=for Pod::Coverage clear fetch get_keys get_namespaces remove store

=head1 SYNOPSIS

 use CHI;

 my $cache = CHI->new(
     driver     => 'BerkeleyDB',
     root_dir   => '/path/to/cache/root'
 );

=head1 DESCRIPTION

This cache driver uses L<Berkeley DB|BerkeleyDB> files to store data. Each
namespace is stored in its own db file.

By default, the driver configures the Berkeley DB environment to use the
Concurrent Data Store (CDS), making it safe for multiple processes to read and
write the cache without explicit locking.

=head1 CONSTRUCTOR OPTIONS

=for :list
* root_dir
Path to the directory that will contain the Berkeley DB environment, also known as the "Home".
* db_class
BerkeleyDB class, defaults to BerkeleyDB::Hash.
* env
Use this Berkeley DB environment instead of creating one.
* db
Use this Berkeley DB object instead of creating one.

=head1 HISTORY

Originally created by Jonathan Swartz.  Version 0.04 and later maintained by
Michael Schout.

=head1 SEE ALSO

=for :list
* L<CHI>
* L<BerkeleyDB>

=cut
