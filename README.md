# Open in Place

Minimal example app that illustrates how to get open-in-place to work well with iOS document pickers.

It shows how to:
- invoke the document picker in open mode for files and directories
- use and persist the security scoped URLs the document picker gives you
- work with a directory in a coordinated manner to stay in sync
- edit a text file in a coordinated manner such that your changes are written safely and such that outside changes appear in the editor automatically.

Using the document picker to open directories will probably only work for a few document providers that happen 
to be Git clients. 
I am the author of [Working Copy](https://itunes.apple.com/us/app/working-copy/id896694807?mt=8&uo=6&at=1000lHq&ct=) 
that supports this as does
[Git2Go](https://itunes.apple.com/us/app/git2go-git-client-you-always/id963577401?mt=8).

Opening files and file packages (directories masquarading as files) should work for iCloud Drive and other well behaved document providers.

The excellent [Textastic](https://geo.itunes.apple.com/us/app/id1049254261?ct=textasticapp.com&at=11lNQP&pt=15967&mt=8)
has been [doing](http://blach.io/2016/08/02/opening-git-repository-folders-in-textastic-6-2/) this for a while and my hope is that providing this sample code will encourage others to follow suit.

I am [@palmin](https://twitter.com/palmin) on Twitter.
