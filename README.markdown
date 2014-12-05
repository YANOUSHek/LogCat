Now In App Store
==================

I've written a new Android logcat viewer named LogRabbit. You can [Get It From App Store](http://lograbbit.com). I will continue to make bug fixes to this fork but new improved fucntionality will be available in LogRabbit.

New LogRabbit Features
=====================
* JSON Formatting
* Base64 decode in log messages
* Ability to open links directly from log message
* Quickly search log message in Google
* Reliable application name detection
* Greatly improved integration with ADB
* 10x faster than LogCat
* Greatly improved stability

LogCat
======

LogCat is an adb logcat viewer written in Objective-C and designed with Apple's Human Interface Guidelines in mind. It uses the native GUI views and is a lot nicer for the eyes than the Eclipse plugins.

Originally written by Janusz Bossy who is a mobile device programmer. 
He's been working with Windows Mobile and iOS for quite some time. When Janusz started Android development he found Eclipse as the main frustration generator. It offers a lot of tools to get the job done but the quality of their design is poor. Janusz started using [eclim][eclim] on a regular
basis which allowed him to write code in Vim but he was lacking a small app that would display Android logs and allow for easy filtering and searching within them. Here it is - LogCat - a simple log viewer for Android.


Features
--------

* Advanced log filtering
* Filter with multiple filters at one time
* Definable filters for quick access to frequently checked logs. Filterable by:
	* message,
	* log type,
	* tag,
	* PID,
	* TID,
	* Timestamp
* "Intelligent" automatic scroll
* Ability to change font color and style for different log types
* Capture screen shots right from LogCat
* Can send typed characters to device

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

Special thanks: **Dawid Gatti** ([Dawid's GitHub profile][dggit]) for emerging with the idea for this project

Features Requests
==================
(In no particular order)
* Ability to categorize filters
* Ability to bookmark a log events and annotate
* Ability to import raw logs that were saved with adb or on device (from testers)
* Recent search suggestions
* Import/Export filters
* Ability to manually type predicate
* Provide configuration setting for default predicate
* Ability to configure background to be dark instead of white
* Send screen mouse touch events to device

Contributing
============

If you find a bug or think you can add or fix something: fork, change, send a pull request, welcome to the Credits list. That easy!

[eclim]: http://eclim.org "Eclim Homepage"
[splash]: http://splashsoftware.pl "SplashSoftware Homepage"
[cake]: http://cakeshop.pl "CakeShop"
[dggit]: https://github.com/dawidgatti "Dawid's GitHub Profile"
[cwgit]: https://github.com/yepher "Chris' GitHub profile"
[qhmgit]: https://github.com/qhm123 "qhm123's GitHub profile"
