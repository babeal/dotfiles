# ASDF usage and installation guide

## Install `asdf` - this is handled by the mac setup

`asdf` - https://github.com/asdf-vm/asdf

```bash
brew install asdf
```

Then source the scripts in the shell configuration

```
local asdfInstall="/usr/local/opt/asdf" # $(brew --prefix asdf)
[[ -s "$asdfInstall/asdf.sh" ]] && source "$asdfInstall/asdf.sh"
[[ -s "$asdfInstall/etc/completions/asdf.bash" ]] && source "$asdfInstall/etc/completions/asdf.bash"
```

## Python Instructions

On a new terminal, install Python plugin:

```bash
asdf plugin-add python
```
You may need some libraries on your system to ensure all parts you need of Python are compiled:

Set a global python version. Since mac comes with and expects python2 as the default, set the global python to be the system version:

```bash
asdf global python system
```
At this point, `python --version` & `python2 --version` will point to the system version of python2 and `python3 --version` will point to the homebrew installed python3 version (if it was installed).  

### Project Python versions

To run a different version of python for a project do this following:

```bash
asdf install python ${VERSION}

cd /project/folder
asdf local python 3.8.7
```

Below taken from https://gist.github.com/rubencaro

## Routine processes

Here I use [venv](https://docs.python.org/3/library/venv.html) to isolate the project environment ([virtualenv](https://virtualenv.pypa.io/en/latest/) for Python2) and [pip](https://pip.pypa.io/en/stable/user_guide/) to track dependencies.

### Setup a new project

Create a folder for the project and `cd` into it. Then fix your Python version `asdf local python 3.7.4`. Once you have that, you can create the project's environment `python -m venv env`. That will create an `env` folder that you should add to your `.gitignore`.

#### Python 3

Create a folder for the project and `cd` into it. Then fix your Python version `asdf local python 2.7.16`. Then you must install `virtualenv` by running `pip install virtualenv`. Once you have that, you can create the project's environment `virtualenv env`. That will create an `env` folder that you should add to your `.gitignore`.

### Activate the environment

__You must always activate the environment before working on your code.__ It's simple, but vital. Activation is what ensures that the paths for your code dependencies are local to your project, and not shared with others. Just run `source env/bin/activate`. You should see a `(env)` prefix on your prompt showing it is activated.

Once activated, calls to `python` or `pip` will use your project's local binaries, and your code will import libraries present only in your local project's environment.

Some editors, such as VSCode, do this automatically for you when they detect an `env` folder in the root of a Python project. You must keep it in mind though, being aware of the actual Python environment you are in.

You can make you shell to do that automatically too by adding this to your `.bashrc`:

```bash
# auto activate virtualenv when entering its root path
function auto_activate_virtualenv {
  if [[ "$VIRTUAL_ENV" = "" && -f "$PWD/env/bin/activate" ]]; then
    source "$PWD/env/bin/activate"
  fi
}

function prompt_command {
  # other stuff
  # ...
  auto_activate_virtualenv
}

export PROMPT_COMMAND=prompt_command
```

### Start working on an existing project

Provided the project was created following this guide, it is straightforward to start working on it. You should clone it, then `cd` into its folder, run `asdf install` to get the right Python version. Then `python -m venv env` to create a new environment and `source env/bin/activate` to activate it. Then run `pip install -r requirements.txt` to install all dependencies. If any dependencies include binaries, you may need to run `asdf reshim python` to ensure they are accessible from `PATH`.

#### Python2

You should clone it, then `cd` into its folder, run `asdf install` to get the right Python version. Then you must install `virtualenv` by running `pip install virtualenv`. Then `virtualenv env` to create a new environment and `source env/bin/activate` to activate it. Then run `pip install -r requirements.txt` to install all dependencies. If any dependencies include binaries, you may need to run `asdf reshim python` to ensure they are accessible from `PATH`.

### Add new depencencies

[Activate the enviroment](#Activate-the-environment). Then simply install your dependency with `pip install yourdependency`. Once it's installed, freeze project's dependencies by running `pip freeze > requirements.txt`. If any dependencies include binaries, you may need to run `asdf reshim python` to ensure they are accessible from `PATH`.

### Remove a dependency

[Activate the enviroment](#Activate-the-environment). Then simply uninstall your dependency with `pip uninstall yourdependency`. Once it's uninstalled, freeze project's dependencies by running `pip freeze > requirements.txt`.


## Node Instructions

Install the node plugin

```
asdf plugin-add "nodejs" "https://github.com/asdf-vm/asdf-nodejs.git"
```

Install the lts version of node [see mange versions](https://asdf-vm.com/#/core-manage-versions)

```
asdf install nodejs lts
```

Set that version of node as default global install

```
asdf global nodejs lts
```