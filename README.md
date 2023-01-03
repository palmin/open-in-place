<p align="center">
<a href="https://developer.apple.com/swift/"><img src="https://img.shields.io/badge/Swift-5-orange.svg?style=flat" alt="Swift"/></a>

<img src="https://img.shields.io/badge/Platform-iOS%2013.0+-lightgrey.svg" alt="Platform: iOS">
<a href="http://twitter.com/palmin"><img src="https://img.shields.io/badge/Twitter-@palmin-blue.svg?style=flat" alt="Twitter"/></a>
</p>

# Open in Place.
Example app that illustrates how to get open-in-place to work well with iOS file providers.

It shows how to:

- invoke the document picker in open mode for files and directories
- receive open-in-place file references through Drag and Drop
- use and persist the security scoped URLs the document picker or Drag and Drop gives you
- work with a directory in a coordinated manner to stay in sync
- edit a text file in a coordinated manner such that your changes are written safely and such that outside changes appear in the editor automatically
- use the WorkingCopyUrlService file-provider SDK to fetch information about entries
- open using x-callback-url without user interaction for files in folders user has previously granted access using XCallbackOpener

Using the document picker to open directories will probably only work for iCloud Drive, external drives and 
a few third party apps. I am the author of [Working Copy](https://itunes.apple.com/us/app/working-copy/id896694807?mt=8&uo=6&at=1000lHq&ct=openinplace) and [Secure ShellFish](https://apps.apple.com/us/app/secure-shellfish-sftp-client/id1336634154?mt=openinplace) 
that fully supports opening directories in-place. Opening files in-place should be supported by all file providers.

The excellent [Textastic](https://geo.itunes.apple.com/us/app/id1049254261?ct=textasticapp.com&at=11lNQP&pt=15967&mt=8)
has been [doing](http://blach.io/2016/08/02/opening-git-repository-folders-in-textastic-6-2/) this for a while and so
does [Codea](http://itunes.apple.com/app/id439571171?mt=8), [iA Writer](https://ia.net/writer) and 
[Pythonista](https://apps.apple.com/us/app/pythonista-3/id1085978097?ls=1).
My hope is that providing sample code will encourage others to follow suit. 

A good place to start is at the top of [ListController](OpenInPlace/ListController.swift) and
[EditController](OpenInPlace/EditController.swift).

If you have any questions the easiest way to catch me is on Twitter as [@palmin](https://twitter.com/palmin).
