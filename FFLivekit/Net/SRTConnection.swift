
import Foundation

public class SRTConnection: Connection {
    
    public init(baseUrl: String) throws {
        guard let url = URL(string: baseUrl), url.scheme == "srt" else {
            throw ConnectionError.SchemeError
        }
        super.init(fileType: FileType.MPEGTS.rawValue, baseUrl: baseUrl)
    }
}
