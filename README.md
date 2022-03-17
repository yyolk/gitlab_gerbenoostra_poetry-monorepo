# Poetry Monorepo
Demonstrates how poetry packages within a monorepo can be published to pypi (wheel/tar.gz) by replacing the path dependencies with a version dependency before the twine upload.

The main logic is in scripts/replace_path_deps.sh. 
It will look for relative path dependencies in the metadata of the build package.
These will be replaced by the version range that is at least equal to the current version, and still compatible.

Thus if the monorepo is at 1.2.3, it will assign ~1.2.3. 
That is however a semver range, not one mentioned in https://peps.python.org/pep-0440/#compatible-release.
Therefore, it will set it to (~=1.2,>=1.2.3).
