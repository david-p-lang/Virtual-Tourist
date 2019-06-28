//
//  ViewController.swift
//  VirtualTourist
//
//  Created by David Lang on 6/11/19.
//  Copyright © 2019 David Lang. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class AlbumViewController: UIViewController {

    var flickrSearchResult: FlickrSearchResult?
    var currentPin:Pin!
    var photoResultsController:NSFetchedResultsController<Photo>!
    let delegate = UIApplication.shared.delegate as! AppDelegate
    var pages = 0
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self        
    }
        
    override func viewWillAppear(_ animated: Bool) {
        getFlickrPhotos()
        placePin()
        buildFetchRequest()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        photoResultsController = nil
    }
    
    fileprivate func placePin() {
        let pin = MKPointAnnotation()
        let spanForRegion = MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        pin.coordinate = CLLocationCoordinate2D(latitude: currentPin.latitude, longitude: currentPin.longitude)
        mapView.addAnnotation(pin)
        mapView.setRegion(MKCoordinateRegion(center: pin.coordinate, span: spanForRegion), animated: true)
    }
    
    func buildFetchRequest() {
        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        fetchRequest.sortDescriptors = []
        fetchRequest.predicate = NSPredicate(format: "pin == %@", currentPin)
        photoResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: DataController.shared.mainContext,
            sectionNameKeyPath: nil,
            cacheName: nil
            )
        photoResultsController!.delegate = self
        do {
            try photoResultsController!.performFetch()
        } catch {
            displayAlert(error)
        }
    }
    
    func getFlickrPhotos() {
        guard let flickerUrls = flickrSearchResult?.photos?.photo else {return}
        for flickrUrl in flickerUrls {
            if let url = Flickr.buildImageUrlString(flickrUrl) {
                guard let entity = NSEntityDescription.entity(forEntityName: "Photo", in: DataController.shared.mainContext) else {return}
                let photo = Photo(entity: entity, insertInto: DataController.shared.mainContext)
                photo.url = url.absoluteString
                currentPin.addToPhoto(photo)
                try? DataController.shared.mainContext.save()
            }
        }
    }

    fileprivate func deletePhotos() {
        photoResultsController.fetchedObjects?.forEach({ (photo) in
            DataController.shared.mainContext.delete(photo)
            try? DataController.shared.mainContext.save()
        })
    }
    
    /// Aquire a radomized page number of less than 100
    ///
    /// - Returns: Integer limited by the pages result or <100 if pages is greater.
    func getRandomResultPage() -> Int {
        if pages > 99 {
            pages = 99
        }
        return Int.random(in: 1...pages)
    }
    
    @IBAction func refresh(_ sender: Any) {
        deletePhotos()
        let coordinate = [
            Constants.latKey:currentPin.latitude,
            Constants.lonKey:currentPin.longitude
        ]
        let resultPage = getRandomResultPage()
        Flickr.requestImageResourceLocations(
            coord: coordinate,
            pageNumber: resultPage
            ) { (flickrSearchResult, error) in
            guard let flickrSearchResult = flickrSearchResult, error == nil else {return}
            self.flickrSearchResult = flickrSearchResult
            self.getFlickrPhotos()
        }
        try? DataController.shared.mainContext.save()
    }
}

extension AlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let number = photoResultsController?.sections?[section].numberOfObjects ?? 0
        if number == 0 && (flickrSearchResult?.photos?.photo.count) == 0 {
            self.collectionView.setEmptyMessage("No Images")
        } else {
            self.collectionView.restore()
        }
        return number
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.flickerCell, for: indexPath) as! FlickrImageCell
        
        //prepare cell for load/download
        cell.imageView.image = UIImage(named: Constants.placeholderKey)
        cell.activityIndicator.isHidden = false
        cell.activityIndicator.startAnimating()
        
        //Aquire photo data and url if available
        guard let photo = photoResultsController?.object(at: indexPath) else {return cell}
        guard let photoUrl = photo.url else {return cell}
        guard let photoData = photo.data else {
            
            //Photo's data is nil so download
            Flickr.requestImage(urlString: photoUrl) { (image, error) in
                guard error == nil, let image = image else {
                    self.displayAlert(error ?? ConnectionError.connectionFailure)
                    return
                }
                DispatchQueue.main.async {
                    guard let imageData = image.jpegData(compressionQuality: 1.0) else { return }
                    photo.data = imageData
                    do {
                        try DataController.shared.mainContext.save()
                    } catch {
                        self.displayAlert(error)
                    }
                    cell.imageView.image = image
                    cell.activityIndicator.stopAnimating()
                    cell.activityIndicator.isHidden = true
                }
            }
            return cell
        }
        
        //Load from stored data
        cell.imageView.image = UIImage(data: photoData)
        cell.activityIndicator.stopAnimating()
        cell.activityIndicator.isHidden = true
        return cell
    }
    
    //The user remove photos from the album by tapping the image
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photo = photoResultsController.object(at: indexPath)
        DataController.shared.mainContext.delete(photo)
    }
}

extension AlbumViewController: NSFetchedResultsControllerDelegate {

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        if type == .insert {
            guard let newIndexPath = newIndexPath else {return}
            collectionView.insertItems(at: [newIndexPath])
        } else if type == .update {
            guard let indexPath = indexPath else {return}
            collectionView.reloadItems(at: [indexPath])
        } else if type == .delete {
            guard let indexPath = indexPath else {return}
            collectionView.deleteItems(at: [indexPath])
        }
    }
}

//Modified from Reply: Samman Bikram Thapa
//https://stackoverflow.com/questions/43772984/how-to-show-a-message-when-collection-view-is-empty
extension UICollectionView {
    
    func setEmptyMessage(_ message: String) {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height))
        messageLabel.text = message
        messageLabel.textColor = .black
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.sizeToFit()
        self.backgroundView = messageLabel
    }
    
    func restore() {
        self.backgroundView = nil
    }
}
