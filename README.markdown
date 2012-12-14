LogCat
======

LogCat is a simple adb logcat viewer written purely in Objective-C and designed
with Apple's Human Interface Guidelines in mind. It uses the native GUI views
and is a lot nicer for the eyes than Eclipse plugins.

I'm a mobile device programmer. I've been working with Windows Mobile and iOS
for quite some time now and when I started Android development I found Eclipse
as the main frustration generator. It offers a lot of tools to get the job done
but the quality of their design is poor. I started using [eclim][eclim] on a regular
basis which allowed me to write code in Vim but I was lacking a small app that
would display Android logs and allow for easy filtering and searching within
them. Here it is - LogCat - a simple log viewer for Android.

P.S. This is my first open source project so please go easy on me :)

P.P.S. This was hacked in a couple of hours and I'm not the best Mac OS
X programmer in the world so it must look silly :)

Features
--------

* Search as you type filtering
* Definable filters for quick access to frequently checked logs. Filterable by:
	* message,
	* log type,
	* tag,
	* PID
* "Intelligent" automatic scroll
* Ability to change font color and style for each for different log types

Screenshot
----------

![LogCat](http://januszbossy.pl/LogCat.png "LogCat")

Credits
-------

Programming:

- **Janusz Bossy** - [SplashSoftware.pl][splash]
- **qhm123** - ([qhm123's GitHub profile][qhmgit])
- **Chris Wilson** - ([Chris' GitHub profile][cwgit])

Icon design: **Kamil Tatara** - [cakeshop.pl][cake]

Special thanks: **Dawid Gatti** ([Dawid's GitHub profile][dggit]) for emerging
with the idea for this project

Roadmap
=======

This is a not prioritized list of what I'd like to add to LogCat:

1. Support for more than 1 device at a time.
2. Automatically generated filters for all the tags, types etc.
3. Better and easier filter definitions with NSPredicateEditor.
4. RegExp searching and filtering.
5. Autodetection of adb location (or bundling the adb within LogCat?).
6. A better solution for reading and parsing adb output.

Contributing
============

If you find a bug or think you can add or fix sommething: fork, change, send
a pull request, welcome to the Credits list. That easy!

[eclim]: http://eclim.org "Eclim Homepage"
[splash]: http://splashsoftware.pl "SplashSoftware Homepage"
[cake]: http://cakeshop.pl "CakeShop"
[dggit]: https://github.com/dawidgatti "Dawid's GitHub Profile"
[cwgit]: https://github.com/yepher "Chris' GitHub profile"
[qhmgit]: https://github.com/qhm123 "qhm123's GitHub profile"
