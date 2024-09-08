# nix expressions for creating a qubes templatevm

## what works
- qrexec
- appvm networking
- xorg
- copy / paste
- qvm-copy
- ssh over qrexec ( handy for using --target-host with nixos-rebuild )
- memory reporting / ballooning

## what doesn't work / untested
- qubes update checks / triggers 
- populating application shortcuts
- update proxy
- building an rpm for the templatevm
- using a non-xen provided kernel
- usb proxy?
- using as netvm or usbvm
