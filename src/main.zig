const std = @import("std");
const Allocator = std.mem.Allocator;
pub const AudioPipeline = @import("./AudioPipeline.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    _ = allocator;
    defer _ = gpa.deinit();

    // try audioTest(allocator);
}

pub fn audioTest(allocator: Allocator) !void {
    _ = allocator;

    // const Spectrogram = @import("./audio_utils/Spectrogram.zig");
    // const spectrogram = try Spectrogram.compute(allocator, audio.channel_pcm_buf[0], .{
    //     .sample_rate = audio.sample_rate,
    // });

    // const gui = @import("./gui.zig");
    // try gui.visualizeSpectrogram(allocator, spectrogram);
}

test {
    _ = AudioPipeline;
    _ = @import("./structures/MultiRingBuffer.zig");
    _ = @import("./Evaluator.zig");
}
