# Whatisdot Tap-example

## Installation
These packages require a GitHub token to be set up in your environment with the name `HOMEBREW_GITHUB_API_TOKEN`.

You can add this to your shell profile, or prefix it to the brew commands.
```
HOMEBREW_GITHUB_API_TOKEN=xxxxx brew ...
```

Install a specific formula from this repository:
```
brew install whatisdot/tap-example/<formula>
```

Install the repository and then formula by name:
```
brew tap whatisdot/tap-example
brew install <formula>
```

## Testing

### Validation
To validate that the package will work on your system, install the repository and run the following:
```
brew test tinker
```

### Locally/Development
To test locally, install the formula from source. Clone this repository and `cd` to it from a CLI terminal.

Run The following to install Tinker:
```
brew install --debug --build-from-source Formula/tinker.rb
```

This will reflect any changes you make to the formula in `Formula/tinker.rb`.

To run the test case for Tinker, you must have first installed locally from source. Then run the following:
```
brew test Formula/tinker.rb
```
