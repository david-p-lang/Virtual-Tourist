//
//  API.swift
//  VirtualTourist
//
//  Created by David Lang on 6/18/19.
//  Copyright © 2019 David Lang. All rights reserved.
//

import Foundation
import UIKit

class Constants {
    static let albumSegue = "albumSegue"
    static let flickerCell = "flickrCell"
    static let apiKey = "e79e37db8c17fb8f7b009ea28a20cb4c"
}

struct FlickrSearchResult: Codable {
    let photos: FlickrPagesResult?
    let stat: String
}

struct FlickrPagesResult: Codable {
    let photo: [FlickrUrl]
    let page: Int
    let pages: Int
    let perpage: Int
    let total: String
}

struct FlickrUrl: Codable {
    let id: String
    let farm: Int
    let owner: String
    let secret: String
    let server: String
    let title: String
}

class Flickr {
    
    var session: URLSession?
    
    func buildDataTask( url: URL,
        //parameters: [String:String],
        session: URLSession,
        completion: @escaping (Any?, Error?) -> Void
        ) -> URLSessionDataTask {
        
        var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        return session.dataTask(with: request, completionHandler: { (data, response, error) in
            guard let data = data, error == nil else {
                completion(nil, error)
                return
            }
            
            completion(data, nil)
        })
    }
    
    func buildLocationQuery() -> URL {
        let latString = String(35.0)
        let lonString = String(40.0)
        var components = URLComponents()
        let queryItemLatitude = URLQueryItem(name: "lat", value: latString)
        let queryItemLongitude = URLQueryItem(name: "lon", value: lonString)
        let queryItemPerPage = URLQueryItem(name: "per_page", value: "25")
        let queryItemMethod = URLQueryItem(name: "method", value: "flickr.photos.search")
        let queryItemAPIKey = URLQueryItem(name: "api_key", value: Constants.apiKey)
        let queryItemFormat = URLQueryItem(name: "format", value: "json")
        let queryItemCallback = URLQueryItem(name: "nojsoncallback", value: "1")
        components.scheme = "https"
        components.host = "api.flickr.com"
        components.path = "/services/rest"
        components.queryItems = [queryItemMethod, queryItemAPIKey, queryItemLongitude, queryItemLatitude, queryItemFormat, queryItemPerPage, queryItemCallback]
        return components.url!
    }
    
    func requestImageResourceLocations(session: URLSession, completion: @escaping ((FlickrSearchResult?, Error?) -> Void)) {
        let url = buildLocationQuery()
        let task = buildDataTask(url: url, session: session) { (data, error) in
            guard error == nil, let data = data else {
                completion(nil, error!)
                return
            }
            
            let flickrSearchDecoder = JSONDecoder()
            do {
                let flickrResponseData = try flickrSearchDecoder.decode(FlickrSearchResult.self, from: data as! Data)
                completion(flickrResponseData, nil)
            } catch {
                completion(nil, error)
            }
        }
        
        task.resume()
    }
    
    
}
