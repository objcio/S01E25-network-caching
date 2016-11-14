//: To run this playground start a SimpleHTTPServer on the commandline like this:
//:
//: `python -m SimpleHTTPServer`
//:
//: It will serve up the current directory, so make sure to be in the directory containing episodes.json

import UIKit
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true


var allEpisodes: Resource<[Episode]> = try! Resource(
    url: URL(string: "http://localhost:8000/episodes.json")!,
    parseElement: Episode.init
)

let webservice = Webservice()

struct FileStorage {
    let baseURL: URL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    subscript(key: String) -> Data? {
        get { return try? Data(contentsOf: baseURL.appendingPathComponent(key)) }
        set {
            let url = baseURL.appendingPathComponent(key)
            try? newValue?.write(to: url)
        }
    }
}

extension Resource {
    var cacheKey: String {
        return "cache" + String(url.hashValue)
    }
}

final class Cache {
    var storage = FileStorage()
    
    init() {}
    
    func load<A>(_ resource: Resource<A>) -> A? {
        guard case .get = resource.method else { return nil }
        return storage[resource.cacheKey].flatMap(resource.parse)
    }
    
    func save<A>(_ data: Data, for resource: Resource<A>) {
        guard case .get = resource.method else { return }
        storage[resource.cacheKey] = data
    }
}

public final class CachedWebservice {
    private let webservice: Webservice
    private let cache = Cache()
    
    public init(webservice: Webservice) {
        self.webservice = webservice
    }
    
    public func load<A>(_ resource: Resource<A>, update: @escaping (Result<A>) -> ()) {
        if let result = cache.load(resource) {
            print("Cache hit")
            update(.success(result))
        }
        
        let dataResource = Resource<Data>(url: resource.url, parse: { data in data }, method: resource.method)
        webservice.load(dataResource) { result in
            switch result {
            case let .success(data):
                print("Network load succeeded")
                self.cache.save(data, for: resource)
                update(Result(resource.parse(data), or: WebserviceError.other))
            case let .error(err):
                update(.error(err))
            }
        }
    }
}

let cachedWS = CachedWebservice(webservice: webservice)
cachedWS.load(allEpisodes) { print($0) }


