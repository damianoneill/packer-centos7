# Packer Image Builder for Centos 7

## Introduction

The focus is to:

* build production ready images
* reduce the image to the minimal required set
* do not expect any specific environment (for patch management etc)

This repository can be used to build

* KVM images

## Requirements

* The templates are only tested with [packer](http://www.packer.io/downloads.html) 0.5.2 and later.
* This build needs to be run on a Centos Host.

### CentOS 7

CentOS 7 is the next major release with [great new features](http://wiki.centos.org/Manuals/ReleaseNotes/CentOS7).

```bash
# start the installation
packer build -only=centos-7-qemu-qcow2 centos7.json

# shrink the image size
qemu-img convert -c -f qcow2 -O qcow2 -o cluster_size=2M target/centos-7-qemu.qcow2 target/centos-7-qemu-compressed.qcow2

```

# License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
