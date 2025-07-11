#!/bin/bash

dart compile exe packages/dox-cli/bin/dox.dart -o packages/dox-cli/bin/dox
rm -rf packages/dox-app/bin/dox
cp packages/dox-cli/bin/dox packages/dox-app/bin/dox