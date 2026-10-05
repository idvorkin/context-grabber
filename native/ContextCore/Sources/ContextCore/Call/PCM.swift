//  PCM plumbing for the Larry call.
//
//  The voice bridge speaks raw PCM16 little-endian mono: 16 kHz up (the mic), and whatever rate its `ready` frame
//  names down (24 kHz for Gemini and OpenAI, 16 kHz for ElevenLabs). The audio engine on the phone works in
//  Float32 at whatever rate the hardware prefers, so every frame crosses this file once in each direction.
//
//  The resampler is linear interpolation — the same shape as the Cockpit page's `downsampleTo16k` and the
//  bridge's `resample_pcm16`, so a native call and a page call sound the same to Deepgram and to the vendor.

import Foundation

public enum PCM {
  /// The only mic rate the bridge accepts.
  public static let bridgeInRate = 16000.0

  /// Linear-interpolation resample. The input comes back untouched when the rates match.
  public static func resampleLinear(_ input: [Float], from: Double, to: Double) -> [Float] {
    guard from != to, !input.isEmpty else { return input }
    let outLength = max(1, Int((Double(input.count) * to / from).rounded()))
    let step = from / to
    let last = input.count - 1
    var out = [Float](repeating: 0, count: outLength)
    for i in 0..<outLength {
      let pos = Double(i) * step
      let i0 = min(Int(pos), last)
      let i1 = min(i0 + 1, last)
      out[i] = input[i0] + (input[i1] - input[i0]) * Float(pos - Double(i0))
    }
    return out
  }

  /// Float32 [-1, 1] → Int16, clipped.
  public static func floatToPcm16(_ input: [Float]) -> [Int16] {
    input.map { sample in
      let s = max(-1, min(1, sample))
      return Int16((s < 0 ? s * 32768 : s * 32767).rounded())
    }
  }

  /// Int16 little-endian bytes → Float32 [-1, 1]. A trailing odd byte is ignored.
  public static func pcm16ToFloat(_ data: Data) -> [Float] {
    let count = data.count / 2
    var out = [Float](repeating: 0, count: count)
    data.withUnsafeBytes { raw in
      for i in 0..<count {
        let v = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: i * 2, as: Int16.self))
        out[i] = v < 0 ? Float(v) / 32768 : Float(v) / 32767
      }
    }
    return out
  }

  /// True when every sample is exactly zero — a dead capture graph, never a quiet room.
  public static func isExactSilence(_ samples: [Float]) -> Bool {
    !samples.isEmpty && samples.allSatisfy { $0 == 0 }
  }

  /// Quietest level the strip still shows; below this it sits at zero.
  private static let levelFloorDb = -50.0

  /// How loud a mic buffer is, 0…1, on a decibel scale so speech at a normal distance sits mid-strip rather
  /// than pinned near zero the way linear peak would put it. -50 dBFS → 0, 0 dBFS → 1.
  public static func micLevel(_ samples: [Float]) -> Double {
    let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
    guard peak > 0 else { return 0 }
    let db = 20 * log10(Double(min(1, peak)))
    return max(0, min(1, 1 - db / levelFloorDb))
  }

  /// One mic buffer from the engine → one binary frame for the bridge: resampled to 16 kHz, Int16 LE.
  public static func encodeMicFrame(_ samples: [Float], sampleRate: Double) -> Data {
    let pcm = floatToPcm16(resampleLinear(samples, from: sampleRate, to: bridgeInRate))
    return pcm.withUnsafeBufferPointer { buffer in
      var data = Data(capacity: buffer.count * 2)
      for sample in buffer {
        withUnsafeBytes(of: sample.littleEndian) { data.append(contentsOf: $0) }
      }
      return data
    }
  }
}
