# build-arch-packages-action
Arch Linux package builder GitHub action

## Usage

### GitHub actions example
Let's assume you have a github repo with Arch Linux package folders at the top level. Then you could create a `.github/workflows/build.yaml` file in your repo containing
```yaml
name: Build and Release Arch Linux packages
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  # Allows you to run this workflow manually from the Actions tab
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    env:
      ACTIONS_BOT_NAME: github-actions[bot]
    steps:
      - id: bs
        uses: greyltc/build-arch-packages-action@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```
then this action will build all packages in the repo, create a github release for the build, and attach the built packages (and source packages) as artifacts to the release.

### Local build
You can use this repo to build your Arch Linux packages locally too.
#### With Docker
Wherever docker-buildx can run (`ln`, `mkdir` commands might need to be adapted for Windows):
```bash
# starting from a directory containing package folders that each contain PKGBUILD files, etc.
git clone https://github.com/greyltc/build-arch-packages-action.git

# create the builder
docker buildx create --buildkitd-flags "--allow-insecure-entitlement security.insecure --allow-insecure-entitlement network.host" --name container --driver=docker-container

ln -s build-arch-packages-action/.dockerignore .  # or just copy it with cp or something
mkdir -p out/cache  # ensure the cache directory exists

# build the packages
docker buildx build --builder container --allow security.insecure --progress plain --target build --tag built --load --build-context packages=. --build-context cache=out/cache build-arch-packages-action

# copy them out
docker buildx build --builder container --allow security.insecure --progress plain --target export --output type=local,dest=out --build-context packages=. --build-context cache=out/cache build-arch-packages-action
```
build artifacts will have now appeard in a directory called `out`
#### With Podman
```bash
# starting from a directory containing package folders that each contain PKGBUILD files, etc.
git clone https://github.com/greyltc/build-arch-packages-action.git

# remove `--security=insecure` from the Dockerfile
cat build-arch-packages-action/Dockerfile | sed 's,--security=insecure ,,' > Containerfile

ln -s build-arch-packages-action/.dockerignore .  # or just copy it with cp or something
mkdir -p out/cache  # ensure the cache directory exists

# build the packages
podman build --cap-add=CAP_SYS_ADMIN --target build --tag built --build-context packages=. --build-context cache=out/cache --file Containerfile build-arch-packages-action

# copy them out
podman build --cap-add=CAP_SYS_ADMIN --target export --output type=local,dest=out --build-context packages=. --build-context cache=out/cache --file Containerfile build-arch-packages-action
```
build artifacts will have now appeard in a directory called `out`
