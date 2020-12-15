---
title: "Shell Competency and Prominent Anti-Patterns"
date: 2020-12-15T23:45:00-06:00
description: "You'll always be bad at shell if you never practice."
tags:
    - devops
    - shell
---

Throughout my career, I've crossed paths with quite a few developers whose
chief expertise has run the gamut of programming languages: C, Python,
Java, Ruby, JavaScript, and so on. The programming language(s) in which you
build expertise undoubtedly influence the way you think about problems and
what solutions you're likely to reach for, and they do so in a big way.
The common thread I've noticed, though, is that developers on average lack
competency in their operating system shell. That lack of competency often
manifests as an *aversion* to the shell.

You may see that a developer prefers to use point-and-click interfaces
when a shell can get the job done more quickly and with exponentially
more flexibility. You might find that they write scripts in their native
language rather than struggle with the intricacies of `bash`. At one of
my previous workplaces, I uncovered a 30 line Ruby script that could
have been replaced by one pipeline in `bash`. Yes, a single pipeline.

This shell aversion is a real shame, because the shell can be a very powerful
tool in one's technical arsenal. The shell is _the_ textual interface to your
computer.  Regardless of familiarity, every developer will be forced to use a
shell in some ongoing capacity. That use may be to invoke `git`, grab a quick
snapshot of what is happening in the cloud with `aws`, or start a container
with `docker` or `docker-compose`. The uses are there, and they are many.

Because my experience has largely been infrastructure focused, the shell is more
often a sensible tool for me to reach for than it is for other developers.
Consequently, I learned many hard lessons about shell, best practices,
patterns, and anti-patterns.

And that brings us to the topic at hand today. A friend sent me a blog post
claiming to implement a "safe" template for bash. Just insert your shell
into the provided blank. It's a fairly hefty template too, weighing in at
just under 100 lines.

Complements of [Better Dev.blog](https://betterdev.blog/minimal-safe-bash-script-template/),
the template follows (note: this is the template as originally published, before any edits):

{{< highlight bash "linenos=table" >}}
#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1

trap cleanup SIGINT SIGTERM ERR EXIT

usage() {
  cat <<EOF
Usage: $(basename "$0") [-h] [-v] [-f] -p param_value arg1 [arg2...]

Script description here.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-f, --flag      Some flag description
-p, --param     Some param description
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOCOLOR='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOCOLOR='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  flag=0
  param=''

  while :; do
    case "${1-}" in
    -h | --help)
      usage
      ;;
    -v | --verbose)
      set -x
      ;;
    --no-color)
      NO_COLOR=1
      ;;
    -f | --flag) # example flag
      flag=1
      ;;
    -p | --param) # example named parameter
      param="${2-}"
      shift
      ;;
    -?*)
      die "Unknown option: $1"
      ;;
    *)
      break
      ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ -z "${param-}" ]] && die "Missing required parameter: param"
  [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

  return 0
}

parse_params "$@"
setup_colors

# script logic here

msg "${RED}Read parameters:${NOCOLOR}"
msg "- flag: ${flag}"
msg "- param: ${param}"
msg "- arguments: ${args[*]-}"
{{< /highlight >}}

I won't sugar coat it. There's a *lot* wrong with this. Let's start
from the top.

## The Airing of Grievances

### The Shebang

```
#!/usr/bin/env bash
```

In case you don't know what a shebang is for, here's the quick
rundown: generally, when you execute a file on your computer, it's a raw
binary that your operating system understands and can execute natively.
Being that scripts aren't binaries, a file starting with `#!` signals
that instead, the command that follows should be executed and the the
file path passed to the interpreter.

In this case, we've got `env` searching a user's `PATH` and executing
`bash`. Proponents of this method would tell you that it smooths over
file system hierarchy differences between machines. That's technically
true.

But there's a big problem here: if you're at the level of experience
where you're copy/pasting a template, your `bash` script isn't
going to run on any machine other than the one you wrote it on (or
other very similar systems where `bash` can be found at the same
place). Using `#!/usr/bin/env bash` as the shebang gives the
*misleading* impression that you can just take the script and
run it somewhere else. And that's just not true unless your script does
almost nothing of interest, or you actually understand the differences
between various platforms and can account for them when writing
your script. Furthermore, as the author, you probably originally
wrote the script with the system-wide `bash` in mind - so why
shouldn't you just use that one?

"But John," you say. "When I use `python` and `ruby` and other scripting
languages, I always use `#!/usr/bin/env`." You sure do. The difference
between `bash` and those other languages is that those other ones
have tooling built around them, like `pyenv`, `poetry`, `rbenv` and `bundler`,
to facilitate running at a non-standard location with a particular
interpreter version and collection of libraries.

Don't misrepresent your script from the outset. Just use `#!/bin/bash`
unless you can actually handle running in another environment.

### The `set` Smorgasbord

```
set -Eeuo pipefail
```

Here we've got a smattering of shell options that are commonly used, but
are not universal. Here's what `bash` has to say about those options,
with irrelevant options removed for brevity:

```
$ help set
      -e  Exit immediately if a command exits with a non-zero status.
      -u  Treat unset variables as an error when substituting.
      -o option-name
          Set the variable corresponding to option-name:
              pipefail     the return value of a pipeline is the status of
                           the last command to exit with a non-zero status,
                           or zero if no command exited with a non-zero status
      -E  If set, the ERR trap is inherited by shell functions.
```

Right off the bat, `set -e` is a giant landmine. What happens when you pipe
some text to `grep` and nothing matches? Well, `grep` exits with a non-zero
status. Oops!

You can work around this with an `if` statement, or slapping an `|| true`
on the end, but it creates an entirely new problem. It's still something you
have to remember to do everywhere, but only for very few binaries.

`grep` is not the only binary that uses its exit code informatively.
`terraform plan -detailed-exitcode`, for example, will let you know whether
the plan showed a diff or not, or if there was an error during the plan
process. In this sort of case, you'd probably want to capture the exit code
with something like `rc="$?"` immediately after so that you can deal with it
as appropriate.

`set -u` is fine, and I would recommend it generally. That said, you've got to
be responsible and initialize anything you're going expecting to get via the
environment. If you don't, your program will bomb with a canned error message
and exit code. Your users (or future you) will appreciate a reminder regarding
expected environment variables and what their values ought to be. For example,
you might write something like:

{{< highlight bash "linenos=table" >}}
#!/bin/bash

set -uo pipefail

MY_SECRET_PASSWORD=${MY_SECRET_PASSWORD:-}

if [[ -z "$MY_SECRET_PASSWORD" ]]; then
    echo 'you forgot to provide your secret password' >&2
    exit 1
fi
{{< /highlight >}}


I don't take any exceptions with `set -o pipefail`.

The biggest problem I have with `set -E` is that its only usefulness comes
from catching unhandled errors in your script. Unhandled errors are
a deficiency with the script as written, and should be corrected. And, like
`set -e`, you run into the same sort of problem where executables
might use the exit code to communicate some information that is not
necessarily a fatal error.

### An Immediate Directory Change

On line 5, before any script logic has been executed, this template will
change the current directory:

```
cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1
```

Want to pass the script a relative file path? Not on my watch.

Don't change directories in your script unless you are ready to deal with
the consequences of that.

Additionally, this displays another anti-pattern: the use of `$BASH_SOURCE`.
It only works in `bash`, not in any other shell. The manual says that:

```
BASH_SOURCE
    An array variable whose members are the source filenames where the
    corresponding shell function names in the FUNCNAME array variable are
    defined.  The shell function ${FUNCNAME[$i]} is defined in the file
    ${BASH_SOURCE[$i]} and called from ${BASH_SOURCE[$i+1]}.
```

Proponents of the use of `$BASH_SOURCE` would argue that `$BASH_SOURCE` works
both when a script is sourced and when it is executed. That is true,
but also only useful in the rarest of circumstances.

Sourcing acts like an include or import in other programming languages.
The sourced script is effectively inlined. Unless both the sourcing script
and sourced script are built with that in mind, you're signing up for chaos.

I have been writing bash for a long time, and I haven't yet encountered an
instance where there was a compelling argument for a single script to be
either sourced _or_ executed.

Sourcing is useful mainly in two circumstances: to include functions for
use in the sourcing script (i.e. treating the sourced script as a library),
or for the sourced script to serve as a sort of configuration file to
drive the sourcing script by setting some variables.

Rather than leaning on `$BASH_SOURCE`, just use `$0`. It works in multiple
shells. This is all you need to figure out where your script is located:

```
script_dir=$(dirname "$0")
```

That's it. It's beautifully simple. If you really need an absolute path,
you could follow it up with `readlink`, like so (note: I am fairly
certain `readlink` is a GNU-specific coreutil):

```
abs_script_dir=$(readlink -f "$script_dir")
```

You almost certainly don't need `$BASH_SOURCE`. The most common legitimate use
I can think of would be to break up a library into multiple source files.

### It's a `trap`

`trap` is quite a useful feature to perform cleanup when a script exits, except
when your script hasn't done anything yet and _there is nothing to clean up_.
So why is `cleanup` installed as a `trap` on line 7?

Cleanup logic should be configured just before it is needed. Otherwise you're
running cleanup routines needlessly. What happens if those cleanup routines
take a long time to execute? What if their proper execution is state-dependent?
If you're running a cleanup routine, you likely depend on some sort of global
variable containing a lock file path, or perhaps some type of script
configuration, or credentials. What happens if you try to run the cleanup
routine when those things aren't properly initialized?

Understand the flow of your script so that you can make informed decisions about
what needs to be cleaned up and when.

Additionally, the plethora of signals isn't required for most scripts.

`trap cleanup EXIT` will run the `cleanup` exactly one time when the script exits
without having to do additional fiddling with `trap` inside your cleanup routine.

### Escape Codes that _Hopefully_ Make Colors

This template does not configure colors correctly. It will work for many terminals
with varying degrees of success, but not all of them. Some terminals support
color, some don't. Some terminals support more color than others. Some support
features like bold or underline.

Use `tput` to get the proper escape sequences for your terminal from the
terminfo database.

### Parameter Parsing is not Mandatory

This script includes parameter parsing that is often not necessary in shorter
scripts. Sometimes, just giving `$1` a friendly variable name is sufficient.
Your script may not even use any arguments, in which case why bother with
parameter parsing at all?

Then there are even cases where you actively _don't want parameter parsing_. One such
example would be any script that acts largely as a wrapper to some other executable,
like this one I use to launch `rofi` with a set of arguments always passed:

{{< highlight bash "linenos=table" >}}
#!/bin/bash

font_size=12
if [[ "$DISPLAY_PROFILE" == 'UHD' ]]; then
    font_size=20
fi

exec /usr/bin/rofi \
    -monitor -4 \
    -matching fuzzy \
    -sort \
    -sorting-method fzf \
    -theme-str "* { font: \"mononoki Nerd Font Mono $font_size\"; }" \
    -theme "$DOTFILE_DIR/rofi/solarized-dark.rasi" "$@"
{{< /highlight >}}

### Grievances Concluded

I hope that if anything, this list of criticisms has helped impress upon you
that there really isn't a magic `bash` template you can copy/paste to solve
all of your problems. The best way to solve your shell problems is to
become shell proficient.

## Shell Observations

You will find no shortage of complaints in online programming forums about
just how awful it is to develop in shell. It's got strange syntax, it's
not legible, and so on. These criticisms are not without merit. `bash`
is going to treat you poorly if you don't quote arguments correctly
or if you fail to handle errors. It's quite easy to write shell that
is an absolute monstrosity in terms of readability.

The thing about `bash` is that it is in the highly unenviable position
of having to be an effective interactive language _and_ scripting
language. Can you imagine trying to use plain old `python` as
an interactive shell? It would be awfully tedious.

There are some neat projects out there that are attempting to improve on the
shell experience, like [xonsh](https://xon.sh/) and
[oil](https://www.oilshell.org/), but as far as I know they haven't seen
significant adoption yet. Keep an eye on those.

Shell is powerful, and it lends itself well to particular uses.
I offer one rule of thumb when considering whether or not to use
shell:

_Can your problem be solved effectively by executing a bunch of other processes?_

To answer this adequately, you need a good understanding of what coreutils and
shell are capable of. That means leveling up your shell expertise.
