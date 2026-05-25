fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios clean

```sh
[bundle exec] fastlane ios clean
```

Clean any generated Xcode project, workspace, ipa and Pods

### ios generate_dev

```sh
[bundle exec] fastlane ios generate_dev
```

Generate Xcode project and install dependencies for development mode

### ios generate_firebase

```sh
[bundle exec] fastlane ios generate_firebase
```

Generate Xcode project and install dependencies for Firebase distribution

### ios generate_testflight

```sh
[bundle exec] fastlane ios generate_testflight
```

Generate Xcode project and install dependencies for TestFlight build

### ios publish_firebase

```sh
[bundle exec] fastlane ios publish_firebase
```

Publish a pre-generated project to Firebase App Distribution

### ios publish_testflight

```sh
[bundle exec] fastlane ios publish_testflight
```

Publish a pre-generated project to TestFlight

### ios deploy_firebase

```sh
[bundle exec] fastlane ios deploy_firebase
```

Generate and publish project to Firebase

### ios deploy_testflight

```sh
[bundle exec] fastlane ios deploy_testflight
```

Generate and publish project to TestFlight

### ios upload_to_firebase

```sh
[bundle exec] fastlane ios upload_to_firebase
```

Upload an already-built ipa to Firebase App Distribution

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
