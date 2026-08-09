# Encrypted evidence index

- Event: VM 320 guest-network recovery
- Date: 2026-08-09
- Encrypted artifact:
  `20260809-vm320-guest-network-recovery.tar.zst.sops.json`
- Plaintext archive SHA-256:
  `480107efa5d108d7aca11279d849fd2dc61baf9a3181474d74b5090abf9502ab`
- Encrypted artifact SHA-256:
  `7a9b76082d6727715fe96cb886f3831ac5d06f54ca77921804ee93a2ece225f0`
- Recipient fingerprint:
  `SHA256:KxikWTJFxJlSqVuesl9uTE5UDd+Rq0MEyxIE4DB3nhU`
- Source evidence:
  `evidence/20260809-vm320-guest-network-recovery/`

Cloud-init's NIC rename policy mismatched the guest interface name. Recovery
uses MAC-bound netplan and restores the secondary interface MTU to 9000.
