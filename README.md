# Poetry Monorepo
Demonstrates how poetry packages within a monorepo can be published to pypi (wheel/tar.gz) by replacing the path dependencies with a version dependency before the twine upload.

There is a discussion regarding monorepo's in [python-poetry issue #936](https://github.com/python-poetry/poetry/issues/936)

Other examples:
* [ya-mori/python-monorepo](https://github.com/ya-mori/python-monorepo), which shows how to have multiple libraries and projects in one repo. Dependencies are all 'editable installs' (path dependencies).
* [dermidgen](https://github.com/dermidgen/python-monorepo) uses Makefiles. Applications depend on packages by path dependencies in ther `[tool.poetry.dev-dependencies]` section. The [makefile](https://github.com/dermidgen/python-monorepo/blob/master/tools/Packages.mk) extracts the package names, and will build a wheel for each one. Those wheels, together with the application, will be installed in the docker container.

## A monorepo with publishable wheel&sdist packages
Different people have different ideas of what a monorepo exactly is.

This example repository shows how one
* can have multiple python poetry projects in one git repo
* that depend on each other through a `path` dependency (allowing easy local development and testing)
* while still allowing each of them to be built (as wheel & sdist) and published
* such that they can be installed using pip, together with the required transitive dependencies.

As example, we here have a [package-b/pyproject.toml](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/package-b/pyproject.toml) that depends on a [package-a/pyproject.toml](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/package-a/pyproject.toml) by [`path="../package-a"`](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/package-b/pyproject.toml#L21). During development, `package-b` thus depends on the local on disk version of `package-a`.

If we would `poetry build` the packages just like that, the sdist and wheel artifacts of `package-b` will get a dependency of `package-a @ ../package-a`. It thus can't be `pip` installed in general, because one needs `package-a` at `../package-a` .

Therefore the poetry build should replace that dependency by a version, allowing the individual packages to be pip installed. In this case we replace the path by the semver compatible version of the whole repo (ie.`~1.2.3`)

## Approach
This example repo implements two different approaches:

1. Before running poetry build, apply `sed` to the [`package-b/pyproject.toml`](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/package-b/pyproject.toml) to replace the `path=..` dependency by the compatible semver version range (`~1.2.3`).
2. Run poetry build first, then apply `sed` to the metadata files within the sdist & wheel files to replace the path dependencies by the compatible version range `(~=1.2.3,>=1.2.3)`, as specified in <https://peps.python.org/pep-0440/#compatible-release>.

## Option 1: Editing `pyproject.toml`
One approach is thus to edit the `pyproject.toml` such that poetry will create the desired wheel&sdist artifact.

First we create a local git based version using [scripts/create_local_version](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/scripts/create_local_version.sh). This ensures we have the correct version for the branch (whether it is a tag, certain commit, or one with uncommitted changes). It will modify the root [VERSION]((https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/VERSION)) file, the `__version__` variables in the python code, and the version in the `pyproject.toml` files. (Though it doesn't discover those files itself).

Then, in [gitlab.ci.yml](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/poetry-package.gitlab-ci.yml#L95) we replace all path dependencies by that version.

Subsequently, we just run `poetry build` [here](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/poetry-package.gitlab-ci.yml#L74)

## Option 2: Editing artifacts
Alternatively, we run `poetry build`, and modify the created artifacts afterwards.

First we create a local git based version using [scripts/create_local_version](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/scripts/create_local_version.sh). This ensures we have the correct version for the branch (whether it is a tag, certain commit, or one with uncommitted changes). It will modify the root [VERSION]((https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/VERSION)) file, the `__version__` variables in the python code, and the version in the `pyproject.toml` files. (Though it doesn't discover those files itself).

Then, we just run `poetry build` [here](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/poetry-package.gitlab-ci.yml#L74) to create the artifacts.

Then, in [gitlab.ci.yml](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/poetry-package.gitlab-ci.yml#L105) we replace all path dependencies in the artifacts by that version. This is done by running [scripts/replace_path_deps.sh](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/scripts/replace_path_deps.sh). 

* It will look for relative path dependencies in the metadata of the build package.
* These will be replaced by the version range that is at least equal to the current version, and still compatible.
Thus if the monorepo is at `1.2.3`, it should assign `~1.2.3`. 
That is however a [semver range](https://devhints.io/semver), not one mentioned in <https://peps.python.org/pep-0440/#compatible-release>.
Therefore, it will set it to `(~=1.2,>=1.2.3)`.
