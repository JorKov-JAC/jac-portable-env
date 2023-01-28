# jac-portable-env
Sets up a portable developer environment for Windows computers. **Works without admin priviledges.**

Includes:
- .NET
- Git
- Node.js
- Visual Studio Code

## Setting up the environment (even without admin priviledges):
1. [Download `setup.cmd` from the latest release.](../../releases/latest)
1. Run the setup script.

## Using your portable environment:
1. Plug your portable USB drive into a Windows computer.
1. Run the `env.cmd` script. This will start a command prompt with the proper environment variables.
1. Launch your portable programs from the command prompt (instructions are included).

## FAQ
### Why can't Visual Studio Code analyze my C# project?
When opening a C# project, look for a notification (bottom right corner) saying "Required assets to build and debug are missing from 'project'. Add them?" and select "Yes". Alternatively, press `F1` or `Ctrl-Shift-P`, type "Restart OmniSharp", and press `Enter` (this should reshow the notification).

### Why can't Visual Studio Code do anything related to Git/Node.js/etc?
It's possible you launched VSCode directly instead of using `env.cmd`. Try launching it from `env.cmd` by entering `code` into the `env.cmd` terminal.

### I installed .NET version 7+. Why can't I make a new project for another .NET version, even when the local computer has that version installed!?
Since .NET 7, the portable version of .NET will hide whatever .NET SDKs you have on your local computer; See below for a workaround.

### I would like to have multiple portable versions of .NET! (also a workaround for .NET 7 hiding local versions)
At Time of Writing, the setup script does not help with this. However, you can work around this by running the script again, selecting the same base folder as your current installation, only telling it to install a different version of .NET, and then telling the script NOT to overwrite `env.cmd`.

Note that, when you want to use a version other than the latest, some commands will need you to specify which version you want to use, ex. `dotnet new console -f netcoreapp3.1` (see `dotnet new console --help`). `dotnet build`/`run`/`clean`/etc... are fine, however.
