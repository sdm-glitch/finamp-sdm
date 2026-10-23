# Finamp SDM — personal build

A personal build of [Finamp](https://github.com/jmshrv/finamp) (MPL-2.0), the Jellyfin music
player, with a few small patches:

- own application id and name ("Finamp SDM"), so it installs next to the official app;
- the cover on the player screen flips over to show the synced lyrics, with a text-size setting;
- a minimal player screen and a share button.

This is not an official Finamp release and gets no support — please use the
[official Finamp](https://github.com/jmshrv/finamp) instead.

Each build is a tag `sdm-<version>`: the upstream release tag plus one commit per patch, plus the
build workflow (`.github/workflows/sdm-build.yml`). APKs attached to releases are CI artifacts
signed with a throwaway key.
