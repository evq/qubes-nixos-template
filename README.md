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
qvm-template install qubes-template-nixos-4.2.0-unavailable.noarch.rpm
```
4. start the template and wait about 30s ( see qrexec notes. )
```
qvm-start nixos
```
5. start a terminal in the template
```
qvm-run nixos xterm
```

at this point you can customize the template and use it like any other NixOS install. As a starting point 
I recommend using ./examples/flake.nix and ./examples/configuration.nix to ensure the qubes packages 
and configuration remain installed.

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
- qubes update triggers
- usb proxy

### what doesn't work / untested
- qrexec startup isn't clean, commands can fail initially
- populating application shortcuts
- update proxy
- building an rpm for the templatevm
- using a non-xen provided kernel
- using as netvm or usbvm
- time sync
- grow root fs

### bugs
- memory resizing seems to cause crashes in ff

### todo
- deal with substituteInPlace deprecation
