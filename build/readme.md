# Building and Deploying _Reading List_

This directory contains scripts used during automated build processes.

- [before_install.sh](before_install.sh) is used to prepare a repository or a build on [Travis CI](https://travis-ci.org/AndrewBennet/ReadingList).

- [fabric.sh](fabric.sh) is used during the regular build process, but is empty by default. The script above populates the file when it is run on [Travis CI](https://travis-ci.org/AndrewBennet/ReadingList), based on secure environment variables.
