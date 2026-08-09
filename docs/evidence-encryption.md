# Encrypted operational evidence

Operational evidence that is unsuitable for plaintext Git storage is encrypted
with SOPS and age. Raw evidence is retained locally under `evidence/` and is
never committed.

The repository tracks encrypted artifacts only in `evidence/encrypted/`. The
recipient policy is owned by `.sops.yaml`; the initial operator recipient is
the SSH ED25519 key with fingerprint
`SHA256:KxikWTJFxJlSqVuesl9uTE5UDd+Rq0MEyxIE4DB3nhU`.

Private identities, private keys, and credentials never belong in Git.

To seal an evidence bundle, create the archive outside the repository,
compress it first, encrypt it as binary SOPS JSON, and perform a decrypt plus
SHA-256 round trip before committing the encrypted artifact. Do not commit the
plaintext archive. Encrypted evidence is export-ignored and is not included in
guest source bundles.

Future recipient changes must use SOPS key-management/rekey procedures. Do
not decrypt evidence into the repository to modify recipient policy.
