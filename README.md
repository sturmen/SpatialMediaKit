# SpatialMediaKit

A utility for transforming spatial media.

## Purpose

As of January 2024, Apple's MV-HEVC format for stereoscopic video is very new and barely supported by anything. However, there are millions of iPhones (iPhone 15 Pro/Pro Max) that can capture spatial video already. There was no available FOSS tool capable of splitting the stereo pair, especially not in formats suited for post-production. Upon public request, the ability to create MV-HEVC files from two separate input files was also added.

## Features

1. `Split` takes an MV-HEVC file and outputs the left and right eyes as separate files in the current directory. The output format is ProRes 422 HQ, video only. The user is expected to be familiar with tools such as ffmpeg for all other needs, including remuxing the audio back in.
2. `Merge` takes two video files (left and right) and re-encodes them into a MV-HEVC file. The output is video-only. The user is expected to be familiar with tools such as MP4Box for all other needs, including remuxing the audio back in.

Compared to similar tools:, `SpatialMediaKit` has the following advantages:

- Free as in speech and free as in beer. Other tools are proprietary and often charge fees.
- Splits to ProRes 422 HQ, which is "visually lossless" (Apple's words). Other tools re-encode using lossy HEVC compression in side-by-side, leading to generational quality loss.
- Runs on macOS. To my knowledge, all other existing tools require processing on an iOS device or relying a cloud service, which is a major source of friction in an otherwise streamlined professional workflow.
- Completely, verifiably private. You are free to examine the source code and see that your media never leaves your devices, enabling you to maintain control over your videos.

## Requirements

This has been tested on an M1 Max MacBook Pro running macOS 14.2.1. Hopefully other configurations work, but your mileage may vary.

## Installation

1. Download `spatial-media-kit-tool` from the [releases page](https://github.com/sturmen/SpatialMediaKit/releases)
2. In Terminal, navigate to where you placed the binary and mark it as executable: `chmod +x spatial-media-kit-tool`
3. Copy into your PATH (for example: `sudo cp spatial-media-kit-tool /usr/local/bin`), or leave it in a working directory

In the future I may also try to figure out how to get this added to Homebrew.

## Usage

### `split`

```text
OVERVIEW: Split a single MV-HEVC input into left and right video files.

USAGE: spatial-media-kit-tool split --input-file <input-file> [--output-dir <output-dir>]

OPTIONS:
  -i, --input-file <input-file>
                          The spatial media file to split.
  -o, --output-dir <output-dir>
                          The output directory for the resulting files. If not provided, the current directory will be used.
  --version               Show the version.
  -h, --help              Show help information.
```

### `merge`

```text
OVERVIEW: Merge two video files into a single MV-HEVC file.

USAGE: spatial-media-kit-tool merge [--debug] --left-file <left-file> --right-file <right-file> --quality <quality> [--left-is-primary] [--right-is-primary] --horizontal-field-of-view <horizontal-field-of-view> [--horizontal-disparity-adjustment <horizontal-disparity-adjustment>] --output-file <output-file>

OPTIONS:
  --debug                 Optional. Pause execution at start to allow for time to attach a debugger.
  -l, --left-file <left-file>
                          The left eye media file to merge.
  -r, --right-file <right-file>
                          The right eye media file to merge.
  -q, --quality <quality> Output video quality [0-100]. 50 is a good default value.
  --left-is-primary       Set the left file as the "hero" stream that is displayed when viewing in 2D.
  --right-is-primary      Set the right file as the "hero" stream that is displayed when viewing in 2D.
  --horizontal-field-of-view <horizontal-field-of-view>
                          The field of view of the output video, in degrees. Output will be rounded to the nearest thousandth of a degree. 90.000 is a good default value.
  --horizontal-disparity-adjustment <horizontal-disparity-adjustment>
                          Optional. The horizontal disparity adjustment. The value is a 32-bit integer, measured over the range of -10000 to 10000. Only specify a disparity adjustment, including 0, when you know the specific value.
  -o, --output-file <output-file>
                          The output file to write to. Expects a .MOV extension.
  --version               Show the version.
  -h, --help              Show help information.
```

### Example Usage

You can see an example of how to encode a half-SBS movie file into a spatial video [in the Scripts directory.](Scripts/convert_hsbs.zsh)

## Contributing

I literally do not know Swift (I'm an Android developer) and had to bumble my way through for this project, so apologies for the code organization (or lack thereof). There is also no error handling or anything. Consider this to at most a "proof of concept." PRs welcome!

## Additional Notes

### Special Thanks

This would not have been possible without [this blog post](https://www.finnvoorhees.com/words/reading-and-writing-spatial-video-with-avfoundation) from [Finn Voorhees](https://github.com/finnvoor). Huge thanks! ([archive link](https://web.archive.org/web/20240117091738/https://www.finnvoorhees.com/words/reading-and-writing-spatial-video-with-avfoundation))

### Adding Audio

`ffmpeg` does not maintain Apple's custom spatial video metadata when remuxing. I recommend using [MP4Box](https://github.com/gpac/gpac/wiki/MP4Box). Here's a quick example:

```zsh
brew install mp4box
mp4box -new -add <MV-HEVC video output> -add <additional file with audio> -add <additional file with subtitles> <...> output.mp4
```

You should see output like this:

```text
[iso file] Unknown box type vexu in parent hvc1
[iso file] Unknown box type hfov in parent hvc1
[iso file] Unknown box type vexu in parent hvc1
[iso file] Unknown box type hfov in parent hvc1
```

That's good! Those are the proposed "Spatial Video" metadata boxes that Apple defined [here](https://developer.apple.com/av-foundation/Stereo-Video-ISOBMFF-Extensions.pdf). MP4Box should carry them through to the output, resulting in a file with audio that Apple devices recognize as spatial video.

## Changelog

### v0.0.5-alpha (2024-01-30)

- Made horizontal disparity adjustment optional for Merge.

### v0.0.4-alpha (2024-01-26)

- added "merge"

### v0.0.3-alpha (2024-01-22)

- Renamed project to "SpatialMediaKit"
- Huge refactor, now based on Swift Package Manager
- Automatically determines output resolution based on input resolution
- Reads the source file once and writes both eyes, cutting processing time in half.
- Allows choosing output directory.
- Revamped CLI.
- Added test case

### v0.0.2-alpha (2024-01-21)

Have user specify output dimensions.

### v0.0.1-alpha (2024-01-21)

Initial release.
