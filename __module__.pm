package Rex::Module::WebService::Solr;

use Rex -base;
use Data::Dumper;
use Rex::Commands::User;

our %service_name = (
   Debian => "solr",
   Ubuntu => "solr",
   CentOS => "solr",
   Mageia => "solr",
);

my %SOLR_CONF = ();
Rex::Config->register_set_handler("solr" => sub {
   my ($name, $value) = @_;
   $SOLR_CONF{$name} = $value;
});


set solr => source_gz => "http://archive.apache.org/dist/lucene/solr/6.6.3/solr-6.6.3.tgz";
set solr => service => {
	user => 'solr',
	service => 'solr',
	dir => '/var/lib/solr',
	home => '/var/lib/solr/data',
	log4j_prop => '/var/lib/solr/log4j.properties',
	log_dir => '/var/log/solr',
	port => 8983,	# can't work on 80
};


task setup => sub {
   my $source_gz = $SOLR_CONF{source_gz};
   my $solr_port = $SOLR_CONF{service}->{port};
   my $solr_dir = $SOLR_CONF{service}->{dir};
   my $solr_log_dir = $SOLR_CONF{service}->{log_dir};
   
   my $tmp_dir = "/tmp";
   $source_gz =~ m|(/[^/]+?)$|;
   my $target_tgz = $tmp_dir.$1;
   my $target_dir = '/opt/solr';
  
   # install required packages
   update_package_db;
   pkg "wget", ensure => "present";
   pkg "lsof", ensure => "present";

	setup_user();
	
	#Build Properties
	file $tmp_dir.'/install_solr_service.sh',
		source => 'files/install_solr_service.sh',
		mode  => 755;	
		
	file $solr_dir, ensure => "directory",
		owner  => $SOLR_CONF{service}->{user},
		group  => $SOLR_CONF{service}->{user};
	file $solr_log_dir, ensure => "directory",
		owner  => $SOLR_CONF{service}->{user},
		group  => $SOLR_CONF{service}->{user};
		

	# download compressed source file
	if (is_installed("wget")) {
		Rex::Logger::info('Downloading '.$source_gz);
		run 'wget '.$source_gz.' -O '.$target_tgz;
		die('Error downloading: '. $source_gz) unless ($? == 0);
	}   
	
	Rex::Logger::info("Installing solr...");
	
	run 'bash '.$tmp_dir.'/install_solr_service.sh '.$target_tgz.' -d '.$solr_dir.' -f -n -p '.$solr_port;
	die('error installing solr service') unless ($? == 0);	
	
	file '/etc/default/solr.in.sh',
		content => template ( "templates/solr.in.sh.tpl",
			conf => $SOLR_CONF{service}
		);
};

task start => sub {
   my $service = $service_name{get_operating_system()};
   service $service => "start";
};

task stop => sub {
   my $service = $service_name{get_operating_system()};
   service $service => "stop";
};

task restart => sub {
   my $service = $service_name{get_operating_system()};
   service $service => "restart";
};

sub is_running () {
   my $solr_service = $SOLR_CONF{service}->{service};
   run "ps -ef | grep -q $solr_service";   # only run if solr is running
   die('Service '.$solr_service.' is not running.') unless ($? == 0);
};

#TODO: make it dynamic
sub setup_user {
  my $solr = $SOLR_CONF{service};
  
  group $solr->{user},
	ensure => "present";
  
  account $solr->{user},
   ensure         => "present",  # default
   home           => $solr->{dir},
   comment        => 'Changed by solr rex module',
   groups         => [ $solr->{user} ];   
   #TODO: set /sbin/nologin as this user can't log
};

1;

=pod

=head1 NAME

$::module_name - {{ SHORT DESCRIPTION }}

=head1 DESCRIPTION

{{ LONG DESCRIPTION }}

=head1 USAGE

{{ USAGE DESCRIPTION }}

 include qw/Rex::Module::WebService::Solr/;

 task yourtask => sub {
    Rex::Module::WebService::Solr::setup();
	Rex::Module::WebService::Solr::restart();
 };

=head1 TASKS

=over 4

=item example

This is an example Task. This task just output's the uptime of the system.

=back

=cut
