# build-arch-packages-action
Arch Linux package builder GitHub action

## Usage

### GitHub actions example
Let's assume you have a github repo with Arch Linux package folders at the top level. Then you could create a `.github/workflows/build.yaml` file in your repo containing
```
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
You can use this repo to build your Arch Linux packages locally too, whereever docker-buildx can run:
```
# starting from a directory containing package folders that each contain PKGBUILD files, etc.
git clone https://github.com/greyltc/build-arch-packages-action.git
docker buildx build --progress plain --target build --tag built --load --build-context packages=. build-arch-packages-action
docker buildx build --progress plain --target export --output type=local,dest=out --build-context packages=. build-arch-packages-action
```
build artifacts will have now appeard in a directory called `out`
