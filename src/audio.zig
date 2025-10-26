const std = @import("std");
const rl = @import("raylib");
const Evaluator = @import("evaluator.zig").Evaluator;
const SampleRate = @import("evaluator.zig").SampleRate;

pub const AudioSystem = struct {
    stream: rl.AudioStream,
    evaluator: *Evaluator,
    time: u32 = 0,
    current_rate: SampleRate,
    muted: bool = false,

    pub fn init(evaulator: *Evaluator)!AudioSystem {
        const hz = sampleRateToHz(evaulator.config.sample_rate);
        const stream = try rl.loadAudioStream(hz, 16, 1);
        const self = AudioSystem{
            .stream = stream,
            .evaluator = evaulator,
            .current_rate = evaulator.config.sample_rate,
            .muted = false,
        };

        rl.setAudioStreamCallback(stream, audioCallback);
        return self;
    }

    pub fn activate(self: *AudioSystem) void {
        setGlobal(self);
    }

    pub fn deinit(self: *AudioSystem) void {
           rl.unloadAudioStream(self.stream);
           clearGlobal();
       }

       pub fn play(self: *AudioSystem) void {
           rl.playAudioStream(self.stream);
       }

       pub fn stop(self: *AudioSystem) void {
           rl.stopAudioStream(self.stream);
       }

       pub fn isPlaying(self: *const AudioSystem) bool {
           return rl.isAudioStreamPlaying(self.stream);
       }

       pub fn setMuted(self: *AudioSystem, muted: bool) void {
           self.muted = muted;
       }

       pub fn isMuted(self: *const AudioSystem) bool {
           return self.muted;
       }

       pub fn reset(self: *AudioSystem) void {
           self.time = 0;
       }

       pub fn getTime(self: *const AudioSystem) u32 {
           return self.time;
       }

       pub fn getSampleRate(self: *const AudioSystem) u32 {
           return sampleRateToHz(self.current_rate);
       }

       pub fn setSampleRate(self: *AudioSystem, rate: SampleRate) void {
           if (rate == self.current_rate) return;

           const was_playing = rl.isAudioStreamPlaying(self.stream);
           rl.stopAudioStream(self.stream);
           rl.unloadAudioStream(self.stream);

           const hz = sampleRateToHz(rate);
           self.stream = rl.loadAudioStream(hz, 16, 1);
           self.current_rate = rate;
           self.evaluator.setSampleRate(rate);

           rl.setAudioStreamCallback(self.stream, audioCallback);
           if (was_playing) rl.playAudioStream(self.stream);
       }

    fn sampleRateToHz(rate: SampleRate) u32 {
        return switch (rate) {
            .rate_8000 => 8000,
                      .rate_11000 => 11000,
                      .rate_22000 => 22000,
                      .rate_32000 => 32000,
                      .rate_44100 => 44100,
                      .rate_48000 => 48000,
        };
    }
};

var g_audio: ?*AudioSystem = null;

pub fn setGlobal(system: *AudioSystem) void {
    g_audio = system;
}

fn clearGlobal() void {
    g_audio = null;
}

export fn audioCallback(buffer_ptr: ?*anyopaque, frames: c_uint) callconv(.c) void {
      const system = g_audio orelse return;
      const buffer = @as([*]i16, @ptrCast(@alignCast(buffer_ptr)));

      const frame_count: usize = @intCast(frames);

      if (system.muted) {
          const samples = buffer[0..frame_count];
          @memset(samples, 0);
          const frames_u32: u32 = @intCast(frame_count);
          system.time +%= frames_u32;
          return;
      }

      for (0..frame_count) |i| {
          const value = system.evaluator.evaluate(system.time) catch 0.0;
          const sample = switch (system.evaluator.config.beat_type) {
              .bytebeat => convertBytebeat(value),
              .floatbeat => convertFloatbeat(value),
          };

          buffer[i] = sample;
          system.time += 1;
      }
  }

  fn convertBytebeat(x: f32) i16 {
      const i32_max_f32 = @as(f32, @floatFromInt(std.math.maxInt(i32)));
      const i32_min_f32 = @as(f32, @floatFromInt(std.math.minInt(i32)));
      const bounded = std.math.clamp(x, i32_min_f32, i32_max_f32);
      const raw: i32 = @intFromFloat(bounded);
      const wrapped: u8 = @intCast(@mod(raw, 256));
      const centered: i16 = @as(i16, wrapped) - 128;
      return centered * 256;
  }

  fn convertFloatbeat(x: f32) i16 {
      const clamped = std.math.clamp(x, -1.0, 1.0);
      return @intFromFloat(clamped * 32767.0);
  }
