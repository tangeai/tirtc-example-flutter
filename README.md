# TiRTC Flutter Example

This directory is the fixed local publish root for the public Flutter example repository.

## Scope

- carries the public Flutter example repo contract and bootstrap handoff point
- becomes the local working copy of `tirtc-example-flutter` once the first public `main` commit exists

## Out Of Scope

- does not define the Flutter plugin or example source of truth
- does not carry internal workflow discussion or owner-only helper assets

## Release Contract

- source content is synchronized from `products/sdk/flutter/tirtc_av_kit/example/`
- the published repo must not keep `tirtc_av_kit: path: ..`; it is rewritten to the exact released package version before verify and publish
- while the remote `origin/main` is still unborn, this path serves as the bootstrap target for the first publish; after that bootstrap commit lands, it is expected to be re-attached as the real submodule working copy
