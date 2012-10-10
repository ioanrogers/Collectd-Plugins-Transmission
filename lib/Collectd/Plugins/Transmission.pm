package Collectd::Plugins::Transmission;

# ABSTRACT: collect transmission torrent statistics

use v5.14;
use strict;
use warnings;
use Collectd qw/:all/;
use Transmission::Client;
use Try::Tiny;

my @keys = qw/
    transmission_cum_bytes_down
    transmission_cum_bytes_up
    transmission_cur_bytes_down
    transmission_cur_bytes_up
    transmission_download_speed
    transmission_upload_speed
    transmission_torrent_count
    transmission_active_torrent_count
    transmission_paused_torrent_count
/;

plugin_register( TYPE_INIT,   'Transmission', 'transmission_init' );
plugin_register( TYPE_CONFIG, 'Transmission', 'transmission_config' );
plugin_register( TYPE_READ,   'Transmission', 'transmission_read' );

my $tm_client;
my $tm_opts  = { autodie => 1, };

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
        transmission_cum_bytes_up         => $stats->{'cumulative-stats'}->{uploadedBytes},
        transmission_cur_bytes_down       => $stats->{'current-stats'}->{downloadedBytes},
        transmission_cur_bytes_up         => $stats->{'current-stats'}->{uploadedBytes},
        transmission_download_speed       => $stats->{downloadSpeed},
        transmission_upload_speed         => $stats->{uploadSpeed},
        transmission_torrent_count        => $stats->{torrentCount},
        transmission_active_torrent_count => $stats->{activeTorrentCount},
        transmission_paused_torrent_count => $stats->{pausedTorrentCount},
    );

    foreach my $key (@keys) {
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
    </Plugin>
 </Plugin>

