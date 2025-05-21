# build-arch-packages-action
Arch Linux package builder GitHub action

## Local build
You can use this repo to build your Arch Linux packages locally too:
```
# starting from a directory containing package folders that each contain PKGBUILD files, etc.
git clone https://github.com/greyltc/build-arch-packages-action.git
docker buildx build --progress plain --target build --tag built --load --build-context packages=. build-arch-packages-action
docker buildx build --progress plain --target export --output type=local,dest=out --build-context packages=. build-arch-packages-action
```
build artifacts will have now appeard in a directory called `out`
