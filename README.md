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

at this point you can customize the template and use it like any other NixOS install. the example config
has been copied to `/etc/nixos`.

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
