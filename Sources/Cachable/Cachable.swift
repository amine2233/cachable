public protocol Cachable {
    var fileName: String { get }
    func transform() throws -> Data
}

public enum CacherError: Error {
    case transform(Error)
    case load(Error)
    case createDirectory(CacheDestination, Error)
}

public enum CacheDestination {
    case temporary
    case atFolder(String)
}

public protocol FileManagerProtocol {
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
}

extension FileManager: FileManagerProtocol {}

public final class Cacher {
    public let destination: URL
    public let fileManager: FileManagerProtocol
    private let queue = OperationQueue()

    // MARK: Initialization

    public init(destination: CacheDestination, fileManager: FileManagerProtocol = FileManager.default) throws {
        switch destination {
        case .temporary:
            self.destination = URL(fileURLWithPath: NSTemporaryDirectory())
        case let .atFolder(folder):
            let documentFolder = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            self.destination = URL(fileURLWithPath: documentFolder).appendingPathComponent(folder, isDirectory: true)
        }

        self.fileManager = fileManager

        do {
            try fileManager.createDirectory(at: self.destination, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw CacherError.createDirectory(destination, error)
        }
    }

    // MARK: Methods

    public func persist(item: Cachable, completion: @escaping (Result<URL, CacherError>) -> Void) {
        let url = destination.appendingPathComponent(item.fileName, isDirectory: false)

        // Create an operation to process the request
        let operation = BlockOperation {
            do {
                try item.transform().write(to: url, options: [.atomicWrite])
            } catch {
                completion(.failure(CacherError.transform(error)))
            }
        }

        // Set the operation's completion block to call the request's completion handler.
        operation.completionBlock = {
            completion(.success(url))
        }

        // Add the operation to the queue to start the work.
        queue.addOperation(operation)
    }

    public func load<T: Cachable & Codable>(fileName: String) throws -> T {
        do {
            let data = try Data(contentsOf: destination.appendingPathComponent(fileName, isDirectory: false))
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CacherError.load(error)
        }
    }

    public func load<T: Cachable>(fileName: String, completion: (Data) throws -> T) throws -> T {
        do {
            let data = try Data(contentsOf: destination.appendingPathComponent(fileName, isDirectory: false))
            return try completion(data)
        } catch {
            throw CacherError.load(error)
        }
    }
}

extension Cachable where Self: Codable {
    public func transform() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
