# <img src="rem/Assets.xcassets/AppIcon.appiconset/AppIcon128x128@2x.png" width=24 /> rem

🧠 Remember everything. (very alpha)

### Original Demo
<a href="https://www.loom.com/share/091a48b318f04f22bdada62716298948">
  <img style="max-width:300px;" src="https://cdn.loom.com/sessions/thumbnails/091a48b318f04f22bdada62716298948-with-play.gif">
</a>

An open source approach to locally record everything you view on your Apple Silicon computer.

_Note: Only tested on Apple Silicon, and the release is Apple Silicon._

---

Please log any bugs / issues you find!

Working on getting the build code signed / official... fighting with hardened runtime + bundled ffmpeg.

Looking at this code and grimacing? Want to help turn this project into something awesome? Please contribute. I haven't written Swift since 2017. I'm sure you'll write better code than me.

---

I think the idea of recording everything you see has the potential to change how we interact
with our computers, and believe it should be open source.

Also, from a privacy / security perspective, this is like... pretty scary stuff, and I want the code open
so we know for certain that nothing is leaving your laptop. Even logging to Sentry has the potential to
leak private info.

This is 100% local. Please, read the code yourself.

### This is crazy alpha version

I wrote this in a couple days over the holidays, and if there's one takeaway, it's that I'm a
complete novice at Swift.

## Build it yourself

- Clone the repo `git clone --recursive -j8 https://github.com/jasonjmcghee/rem.git` or run `git submodule update --init --recursive` after cloning
- Open project in Xcode
- Change default SQLite.Swift sdk archiecture to macOS <img width="1512" alt="Screenshot 2023-12-28 at 5 38 19 PM" src="https://github.com/ruslanjabari/rem/assets/59275080/63c08975-0bd2-4fe8-91ca-0b9406d44704">
- Product > Archive
- Distribute App
- Custom
- Copy App

## Getting Started

- Download `0.1.4` or later (previous are unsigned), or build it yourself!
- Launch the app
- Click the brain
- Click "Start Remembering"
- Grant it access to "Screen Recording" i.e. take screenshots every 2 seconds
- Click "Open timeline" or "Cmd + Scroll Up" to open the timeline view
    - Scroll left or right to move in time
- Click "Search" to open the search view
    - Search your history and click on a thumbnail to go there in the timeline
- In timeline, give Live Text a second and then you can select text
- Click "Copy Recent Context" to grab a prompt for interacting with an LLM with what you've seen recently as context
- Click "Purge All Data" to delete everything (useful if something breaks)

(that should be all that's needed)

## Current supports:
- Going back in time (full-screen scrubber of everything you've viewed)
- Copy text from back in time
- Search everything you've viewed
- Easily grab recent context for use with LLMs

## Things I'd love to add:
- Natural language search / agent interaction via updating local vector embedding
    - [I've also been exploring novel approaches to vector dbs](https://github.com/jasonjmcghee/portable-hnsw)
- Multi-monitor support

## Contributors ✨
<a href="https://github.com/jasonjmcghee/rem/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=jasonjmcghee/rem" />
</a>

### FAQ
- Where is my data?
    - It was originally: `~/Library/Application\ Support/today.jason.rem/`
    - After turning on app sandbox, appears to now be in: `~/Library/Containers/today.jason.rem/Data/Library/Application Support/today.jason.rem`

### XCode + copy / paste from history:

https://github.com/jasonjmcghee/rem/assets/1522149/97acacb9-b8c6-4b9c-b452-5423fb4e4372
