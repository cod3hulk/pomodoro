import AVFoundation
import Foundation

@MainActor
final class TickSound {
    private var player: AVAudioPlayer?

    init() {
        let rate = 22_050
        let count = rate / 40
        var data = Data()
        func append16(_ value: UInt16) {
            data.append(UInt8(truncatingIfNeeded: value))
            data.append(UInt8(truncatingIfNeeded: value >> 8))
        }
        func append32(_ value: UInt32) {
            append16(UInt16(truncatingIfNeeded: value))
            append16(UInt16(truncatingIfNeeded: value >> 16))
        }
        data.append(contentsOf: "RIFF".utf8)
        append32(UInt32(36 + count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8)
        append32(16)
        append16(1) // PCM
        append16(1) // mono
        append32(UInt32(rate))
        append32(UInt32(rate * 2))
        append16(2)
        append16(16)
        data.append(contentsOf: "data".utf8)
        append32(UInt32(count * 2))
        for i in 0..<count {
            let t = Double(i) / Double(rate)
            let envelope = exp(-t * 190)
            let sample = Int16(10_000 * envelope * sin(2 * .pi * 1_250 * t))
            append16(UInt16(bitPattern: sample))
        }
        player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
    }

    func play() {
        player?.currentTime = 0
        player?.play()
    }
}
