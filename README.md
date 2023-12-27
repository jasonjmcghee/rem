# <img src="rem/Assets.xcassets/AppIcon.appiconset/AppIcon128x128@2x.png" width=24 /> rem

🧠 Remember everything.

An open source approach to locally record everything you view on your Apple Silicon computer.

_Note: Relies on Apple Silicon, and configured to only produce Apple Silicon builds._

I think the idea of recording everything you see has the potential to change how we interact 
with our computers, and believe it should be open source.

Also, from a privacy / security perspective, this is like... pretty scary stuff, and I want the code open 
so we know for certain that nothing is leaving your laptop. Even logging to Sentry has the potential to 
leak private info.

This is 100% local. Please, read the code yourself.

### This is crazy alpha version
I wrote this in a couple days over the holidays, and if there's one takeaway, it's that I'm a
complete novice at Swift.

## Current supports:
- Going back in time (full-screen scrubber of everything you've viewed)
- Copy text from back in time
- Search everything you've viewed
- Easily grab recent context for use with LLMs

## Things I'd love to add:
- Natural language search / agent interaction via updating local vector embedding
    - [I've also been exploring novel approaches to vector dbs](https://github.com/jasonjmcghee/portable-hnsw)
- Multi-monitor support
