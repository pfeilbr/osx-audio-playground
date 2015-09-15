//: Playground - noun: a place where people can play

import Cocoa
import XCPlayground
import AVFoundation

XCPSetExecutionShouldContinueIndefinitely(true)

extension NSStream {
    
    /// Creates an input/output stream pair that are bound together using a buffer of size bufferSize.
    /// Data written to outputStream will be received by inputStream, and vice versa.
    class func boundStreamsWithBufferSize(bufferSize: Int) ->
        (inputStream: NSInputStream, outputStream: NSOutputStream) {
            var readStream: Unmanaged<CFReadStream>?;
            var writeStream: Unmanaged<CFWriteStream>?;
            CFStreamCreateBoundPair(nil, &readStream, &writeStream, bufferSize)
            return (readStream!.takeUnretainedValue(), writeStream!.takeUnretainedValue())
    }
}

class AudioProcessor : NSObject, NSStreamDelegate {
    let documentsDir = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
    let audioEngine = AVAudioEngine()
    let audioFilePlayer = AVAudioPlayerNode()
    var audioFormat:AVAudioFormat?
    var outputStream:NSOutputStream?
    var inputStream:NSInputStream?
    var bufferArray = [NSData]()
    
    override init(){
        super.init()
    }
    
    func run() {
    
        // setup an output stream that is linked to an input stream
        let (inStream, outStream) = NSStream.boundStreamsWithBufferSize(4096)
        
        outputStream = outStream
        outputStream?.delegate = self
        outputStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        outputStream?.open()
        
        inputStream = inStream
        inputStream?.delegate = self
        inputStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        inputStream?.open()
        
        guard let inputNode = audioEngine.inputNode else { return }
        let bus = 0 // microphone
        audioFormat = inputNode.inputFormatForBus(bus)
        print("audioFormat?.channelCount = \(audioFormat?.channelCount)")
        inputNode.installTapOnBus(bus, bufferSize: 2048, format: audioFormat) {
            (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
            let data = self.toNSData(buffer)
            self.bufferArray.append(data)
            guard let outStream = self.outputStream else { return }
            if (outStream.hasSpaceAvailable) {
                print("NSStreamEvent.HasSpaceAvailable")
                while (!self.bufferArray.isEmpty) {
                    let data = self.bufferArray.removeFirst()
                    print("data.length = \(data.length)")
                    outStream.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
                }
            }
                        
            //print("data.length = \(data.length)")
            /*
            print("buffer.frameLength = \(buffer.frameLength)")
            print("time.sampleTime = \(time.sampleTime)")
            print("time.sampleRate = \(time.sampleRate)")
            */
            let delay = AVAudioTime.secondsForHostTime(mach_absolute_time()) + 2
            //self.audioFilePlayer.scheduleBuffer(buffer, completionHandler: nil)
            //self.audioFilePlayer.scheduleBuffer(buffer, atTime: AVAudioTime(hostTime: mach_absolute_time()), options: .Loops, completionHandler: nil)
            self.audioFilePlayer.scheduleBuffer(self.toPCMBuffer(data), atTime: AVAudioTime(hostTime: AVAudioTime.hostTimeForSeconds(delay)), options: .Loops, completionHandler: nil)
            

        }
        
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.attachNode(audioFilePlayer)
        audioEngine.connect(audioFilePlayer, to:mainMixer, format: nil)
        
        audioEngine.prepare()

        try! audioEngine.start()
        
        audioFilePlayer.play()

        
        print("started audio")
    }
    
    @objc func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.HasSpaceAvailable:
            //print("NSStreamEvent.HasSpaceAvailable")
            /*
            while (!bufferArray.isEmpty) {
                let data = bufferArray.removeFirst()
                guard let out = aStream as? NSOutputStream else { return }
                out.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
            }
            */
            break
        case NSStreamEvent.HasBytesAvailable:
            print("NSStreamEvent.HasBytesAvailable")
            guard let inStream = aStream as? NSInputStream else { return }
            
            while (inStream.hasBytesAvailable) {
                print("inStream.hasBytesAvailable = \(inStream.hasBytesAvailable)")
                guard let data = NSMutableData(length: 4096) else { return }
                let bytesRead = inStream.read(UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: 4096)
                print("bytesRead = \(bytesRead)")
                print("inStream.hasBytesAvailable = \(inStream.hasBytesAvailable)")
            }
            break
        default: break
        }
    }
    
    func toNSData(PCMBuffer: AVAudioPCMBuffer) -> NSData {
        let channelCount = audioFormat?.channelCount
        let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: Int(channelCount!))
        let ch0Data = NSData(bytes: channels[0], length:Int(PCMBuffer.frameCapacity * PCMBuffer.format.streamDescription.memory.mBytesPerFrame))
        return ch0Data
    }
    
    func toPCMBuffer(data: NSData) -> AVAudioPCMBuffer {
        //let audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.PCMFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)  // given NSData audio format
        let PCMBuffer = AVAudioPCMBuffer(PCMFormat: audioFormat!, frameCapacity: UInt32(data.length) / audioFormat!.streamDescription.memory.mBytesPerFrame)
        PCMBuffer.frameLength = PCMBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: Int(PCMBuffer.format.channelCount))
        data.getBytes(UnsafeMutablePointer<Void>(channels[0]) , length: data.length)
        return PCMBuffer
    }
    
}

// records samples from the microphone and plays them back
let ap = AudioProcessor()
ap.run()


