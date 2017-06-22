# Open in Place

Minimal example app that illustrates how to get open-in-place to work well with the iOS document pickers.
It shows how to:
- invoke the document picker for files and directories
- use and persist the security scoped URLs the document picker gives you
- how to work with a directory in a coordinated manner to stay in sync
- how to edit a text file in a coordinated manner such that your changes are written safely and such that outside changes appear in the editor automatically.

Using the document picker to open directories will probably only work for a few document providers that happen 
to be Git client. I am the author of [Working Copy](https://workingcopyapp.com/) that supports this as does
[Git2Go](https://git2go.com).

The excellent [Textastic](https://geo.itunes.apple.com/us/app/id1049254261?ct=textasticapp.com&at=11lNQP&pt=15967&mt=8)
has been [doing](http://blach.io/2016/08/02/opening-git-repository-folders-in-textastic-6-2/) this for a while and my hope is that showing a small example will encourage others to follow suit.
