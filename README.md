# Control script for Roc Pulse modules

Control script for the [Roc PulseAudio modules](https://github.com/roc-streaming/roc-pulse).
Enable or disable Roc with a single command.

## Prerequisites

A functioning set of ```roc-pulse``` modules for PulseAudio on both Roc sender and receiver
(setup covered [here](https://github.com/roc-streaming/roc-pulse#readme)).

Prior SSH setup over SSH keys to the user account defined as ```REMOTE_USER``` on 
the receiver is necessary.

## Installation

Copy the contents to a directory and add the following control links. All operations
are triggered via the links, not the main ```roc_control.ksh``` script. The links may be
created anywhere outside the script directory as well.

```
ln -s roc_control.ksh roc_check
ln -s roc_control.ksh roc_check_local
ln -s roc_control.ksh roc_check_remote
ln -s roc_control.ksh roc_reload
ln -s roc_control.ksh roc_reload_local
ln -s roc_control.ksh roc_reload_remote
ln -s roc_control.ksh roc_start
ln -s roc_control.ksh roc_start_local
ln -s roc_control.ksh roc_start_remote
ln -s roc_control.ksh roc_stop
ln -s roc_control.ksh roc_stop_local
ln -s roc_control.ksh roc_stop_remote
ln -s roc_control.ksh roc_toggle
ln -s roc_control.ksh roc_toggle_local
ln -s roc_control.ksh roc_update
ln -s roc_control.ksh roc_update_local
```

### Configuration

Edit ```REMOTE_HOST``` & ```REMOTE_USER``` in ```roc_control.conf```. 

```REMOTE_HOST``` is the receiver. ```REMOTE_USER``` is either the user for the remote
PulseAudio commands or the user used to switch to ```SUDO_REMOTE_USER```.

If defined, ```SUDO_REMOTE_USER``` is the user to sudo to from ```REMOTE_USER``` and run
PulseAudio commands. Comment out ```SUDO_REMOTE_USER``` if ```REMOTE_USER``` is the remote
user PulseAudio is running as and there is no special remote user that PulseAudio runs as. 

The variables in the configuration file are set up with a shell default, specifically to
allow overriding them on the command line at any one time, as long as the shell default 
syntax is kept.

```
REMOTE_HOST=${REMOTE_HOST:-hostname}
REMOTE_USER=${REMOTE_USER:-username}
SUDO_REMOTE_USER=${SUDO_REMOTE_USER:-mpd}
```

The additional variables defined in ```roc_control.defaults``` do not normally need to be
modified. They are used internally by the ```roc_control.ksh``` script.

## Running

The main script ```roc_control.ksh``` is run over the links and will refuse to run via itself.

Note that starting the modules does not automatically switch sound to the PulseAudio sources; 
this is left up to the user to perform manually, usually via a set default output sound card 
option in a desktop environment sound manager or running the command:

```
pactl set-default-sink roc_sender
```

### Starting Roc

To start roc modules on the sender and receiver remote host defined as ```REMOTE_HOST``` run:

```# roc_start```

A different host may be specified on the command line:

```# roc_start HOSTNAME```

Where ```HOSTNAME``` stands for your remote host. If there is a change of IP required 
(see [Update mode](#Update-mode)), ```roc_start``` will run ```run_update``` internally.

Or using the default from the config file, provided the default syntax is preserved.

```# REMOTE_HOST=HOSTNAME roc_start```

If any other variables need to be overriden, it may be done with additional variables such as:

```# REMOTE_HOST=HOSTNAME REMOTE_HOST=USERNAME roc_start```

Starting Roc modules adds an appropriate module record to the local PulseAudio config file,
enabling the sender module on PulseAudio restart.

### Stopping Roc

Stopping Roc unloads the modules and comments out the sender's PulseAudio config file record
for the module, to ensure the sender does not start after PulseAudio restart.

```# roc_stop```

or

```# roc_stop HOSTNAME```

```roc_stop``` runs ```run_update``` internally, updating the IP address of the receiver
in the PulseAudio configuration file, if the IP specified ```HOSTNAME``` resolves to
has changed.

### Checking if Roc modules are running

```
# roc_check
Checking roc on local: 1 module-roc-sink module loaded on 127.0.0.1 
roc_check:1 module-roc-sink module loaded on 127.0.0.1 
Checking roc on remote: 1 module-roc-sink module loaded on 127.0.0.1 
roc_check:1 module-roc-sink-input module loaded on 127.0.0.1
```

```roc_check``` prints the same status to both standard error and standard output. 
See [Output control](#Output-control) for details on controlling the duplicate status
messages.

Check output may be redirected to a third party program for desktop notifications, e.g.:

```
# roc_check | xargs -ri kdialog --title 'Check roc' --passivepopup {}
```

### Output control

By default, the overall status is printed to standard output. More detailed status
messages for each operation are printed to standard error. Suppressing either output is
a matter of redirecting it to ```/dev/null```.

Display overall status only - redirect standard error:
```
# roc_start 2>/dev/null
Starting roc on local: ok
Starting roc on remote: ok
``` 

Display detailed status only - redirect standard output:
``` 
# roc_reload >/dev/null
roc_reload:1 module-roc-sink module loaded on 127.0.0.1 
roc_reload:1 module-roc-sink module already started on 127.0.0.1
roc_reload:0 module-roc-sink-input modules loaded on 127.0.0.1 
roc_reload:1 module-roc-sink-input module loaded on 127.0.0.1 
``` 

### Reload mode

If the IP of the receiver has changed, ```roc_reload``` will reload the module on the
sender, and start the module on the receiver if not already running.

## Mode scope

Stop, start, check & reload modes allow their scope to be limited to the sender (local)
or receiver (remote) by adding ```_local``` or ```_remote``` respectively to each command.

This allows for more-fine grained control where each action is run, e.g.

```
# roc_stop
Stopping roc on local: ok
roc_stop:1 module-roc-sink module loaded on 127.0.0.1 
roc_stop:0 module-roc-sink modules loaded
Stopping roc on remote: ok
# roc_start_remote
Starting roc on remote: ok
roc_start_remote:0 module-roc-sink-input modules loaded
roc_start_remote:1 module-roc-sink-input module loaded
# roc_check
Checking roc on local: 0 module-roc-sink modules loaded
roc_check:0 module-roc-sink modules loaded
Checking roc on remote: 0 module-roc-sink modules loaded
roc_check:1 module-roc-sink-input module loaded
# roc_start_local
Starting roc on local: ok
roc_start_local:0 module-roc-sink modules loaded
# roc_check
Checking roc on local: 1 module-roc-sink module loaded on 127.0.0.1 
roc_check:1 module-roc-sink module loaded on 127.0.0.1 
Checking roc on remote: 1 module-roc-sink module loaded on 127.0.0.1 
roc_check:1 module-roc-sink-input module loaded on 127.0.0.1 
# roc_stop_local
Stopping roc on local: ok
roc_stop_local:1 module-roc-sink module loaded on 127.0.0.1 
roc_stop_local:0 module-roc-sink modules loaded
# roc_check_local
Checking roc on local: 0 module-roc-sink modules loaded
roc_check_local:0 module-roc-sink modules loaded
```

## Supplementary functions

### Toggle mode

Roc modules may be toggled back and forth each time ```roc_toggle``` is run. The module
on the receiver is stopped or started based on the status of the module on the sender.

### Update mode

The update mode is provided as a convenience to address the fact the sender does not 
support DNS resolution for hostnames. The ```remote_ip``` parameter accepts only IPs.

In small home networks with DHCP, hostnames cannot be assumed to be persistent. The sender
needs to be aware the IP of the receiver has changed.

This mode does not normally need to be run, since ```roc_start``` or ```roc_stop```
already runs it internally as needed.

Running ```roc_update``` will redefine the ```remote_ip``` parameter in the PulseAudio
config file set in ```PACONFIG``` (normally ```~/.config/pulse/default.pa```) to whatever
the ```REMOTE_HOST``` currently resolves to.

Likewise, ```roc_update HOSTNAME``` will redefine the entry to the IP of ```HOSTNAME```.

An unresolvable DNS name will produce an error:
```
# roc_update non_existent_hostname
failed, unable to ping non_existent_hostname
```

## Authors

Copyright © twojstaryzdomu, 2020-2022.

## License

The scripts are licensed under [LGPL 2.1](LICENSE).

For details on Roc Toolkit licensing, see 
[here](https://roc-streaming.org/toolkit/docs/about_project/licensing.html).
