
import Foundation

public class UDPConnection: Connection {
    
    public init(baseUrl: String) throws {
        guard let url = URL(string: baseUrl), url.scheme == "udp" else {
            throw ConnectionError.SchemeError
        }
        super.init(fileType: FileType.MPEGTS.rawValue, baseUrl: baseUrl)
    }
}
