# OSMR

## osm maps tile renderer in zig

want to render maps similar to i.e. google maps?

## features

- decoding of open map tiles using zig-protobuf[https://github.com/Arwalk/zig-protobuf]
- rendering with z2d[https://github.com/vancluever/z2d]

## usage

get a map tile i.e. from maptiler or self hosted tile server use

```zig
const maptiler = @import("osmr").maptiler;
...
```

dig deeper into the tile data with the decoder

```zig
const decoder = @import("osmr").decoder;
...
```

implement custom maps rendering by looking at:

```zig
const renderer = @import("osmr").renderer;
...
```

# licence

MIT
