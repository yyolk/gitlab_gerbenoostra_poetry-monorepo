# Poetry Monorepo
Demonstrates how to setup a poetry monorepo where
* you can have multiple python poetry projects in one git repo
* that, for local development, depend on each other using `--dev` **path** dependencies
* package building is done with name & version dependency
* packages within the repo can be published to pypi (wheel & tar.gz)
* docker files can be built from branch (without having to release packages to a pypi)
* conventional commits are used to determine semver version
* new semver versions are automatically released (as tag & gitlab release)
* all non-tag (=release) builds are done with local version identifiers

## Background
Poetry is a great tool to manage individual packages.
It however can't (out of the box) handle and manage mono repos. 
There is a discussion regarding monorepo's in [python-poetry issue #936](https://github.com/python-poetry/poetry/issues/936) and [#2270](https://github.com/python-poetry/poetry/issues/2270).
In this example repo I'll show how one can (quite easily) utilize poetry in a mono repo.

I'm not the first one doing this, other examples are:
* [ya-mori/python-monorepo](https://github.com/ya-mori/python-monorepo), which shows how to have multiple libraries and projects in one repo. Dependencies are all 'editable installs' (path dependencies). Note that built artifacts still depend on path dependencies.
* [dermidgen](https://github.com/dermidgen/python-monorepo) uses Makefiles. Applications depend on packages by path dependencies in ther `[tool.poetry.dev-dependencies]` section. The [makefile](https://github.com/dermidgen/python-monorepo/blob/master/tools/Packages.mk) extracts the package names, and will build a wheel for each one. Those wheels, together with the application, will be installed in the docker container. Note that the built artifacts don't have the internal dependencies in their 

My approach here is slightly different, in which I'll actually allow releasing the packages with valid named dependencies.

## How poetry can be adapted to work in a monorepo
The codebase here
* Uses path dependencies, for example `package-a = {path="../package-a", develop=true}`, that are checked into git.
* Built wheels will get a versioned dependency, for example `package-a="^VERSION"`, where VERSION is the current version of the mono-repo. 

This can be done in two ways:
* Modify the `pyproject.toml` (but not updating the `poetry.lock` file), and then use `poetry build`
* Or, first build the wheel & tar.gz artifacts, and then replace the path dependencies with name + version dependencies.

As a result, the wheel will contain a **named** dependency, even though development is done using **path** dependencies. Combining best of both worlds.

## Usage
To create the poetry virtual environments:
```shell
scripts/poetry_install.sh
```
It might update the `poetry.lock` files, which is mainly usefull when running on new architectures.

If a new dependency has been added to any of the poetry file, run the helper script to update all lock files:
```shell
scripts/poetry_update.sh
```
It by design will update all `poetry.lock` files, such that updated transitive dependencies are correct.
It might also update other transitive dependencies to latest versions.

On the build server, one can determine the actual local semver version of the current checkout, and update all version numbers in the codebase:
```shell
poetry run scripts/create_local_version.sh
```
Note that this changes the `pyproject.toml` files and all python files containing versions, which **should not be committed** to git.

To build all the wheels, run
```shell
scripts/poetry_build.sh
```
Note that this changes the `pyproject.toml` files with changes that **should not be committed** to git.

Alternatively, to not have to modify `pyproject.toml` files, one can first build the packages.
Then, we need to modify the dependencies in the wheel & tar.gz artifacts.
This is done as follows (without invoking `poetry_build.sh`):
```shell
cd package-b
poetry build
../scripts/replace_path_deps.sh
```

## How it works

## Determine local semver version
First we create a local semver version using [scripts/create_local_version.sh](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/scripts/create_local_version.sh).
This ensures we have the correct version for the branch (whether it is a tag, certain commit, or one with uncommitted changes).
It will modify the root [VERSION]((https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/VERSION)) file, the `__version__` variables in the python code, and the version in the `pyproject.toml` files.
These files are all listed explicitly in the bash script.


### Adapting poetry to a mono repo through modifying `pyproject.toml`
The `poetry_build.sh` works as follows:
* The `pyproject.toml` uses path dependencies, for example `package-a = {path="../package-a", develop=true}`, that are checked into git
* The `poetry_build.sh` will replace all `path=` dependencies into `package-a="^VERSION"`, where VERSION is the current version of the mono-repo
* Then it builds the python package using `poetry build`. As a result, the wheel will contain a **named** dependency, even though development is done using **path** dependencies. Combining best of both worlds.
* All wheels are then collected to the `dist/` folders of each package (the root and every package). This allows to build the docker files

The main downside of this approach is that the pyproject.toml is updated before building.
That change **should not be committed**, as it is only aimed on having `poetry` create a wheel with the correct dependencies.

Alternatively, the following can be done:

### Adapting poetry to a mono repo by modifying the artifacts directly
Instead of updating the `pyproject.toml`, and relying on `poetry` to create a correct wheel, we can also fix the wheel & `tar.gz` artifacts **after** building with `poetry`.

This can be done using `scripts/replace_path_deps.sh`.
* It will modify existing `dist/*.whl` and `dist/*.tar.gz` files, relatively to the location from which it is run.
* It will extract them to a temporary file
* It will look for relative path dependencies in the metadata files to be replaced
* These will all be replaced by the version range that is at least equal to the current version, and still compatible.
* Then the wheel is compressed again, and put back in the original location

If the monorepo is at `1.2.3`, this will modify the depencency effectively to `~1.2.3`.
Though that is a valid [semver range](https://devhints.io/semver), and interpretable by `poetry`, it is not mentioned in <https://peps.python.org/pep-0440/#compatible-release>.
Therefore, it will be set to `(~=1.2,>=1.2.3)`, such that it adheres to the pep standard.

## Adapting this to your own mono repo
You can freely copy and use the `.sh` scripts. 
But be aware that 
* `projects.sh` contains a list of all the poetry packages, in topological order
* `create_local_version.sh` and `pyproject.toml`'s `[tool.commitizen]` section contain references to all files with the repo version.

## Project structure
The root poetry project only contains development dependencies that are used on the full repo, for example `commitizen`, and `dunamai`.

The `.gitlab-ci.yml` shows how the helper scripts can be used in a CI/CD pipeline.

As it is a monorepo, all the packages in the repo share the same version (as defined in `VERSION`, the `pyproject.toml` and in the package's `__version__` definition) and have one shared `CHANGELOG.md`.

Each subfolder contains their own standalone `pyproject.toml` file, containing both production and development dependencies. `flake8`, `pytest` and the other dev tools are thus mentioned in each project.

The packages in the subfolder depend on each other using path dependencies, for example `package-a = {path="../package-a", develop=true}`.

As example, we here have a [package-b/pyproject.toml](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/package-b/pyproject.toml) that depends on a [package-a/pyproject.toml](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/package-a/pyproject.toml) by [`path="../package-a"`](https://gitlab.com/gerbenoostra/poetry-monorepo/-/blob/main/package-b/pyproject.toml#L21).
During development, `package-b` thus depends on the local on disk version of `package-a`.

The [service-c](https://gitlab.com/gerbenoostra/poetry-monorepo/~blob/main/package-c/) depends on `package-b`, and shows how to build a dockerfile with the wheels. 
The dockerfile assumes `poetry_build.sh` has been run before, which will collect the wheels of all modules into the `service-c`'s `/dist` folder.

## Choosing the right python version
Poetry uses a certain python version to create the virtual env.
The scripts first try to set the version using `pyenv` (defined by the `.python-version` file), if that fails, it will use the correct system python. 
One that is for example installed using `homebrew`.

## Further thoughts
The `dunamai` utility is also [available](https://github.com/mtkennerly/poetry-dynamic-versioning) as a poetry plugin, which can be used to set the version correctly (both for the wheel, and in `version.py` files).
After the build, it automatically reverts the version, to keep the committed files clean.

Following that approach, the modifications that I apply with the bash script, could also be done as a poetry plugin.