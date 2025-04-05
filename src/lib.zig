const std = @import("std");

pub const util = @import("util.zig");
pub const geo = @import("geo.zig");
pub const weather = @import("weather.zig");

// TODO: get weather data from a suitable api
// STATUS:  use open-meteo free api
// can extract daily hourly and 15 minute data of many attributes
// chose 10 attributes for hourly, daily, TODO: 15 Minute Data
// TODO: Request Specific Time Intervals to save Memory
// TODO: cases where we want multi-data for multi-location? i.e. for image generation on map?

pub const img = @import("img.zig");
pub const osm = @import("osm.zig");
test "all" {
    std.testing.refAllDecls(@This());
}
