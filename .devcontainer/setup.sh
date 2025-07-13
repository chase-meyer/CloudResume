#!/bin/bash
set -e

git clone https://github.com/chase-meyer/sage-light-vscode.git /tmp/sage-light-vscode
code --install-extension /tmp/sage-light-vscode
rm -rf /tmp/sage-light-vscode

pip install --upgrade pip 
pip install flask azure-cli pylint && az --version 