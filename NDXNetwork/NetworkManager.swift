//
//  NetworkManager.swift
//  NDXNetwork
//
//  Created by RajanAR21 on 1/6/20.
//  Copyright © 2020 RajanAR21. All rights reserved.
//

import Foundation
import NDXDataModel

public enum APIError : Error {
    case networkingError(Error)
    case clientError
    case serverError
    case requestError(Int, String)
    case invalidResponse
    case decodingError(DecodingError)
}

public struct Response: Decodable {
    public let feed: Feed
}

public struct Feed: Decodable {
    public let results: [AlbumsResult]
}

public class NetworkManager {
    
    public static let sharedInstance = NetworkManager()

    private var urlSession: URLSession = URLSession(configuration: .default)
    private init() {}

    //get rss feed of top 100 albums
    public func getRSSFeed(maxList: Int = 100, urlString: String, completion: @escaping (Result<Response, APIError>) -> Void ) {
        //urlSession = URLSession(configuration: .default)
        if let url = URL(string: urlString) {
            perform(request: URLRequest(url: url), completion: parseDecodable(completion: completion))
        }
    }

    //make url request to Apple's rss feed service
    private func perform(request: URLRequest, completion: @escaping (Result<Data, APIError>) -> Void) {
        let task = urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkingError(error)))
                return
            }
            
            guard let http = response as? HTTPURLResponse, let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            switch http.statusCode {
            case 200:
                completion(.success(data))
            case 300...499:
                completion(.failure(.clientError))
            case 500...599:
                completion(.failure(.serverError))
            default:
                fatalError("Unhandled HTTP status code: \(http.statusCode)")
            }
        }
        task.resume()
    }
    
    //parse response data into model objects
    private func parseDecodable<T : Decodable>( completion: @escaping (Result<T, APIError>) -> Void) -> (Result<Data, APIError>) -> Void {
        return { result in
            switch result {
            case .success(let data):
                do {
                    let jsonDecoder = JSONDecoder()
                    let object = try jsonDecoder.decode(T.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(object))
                    }
                } catch let decodingError as DecodingError {
                    DispatchQueue.main.async {
                        completion(.failure(.decodingError(decodingError)))
                    }
                }
                catch {
                    fatalError("Unhandled error raised.")
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
