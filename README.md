# nix expressions for creating a qubes templatevm

## what works
- qrexec
- appvm networking
- xorg
- copy / paste
- qvm-copy
- ssh over qrexec ( handy for using --target-host with nixos-rebuild )
- memory reporting / ballooning
- qubes update checks
- qubes update triggers
- usb proxy

## what doesn't work / untested
- populating application shortcuts
- update proxy
- building an rpm for the templatevm
- using a non-xen provided kernel
- using as netvm or usbvm
- time sync
- grow root fs

## bugs
- memory resizing seems to cause crashes in ff

## todo
- deal with substituteInPlace deprecation
