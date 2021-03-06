#!/usr/bin/env perl

use strict;
use warnings;

use File::Spec;
use Storable;
use Module::Build;
use Pod::Man;

my $lib_ocf_root = '/usr/lib/ocf';
my $ocft_confs   = '/usr/share/resource-agents/ocft/configs';
my $lib_ocf_dirs;
my $man7_dir;
my $ocf_dirs;
my %ocf_dirs;

my $build = Module::Build->new(
    module_name => 'PAF',
    license     => 'bsd',
    requires    => {
        'perl'        => '5.8.0'
    },
    create_packlist    => 1,
    #create_readme      => 1,
    create_makefile_pl => 'traditional',
    dist_version       => '2.2_rc1',
    release_status     => 'testing', # stable or testing
    dist_abstract      => 'PostgreSQL multistate OCF resource agent for Pacemaker',
    dist_author        => [
        'Mael Rimbault <mael.rimbault@dalibo.com>',
        'Jehan-Guillaume <jgdr@dalibo.com>'
    ],
    script_files       => [ 'script/pgsqlms' ],
    PL_files           => {
        'lib/OCF_Directories.pm.PL' => 'lib/OCF_Directories.pm'
    },
    tests_files        => {
        't/pgsqlms' => 'tests/pgsqlms'
    },
    man7_files         => {
        'ocf_heartbeat_pgsqlms.7' => 'man7/ocf_heartbeat_pgsqlms.7'
    },
    get_options        => {
        with_ocf_root   => {
            type  => '=s',
            store => \$lib_ocf_root
        },
        with_ocft_confs => {
            type  => '=s',
            store => \$ocft_confs
        }
    },
    add_to_cleanup     => [
        'lib/OCF_Directories.pm',
        'ocf_heartbeat_pgsqlms.7'
    ],
    meta_merge         => {
        resources => {
            'homepage'   => 'http://dalibo.github.io/PAF/',
            'repository' => 'https://github.com/dalibo/PAF',
            'bugtracker' => 'https://github.com/dalibo/PAF/issues'
        }
  },
);

# The pgsqlms man page must be generated in man7, not man1.
# We create a new man7 install path, and disable the man1 generation.

# build man7 page
Pod::Man->new(
    'release' => $build->dist_version,
    'section' => 7,
    'center'  => 'OCF resource agents',
    'name'    => 'OCF_HEARTBEAT_PGSQLMS'
)->parse_from_file( 'script/pgsqlms', 'ocf_heartbeat_pgsqlms.7' );

$man7_dir = $build->install_destination( 'bindoc' );
$man7_dir =~ s@man1@man7@;

$build->install_path( 'man7' => $man7_dir );
$build->add_build_element('man7');

# we set the bindoc dirs list to an empty list so Module::Build can not find
# script/pgsqlms and create a man1 page
$build->bindoc_dirs( [] );


# Check given ocf_root or default values
for my $dir (
    $lib_ocf_root, '/usr/lib/ocf', '/usr/lib32/ocf', '/usr/lib64/ocf'
) {
    if ( -d $dir and -s "$dir/lib/heartbeat/ocf-directories" ) {
        print STDERR "Found OCF_ROOT: $dir\n";
        $lib_ocf_root = $dir;
        last;
    }
}

$lib_ocf_dirs = "$lib_ocf_root/lib/heartbeat/ocf-directories";

die "Couldn't find OCF shell functions in «OCF_ROOT/lib/heartbeat»!\n"
    ."Try to build using the --with_ocf_root argument.\n" if ! -f $lib_ocf_dirs;

$ocf_dirs = qx{
  . "$lib_ocf_dirs" 2> /dev/null
  echo "\$INITDIR"
  echo "\$HA_DIR"
  echo "\$HA_RCDIR"
  echo "\$HA_CONFDIR"
  echo "\$HA_CF"
  echo "\$HA_VARLIB"
  echo "\$HA_RSCTMP"
  echo "\$HA_RSCTMP_OLD"
  echo "\$HA_FIFO"
  echo "\$HA_BIN"
  echo "\$HA_SBIN_DIR"
  echo "\$HA_DATEFMT"
  echo "\$HA_DEBUGLOG"
  echo "\$HA_RESOURCEDIR"
  echo "\$HA_DOCDIR"
  echo "\$HA_VARRUN"
  echo "\$HA_VARLOCK"
  echo "\$prefix"
  echo "\$exec_prefix"
};

@ocf_dirs{
  'INITDIR',     'HA_DIR',     'HA_RCDIR',      'HA_CONFDIR',     'HA_CF',
  'HA_VARLIB',   'HA_RSCTMP',  'HA_RSCTMP_OLD', 'HA_FIFO',        'HA_BIN',
  'HA_SBIN_DIR', 'HA_DATEFMT', 'HA_DEBUGLOG',   'HA_RESOURCEDIR', 'HA_DOCDIR',
  'HA_VARRUN',   'HA_VARLOCK', 'prefix',        'exec_prefix'
} = split /\n/ => $ocf_dirs;

$build->install_path( 'lib'    => "$lib_ocf_root/lib/heartbeat" );
$build->install_path( 'script' => "$lib_ocf_root/resource.d/heartbeat" );

for my $dir (
    $ocft_confs, "$ocf_dirs{'prefix'}/share/resource-agents/ocft/configs"
) {
    if ( -d $dir ) {
        print STDERR "Found OCFT_CONFS: $dir\n";
        $ocft_confs = $dir;

        $build->add_build_element('tests');
        $build->install_path( 'tests'  => "$ocft_confs" );
        last;
    }
}

$build->create_build_script;

Storable::store( \%ocf_dirs, File::Spec->tmpdir."/ocf_dirs.bin" );
