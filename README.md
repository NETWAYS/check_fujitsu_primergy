check_fujitsu_primergy
======================

Checks a Fujitsu server using SNMP.


### Requirements

* Perl Net SNMP library


### Usage

    check_fujitsu_primergy.pl - Icinga-Check Plugin for Fujitsu servers

    check_fujitsu_primergy.pl -H|--host=<host> -C|--community=<SNMP
    community string> [--blade] [-t|--timeout=<timeout in seconds>]
    [--fan-warning=<threshold>] [--fan-critical=<threshold>]
    [-v|--verbose=<>verbosity level>] [-e|--exclude=<subsystems to exclude
    from checks>] [-h|--help] [-V|--version]

    Checks a Fujitsu server using SNMP.


    -H|--host=<name-or-ip>
             Hostname or ip address of the server to check

    -C|--community=<SNMP community string>
             The SNMP community.

    --blade  switch the check mode to management blade, only the blade
             itself is checked

    -t|--timeout=<timeout in seconds>
             Time in seconds to wait before script stops.

    --fan-warning=<threshold>
             Threshold of fan speed (rpm) to give back a warning result.

    --fan-critical=<threshold>
             Threshold of fan speed (rpm) to give back a critical result.

    -v|--verbose=<verbosity level>
             Enable verbose mode (levels: 1,2). Multi-line output will be
             generated with verbose level 2.

    -e|--exclude=<subsystems to exclude from checks>
             Comma-sepatated list of non-global subsystems (all except
             Environment, PowerSupply, MassStorage and SystemBoard) to
             exclude from checking. If a global subsystem is in this list it
             just won't be displayed in plugin output but it won't affect
             the plugin's return state and return value.

             Typically used to exclude the Deployment subsystem.

    -V|--version
             Print version an exit.

    -h|--help
             Print help message and exit.

