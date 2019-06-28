//
//  ViewController.swift
//  VirtualTourist
//
//  Created by David Lang on 6/18/19.
//  Copyright © 2019 David Lang. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    var pinResultController:NSFetchedResultsController<Pin>!
    var currentPin:Pin!
    var flickrSearchResult: FlickrSearchResult?
    var editMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress))
        mapView.addGestureRecognizer(longPressRecognizer)

    }
    override func viewWillAppear(_ animated: Bool) {
        fetchStoredPins(nil)
        restoreAnnotations()
    }
    
    func restoreAnnotations() {
        mapView.removeAnnotations(mapView.annotations)
        guard let pins = pinResultController.fetchedObjects else {return}
        pins.forEach({ (pin) in
            let annotation = makeAnnotation(CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
            addAnnotation(annotation)
        })
    }
    
    //handle the long press
    @objc func longPress(sender: UIGestureRecognizer) {
        if sender.state == .ended {
            let viewLocation = sender.location(in: mapView)
            let locationCoordinate = mapView.convert(viewLocation, toCoordinateFrom: mapView)
            let annotation = makeAnnotation(locationCoordinate)
            addAnnotation(annotation)
            savePinToData(annotation)

        }
    }
    func makeAnnotation(_ location: CLLocationCoordinate2D) -> MKPointAnnotation{
        let annotation = MKPointAnnotation()
        annotation.coordinate = location
        return annotation
    }
    
    //add annotation to the mapview
    func addAnnotation(_ annotation: MKPointAnnotation) {
        self.mapView.addAnnotation(annotation)
    }
    
    /// Save the annotationView to the main context
    ///
    /// - Parameter pinView: provides the coordinates from the view to the model
    func savePinToData(_ pointAnnotation: MKPointAnnotation) {
        guard let pinEntityDescription = NSEntityDescription.entity(forEntityName: "Pin", in: DataController.shared.mainContext) else {return}
        let pin = Pin(entity: pinEntityDescription, insertInto: DataController.shared.mainContext)
        let pinCoordinate = pointAnnotation.coordinate
        pin.setValue(pinCoordinate.latitude, forKey: Constants.latitudeKey)
        pin.setValue(pinCoordinate.longitude, forKey: Constants.longitudeKey)
        try? DataController.shared.mainContext.save()
    }
    
    
    func storedPinWith(latitude: Double, longitude: Double) -> Pin? {
        let request:NSFetchRequest<Pin> = Pin.fetchRequest()
        let coordinatePredicates = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "latitude == %lf", latitude),
            NSPredicate(format: "longitude == %lf", longitude)
            ])
       request.predicate = coordinatePredicates
        
        do {
            let pin = try DataController.shared.mainContext.fetch(request).first
            return pin
        } catch {
            return nil
        }
    }
    
    fileprivate func fetchStoredPins(_ compoundPredicate: NSCompoundPredicate?) {
        let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
        fetchRequest.sortDescriptors = []
        if compoundPredicate != nil {
            fetchRequest.predicate = compoundPredicate
        }
        pinResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DataController.shared.mainContext, sectionNameKeyPath: nil, cacheName: nil)

        do {
            try pinResultController.performFetch()
        } catch let error as NSError {
            displayAlert(error)
        }
    }
    
    
    @IBAction func switchMode(_ sender: UIButton) {
        if editMode {
            sender.setTitle("Add Pins", for: .normal)
        } else {
            sender.setTitle("Remove Pins", for: .normal)
        }
        editMode = !editMode

    }
        
    func goToAlbum() {
        performSegue(withIdentifier: Constants.albumSegue, sender: self)
    }
    
    /// Aquire URLs from flickr, assign the flickrsearchresult var, add transistion to the photo album view
    ///
    /// - Parameter coord: map view pin coordinates
    func getPhotosForPin(coord: [String:Double]) {
        Flickr.requestImageResourceLocations(coord: coord, pageNumber: 0) { (data, error) in
            guard let data = data, error == nil else {
                return
            }
            DispatchQueue.main.async {
                self.flickrSearchResult = data
                self.goToAlbum()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == Constants.albumSegue {
            let vc = segue.destination as? AlbumViewController
            if let pages:Int = self.flickrSearchResult?.photos?.pages {
                vc?.pages = pages
            }
            vc?.flickrSearchResult = self.flickrSearchResult
            vc?.currentPin = currentPin
        }
    }
}

extension MapViewController : MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else { return nil}
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: Constants.pin) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: Constants.pin)
        } else {
            pinView?.annotation = annotation
        }
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else {return}
        let coordinate = annotation.coordinate
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        let coord = [
            Constants.latKey:latitude,
            Constants.lonKey:longitude
        ]
        guard let pin = storedPinWith(latitude: latitude, longitude: longitude) else {
            displayAlert(DataError.dataFailure)
            return
        }
        
        guard editMode else {
            currentPin = pin
            getPhotosForPin(coord: coord)
            return
        }
            mapView.removeAnnotation(annotation)
            DataController.shared.mainContext.delete(pin)
            try? DataController.shared.mainContext.save()
    }
}

extension UIViewController {
    func displayAlert(_ error: Error) {
            let alertInfo = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .actionSheet)
        alertInfo.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alertInfo, animated: true, completion: nil)
    }
}







