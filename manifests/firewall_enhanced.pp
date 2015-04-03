# Call firewall::firewall{} with stateless equivalent rules.
define superfirewall::firewall_enhanced (
  $track = true,  # Set to false to generate equivalent stateless rules.
  # The remainder reflect parameters to Firewall[].  Sorted alphabetically.
  $action = undef,
  $chain = undef,
  $destination = undef,
  $dport = undef,
  $ipset = undef,
  $jump = undef,
  $proto = undef,
  $source = undef,
  $sport = undef,
  $state = undef,
  $table = undef,
) {

  if ($track) {

    firewall { $title:
      # Keep these sorted alphabetically:
      action      => $action,
      chain       => $chain,
      destination => $destination,
      dport       => $dport,
      ipset       => $ipset,
      jump        => $jump,
      proto       => $proto,
      source      => $source,
      sport       => $sport,
      state       => $state,
      table       => $table,
    }

    firewall { [
        "${title} RAWPRE",
        "${title} RAWOUT",
        "${title} NTORIG",
        "${title} NTREV",
      ]:
      ensure => absent;
    }

  } else {

    # Validate the input.

    if ($action != 'accept') {
      fail('For track=true, action must be accept')
    }
    if ($jump != undef) {
      fail('For track=true, jump must be undef')
    }
    if ($table != undef) {
      fail('For track=true, table must be unspecified')
    }
    if (!($chain in [ 'INPUT', 'OUTPUT' ])) {
      fail('For track=true, chain must be INPUT or OUTPUT')
    }
    # TODO(tlim): There are other situations where fail() is appropriate.

    # Calculated parameters.

    $ipset_reverse = $ipset ? {
      undef => undef,
      /(.*) src$/ => "${1} dst",
      /(.*) dst$/ => "${1} src",
    }  # No default. Should not happen. We want it to fail if it does.

    case $chain {
      'INPUT': {
        $chain_reverse = 'OUTPUT'
        $chain_rawfwd = 'PREROUTING'
        $chain_rawrev = 'OUTPUT'
      }
      'OUTPUT': {
        $chain_reverse = 'INPUT'
        $chain_rawfwd = 'OUTPUT'
        $chain_rawrev = 'PREROUTING'
      }
      default: {
        fail('Should not happen. $chain unknown.')
      }
    }

    # Generate the rules.

    firewall { $title:
      ensure => absent;
    }

    # The raw/PREROUTING entry:
    firewall { "${title} RAWFWD":
      table       => 'raw',
      chain       => $chain_rawfwd,
      jump        => 'NOTRACK',
      state       => undef,
      action      => undef,
      # Keep these sorted alphabetically:
      dport       => $dport,
      destination => $destination,
      ipset       => $ipset,
      proto       => $proto,
      source      => $source,
      sport       => $sport,
    }

    # TODO(tlim): This could be a little more optimized by adding a --jump
    # to the raw/PREROUTE and raw/OUTPUT entries. More testing is required.

    # The raw/OUTPUT entry:
    firewall { "${title} RAWOUT":
      table       => 'raw',
      chain       => $chain_rawrev,
      jump        => 'NOTRACK',
      ipset       => $ipset_reverse,
      destination => $source, # swapped
      source      => $destination, # swapped
      dport       => $sport, # swapped
      sport       => $dport, # swapped
      action      => undef,
      state       => undef,
      # Keep these sorted alphabetically:
      proto       => $proto,
    }

    # The normal filter entry:
    firewall { "${title} NTORIG":
      table       => 'filter',
      chain       => $chain,
      action      => 'accept',
      jump        => undef,
      state       => undef,
      # Keep these sorted alphabetically:
      destination => $destination,
      dport       => $dport,
      ipset       => $ipset,
      proto       => $proto,
      source      => $source,
      sport       => $sport,
    }

    # The reverse filter entry:
    firewall { "${title} NTREV":
      table       => 'filter',
      chain       => $chain_reverse,
      action      => 'accept',
      ipset       => $ipset_reverse,
      destination => $source, # swapped
      source      => $destination, # swapped
      sport       => $dport, # swapped
      dport       => $sport, # swapped
      jump        => undef,
      state       => undef,
      # Keep these sorted alphabetically:
      proto       => $proto,
    }

  }

}
