# export-proxies

A simple tool for exporting OS X proxy settings as environment variables.

## Usage

Build export-proxies using Xcode. Then add
```sh
eval `./path/to/export-proxies`
```
to your .profile, .bach_profile, .bashrc, or whatever file you're using to set up your environment.

NOTE:

If you want to use http protocol for https proxy, you should run
```sh
eval `./path/to/export-proxies --use-http-protocol-for-https-proxy`
```
instead.

## Credits

This was inspired by Mark Assad's [proxy-config](http://sydney.edu.au/engineering/it/~massad/project-proxy-config.html) that does not work with OS X 10.10.

Authors:

- [@janvogt](https://github.com/janvogt)
- [@mckelvin](https://github.com/mckelvin)
