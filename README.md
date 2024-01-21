# mvhevcsplit

 Split a MV-HEVC file into separate left and right ProRes files.

## Purpose

As of January 2024, Apple's MV-HEVC format for stereoscopic video is very new and barely supported by anything. However, there are millions of iPhones (iPhone 15 Pro/Pro Max) that can capture spatial video already. There was no available FOSS tool capable of splitting the stereo pair, especially not in formats suited for post-production.

## Features

There is only one feature: it takes an MV-HEVC file and outputs the left and right eyes as separate files in the current directory. The output format is ProRes 422 HQ, video only. The user is expected to be familiar with tools such as ffmpeg for all other needs, including remuxing the audio back in.

## Requirements

This has been tested on an M1 Max MacBook Pro running macOS 14.2.1 with [Pro Video Formats 2.3](https://support.apple.com/kb/DL2100?viewlocale=en_US&locale=en_US). Hopefully other configurations work, but your mileage may vary.

## Installation

1. Download `mvhevcsplit` from the releases
2. In Terminal, navigate to where you placed the binary and mark it as executable: `chmod +x mvhevcsplit`
3. Copy into your PATH (for example: `sudo cp mvhevcsplit /usr/local/bin`), or leave it in a working directory

In the future I may also try to figure out how to get this added to Homebrew.

## Usage

In Terminal: `mvhevcsplit 1920 1080 MOV_0001.MOV`

`output_left.mov` and `output_right.mov`, if they already exist, **will be deleted** and then new files with those names will be written to the current directory.

## Contributing

I literally do not know Swift (I'm an Android developer) and had to bumble my way through for this project, so apologies for the code organization (or lack thereof). There is also no error handling or anything. Consider this to at most a "proof of concept." PRs welcome!

## Additional Notes

This would not have been possible without [this blog post](https://www.finnvoorhees.com/words/reading-and-writing-spatial-video-with-avfoundation) from [Finn Voorhees](https://github.com/finnvoor). Huge thanks! ([archive link](https://web.archive.org/web/20240117091738/https://www.finnvoorhees.com/words/reading-and-writing-spatial-video-with-avfoundation))

## Changelog

### v0.0.2-alpha (2024-01-21)

Have user specify output dimensions.

### v0.0.1-alpha (2024-01-21)

Initial release.
