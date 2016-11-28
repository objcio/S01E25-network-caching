//: To run this playground start a SimpleHTTPServer on the commandline like this:
//:
//: `python -m SimpleHTTPServer`
//:
//: Or if you are using Python 3:
//:
//: `python -m http.server`
//:
//: It will serve up the current directory, so make sure to be in the directory containing episodes.json

import UIKit
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

var allEpisodes: Resource<[Episode]> = try! Resource(
    url: URL(string: "http://localhost:8000/episodes.json")!,
    parseElement: Episode.init
)

extension Resource {
    var cacheKey: String {
        return "cache" + String(url.hashValue) // TODO use sha1
    }
}

struct FileStorage {
    let baseURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

    subscript(key: String) -> Data? {
        get {
            let url = baseURL.appendingPathComponent(key)
            return try? Data(contentsOf: url)
        }
        set {
            let url = baseURL.appendingPathComponent(key)
            _ = try? newValue?.write(to: url)
        }
    }
}

final class Cache {
    var storage = FileStorage()
    
    func load<A>(_ resource: Resource<A>) -> A? {
        guard case .get = resource.method else { return nil }
        let data = storage[resource.cacheKey]
        return data.flatMap(resource.parse)
    }
    
    func save<A>(_ data: Data, for resource: Resource<A>) {
        guard case .get = resource.method else { return }
        storage[resource.cacheKey] = data
    }
}

final class CachedWebservice {
    let webservice: Webservice
    let cache = Cache()
    
    init(_ webservice: Webservice) {
        self.webservice = webservice
    }
    
    func load<A>(_ resource: Resource<A>, update: @escaping (Result<A>) -> ()) {
        if let result = cache.load(resource) {
            print("cache hit")
            update(.success(result))
        }
        
        let dataResource = Resource<Data>(url: resource.url, parse: { $0 }, method: resource.method)
        webservice.load(dataResource, completion: { result in
            switch result {
            case let .error(error):
                update(.error(error))
            case let .success(data):
                self.cache.save(data, for: resource)
                update(Result(resource.parse(data), or: WebserviceError.other))
            }
        })
    }
}

let webservice = Webservice()
let cachedWebservice = CachedWebservice(webservice)
cachedWebservice.load(allEpisodes) { result in
    print(result)
}
