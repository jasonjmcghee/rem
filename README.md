![image](https://github.com/jasonjmcghee/rem/assets/1522149/bc7368dc-90b5-42a3-abba-9d365b368ddb)

# rem

🧠 Remember everything. (very alpha - [download anyway](https://github.com/jasonjmcghee/rem/releases))

---

## 🚨 Looking for contributions / help! 🚨
I would love to keep this project alive and growing, but can't do it alone.

If you're at all interested in contributing, please feel free to reach out, start a discussion, open a PR, look at issues, look at roadmap below, etc.

Something not working properly? There's no telemtry or tracking, so I won't know! Please log an issue or take a crack at fixing it yourself and
submitting a PR! Have feature ideas? Log an issue!

Want to learn more about the code?

Here's the [Generated Wiki](https://wiki.mutable.ai/jasonjmcghee/rem)

---

### Original Demo
<a href="https://www.loom.com/share/091a48b318f04f22bdada62716298948">
  <img style="max-width:300px;" src="https://cdn.loom.com/sessions/thumbnails/091a48b318f04f22bdada62716298948-with-play.gif">
</a>

An open source approach to locally record everything you view on your Mac (prefer other platforms? come help build [xrem](https://github.com/jasonjmcghee/xrem), cross-platform version of this project).

_Note: Only tested on Apple Silicon, but [there is now an intel build](https://github.com/jasonjmcghee/rem/releases)

---

### This is an early version (rem could use _your_ help!)

Please log any bugs / issues you find!

Looking at this code and grimacing? Want to help turn this project into something awesome? Please contribute. I haven't written Swift since 2017. I'm sure you'll write better code than me.

---

I think the idea of recording everything you see has the potential to change how we interact
with our computers, and believe it should be open source.

Also, from a privacy / security perspective, this is like... pretty scary stuff, and I want the code open
so we know for certain that nothing is leaving your laptop. Even telemetry has the potential to
leak private info.

This is 100% local. Please, read the code yourself.

Also, that means there is no tracking / analytics of any kind, which means I don't know you're running into bugs when you do. So please report any / all you find!

## Features:
- [x] Automatically take a screenshot every 2 seconds, recognizing all text, using an efficient approach in terms of space and energy
- [x] Go back in time (full-screen scrubber of everything you've viewed)
- [x] Copy text from back in time
- [x] Search everything you've viewed with keyword search (and filter by application)
- [x] Easily grab recent context for use with LLMs
- [x] [Intel build](https://github.com/jasonjmcghee/rem/releases) (please help test!)
- [x] It "works" with external / multiple monitors connected
- [ ] Natural language search / agent interaction via updating local vector embedding
    - [I've also been exploring novel approaches to vector dbs](https://github.com/jasonjmcghee/portable-hnsw)
- [ ] Novel search experiences like spatial / similar images
- [ ] More search filters (by time, etc.)
- [ ] Fine-grained purging / trimming / selecting recording
- [ ] Better / First-class multi-monitor support

## Getting Started

- [Download the latest release](https://github.com/jasonjmcghee/rem/releases), or build it yourself!
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
- Click "Show Me My Data" to open a finder window where `rem` stores SQLite db + video recordings
- Click "Purge All Data" to delete everything (useful if something breaks)

(that should be all that's needed)

## Build it yourself

- Clone the repo `git clone --recursive -j8 https://github.com/jasonjmcghee/rem.git` or run `git submodule update --init --recursive` after cloning
- Open project in Xcode
- Product > Archive
- Distribute App
- Custom
- Copy App

### FAQ
- Where is my data?
    - Click "Show Me My Data" in the tray / status icon menu
    - Currently it is stored in: `~/Library/Containers/today.jason.rem/Data/Library/Application Support/today.jason.rem`
    - It was originally: `~/Library/Application\ Support/today.jason.rem/`

### (Never)AQ
- Wow that logo is so great, you're an artist. Can I see your figma?
    - So nice of you to say, sure [here it is](https://www.figma.com/file/Rr2vUXjsRb9SJMssQbEllA/rem-icons?type=design&node-id=0%3A1&mode=design&t=QhtJ7L1z4rIXTG4M-1)

### XCode + copy / paste from history:

https://github.com/jasonjmcghee/rem/assets/1522149/97acacb9-b8c6-4b9c-b452-5423fb4e4372
