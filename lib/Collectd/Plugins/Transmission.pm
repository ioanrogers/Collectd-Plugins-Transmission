package Collectd::Plugins::Transmission;

# ABSTRACT: collect transmission torrent statistics

use v5.10.1;
use strict;
use warnings;
use Collectd qw/:all/;
use Transmission::Client;
use Try::Tiny;

plugin_register( TYPE_INIT,   'Transmission', 'transmission_init' );
plugin_register( TYPE_CONFIG, 'Transmission', 'transmission_config' );
plugin_register( TYPE_READ,   'Transmission', 'transmission_read' );

my $tm_client;
my $tm_opts  = { autodie => 1, };

my $plug_opts = {
    use_current_speed     => 0,
    use_session_bandwidth => 0,
};

sub transmission_config {
    my $config = shift;

    foreach my $kv ( @{ $config->{children} } ) {

        my $key   = $kv->{key};
        my $value = $kv->{values}[0];

        given ( $key ) {
            when ( 'URL' ) {
                $tm_opts->{url} = $value;
            }
            when ( 'Username' ) {
                $tm_opts->{username} = $value;
            }
            when ( 'Password' ) {
                $tm_opts->{password} = $value;
            }
            when ( 'Password' ) {
                $tm_opts->{password} = $value;
            }
            when ( 'UseCurrentSpeed' ) {
                if ($value == 1 ) {
                    $plug_opts->{use_current_speed} = 1;
                }
            }
            when ( 'UseSessionBandwidth' ) {
                if ($value == 1) {
                    $plug_opts->{use_session_bandwidth} = 1;
                }
    
            }
        };
    }

    return 1;
}

sub transmission_init {

    try {
        $tm_client = Transmission::Client->new($tm_opts);
    }
    catch {
        plugin_log LOG_ERR, "Failed to init Transmission::Client: [$_]";
    };

    return 1;
}

sub transmission_read {
    my $stats = $tm_client->rpc('session-stats');

    my %values = (
        transmission_cum_bytes_down       => $stats->{'cumulative-stats'}->{downloadedBytes},
        transmission_down_speed_avg	      => $stats->{'cumulative-stats'}->{downloadedBytes},
        transmission_cum_bytes_up         => $stats->{'cumulative-stats'}->{uploadedBytes},
        transmission_up_speed_avg         => $stats->{'cumulative-stats'}->{uploadedBytes},
        transmission_torrent_count        => $stats->{torrentCount},
        transmission_active_torrent_count => $stats->{activeTorrentCount},
        transmission_paused_torrent_count => $stats->{pausedTorrentCount},
    );

    if ($plug_opts->{use_session_bandwidth}) {
        $values{transmission_cur_bytes_down} = $stats->{'current-stats'}->{downloadedBytes};
        $values{transmission_cur_bytes_up}   = $stats->{'current-stats'}->{uploadedBytes};
    }

    if ($plug_opts->{use_current_speed}) {
        $values{transmission_download_speed} = $stats->{downloadSpeed};
        $values{transmission_upload_speed}   = $stats->{uploadSpeed};  
    }

    foreach my $key (keys %values) {
        my $vl = {
            plugin   => 'tranmission',
            type     => $key,
            'values' => [ $values{$key} ],
        };
        plugin_dispatch_values($vl);
    }

    return 1;
}

1;

__END__

=head1 SYNOPSIS

 <LoadPlugin perl>
    Globals true
 </LoadPlugin>

 <Plugin perl>
    BaseName "Collectd::Plugins"
    LoadPlugin Transmission
    <Plugin Transmission>
       # All optional
       URL "http://localhost:9091/transmission/rpc"
       Username "tm_user"
       Password "tm_pass"
       UseCurrentSpeed true      # defaults to false
       UseSessionBandwidth true  # defaults to false
    </Plugin>
 </Plugin>

