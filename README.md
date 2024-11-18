# nix expressions for creating a qubes templatevm

## getting started

*warning*: proceed at your own risk, this involves copying files to dom0 and installing a template
without gpg signature verification

1. download the template rpm
2. copy the template rpm to dom0
```
qvm-run --pass-io <YOUR_DOWNLOAD_VM> 'cat <FULL_RPM_PATH>' > qubes-template-nixos-4.2.0-unavailable.noarch.rpm
```
3. install the template
```
qvm-template install qubes-template-nixos-4.2.0-unavailable.noarch.rpm --nogpgcheck
```
4. start the template and wait about 30s ( see qrexec notes. )
```
qvm-start nixos
```
5. start a terminal in the template
```
qvm-run nixos xterm
```

at this point you can customize the template and use it like any other NixOS install. the example config has been copied to `/etc/nixos`.

## issues with the qubes updates proxy

by default a qubes template does not have direct internet access and instead uses the qubes updates proxy
over qrpc. nix does not have a concept of a global proxy setting and as such is tricky to correctly 
configure in a way that doesn't involve simply setting `all_proxy` everywhere. 

as a compromise the packaging sets `all_proxy` for nix-daemon but not all downloads go through nix-daemon. the qubes packaging in this repo creates aliases for interactive shells that wrap a few of the common nix programs to pass proxy info. however this leaves various edge cases, a few of which are noted below. remember that you can always set `all_proxy` in your environment manually or in the worst case, switch to giving the template direct internet access.

### issues with sudo nix commands

due to the above, you're likely to run into issues when running `sudo nix...` - in these cases you can instead first get an interactive root shell e.g. via `sudo su`.

### issues with remote nix configs on github

you may run into issues if you pull a remote nix config over ssh from github. to workaround
you can add the following to `~/.ssh/config` ( the host and port overrides are necessary since these
qubes updates proxy filters port 22. ):
```
Host github.com
  HostName ssh.github.com
  Port 443
  ProxyCommand nc -X connect -x 127.0.0.1:8082 %h %p
```

## notes

### what works
- qrexec eventually works
- appvm networking
- xorg
- copy / paste
- qvm-copy
- ssh over qrexec ( handy for using --target-host with nixos-rebuild )
- memory reporting / ballooning
- qubes update checks
- qubes update triggers ( requires unmerged upstream changes )
- usb proxy
- building an rpm for the templatevm
- grow root fs
- update proxy

### what doesn't work / untested
- qrexec startup isn't clean, commands can fail initially
- populating application shortcuts
- using a non-xen provided kernel
- using as netvm or usbvm
- time sync via rpc ( currently handled is systemd-timesyncd, but per vm ntp sync creates more attack surface area? )

### bugs
- memory resizing seems to cause crashes in ff

### todo
- deal with substituteInPlace deprecation
- should be using 4.2.x package versions across the board, there's a couple 4.3.x packages atm
