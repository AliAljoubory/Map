//
//  ViewController.swift
//  MapKit Tutorial
//
//  Created by Ali Aljoubory on 22/12/2018.
//  Copyright © 2018 Ali Aljoubory. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {
    
    @IBOutlet var mapView: MKMapView!
    @IBOutlet var addressLabel: UILabel!
    
    let locationManager = CLLocationManager()
    let regionInMetres: Double = 10000
    var previouslocation: CLLocation?
    var directionsArray: [MKDirections] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkLocationServices()
        
        let goButton = UIButton(type: .custom)
        goButton.frame = CGRect(x: 184, y: 750, width: 50, height: 50)
        goButton.layer.cornerRadius = goButton.bounds.size.width / 2
        goButton.clipsToBounds = true
        goButton.setTitle("GO", for: .normal)
        goButton.backgroundColor = .green
        goButton.addTarget(self, action: #selector(getDirections), for: .touchUpInside)
        
        view.addSubview(goButton)
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorisation()
        }
        else {
            let ac = UIAlertController(title: "Turn On Location Services", message: "Location Services are currently turned off. Please go to Settings, Privacy and then turn on Location Services.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
        }
    }
    
    func checkLocationAuthorisation() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            centreViewOnUserLocation()
            locationManager.startUpdatingLocation()
            previouslocation = getCentreLocation(for: mapView)
        case .denied:
            let ac = UIAlertController(title: "Location has been denied", message: "Please turn on Location Services. Go to Settings, Privacy, Location Services and turn on Location Services for MapKit Tutorial.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            let ac = UIAlertController(title: "Restrictions on Location Services has been turned on.", message: "Please go to Settings, Screen Time, Content & Privacy Restrictions and ensure Location Services are allowed.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    func centreViewOnUserLocation() {
        if let location = locationManager.location?.coordinate {
            let region = MKCoordinateRegion(center: location, latitudinalMeters: regionInMetres, longitudinalMeters: regionInMetres)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func getCentreLocation(for MapView: MKMapView) -> CLLocation {
        let latitude = MapView.centerCoordinate.latitude
        let longitude = MapView.centerCoordinate.longitude
        
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    @objc func getDirections() {
        guard let location = locationManager.location?.coordinate else {return}
        
        let request = createDirectionsRequest(from: location)
        let directions = MKDirections(request: request)
        resetMapView(withNew: directions)
        
        directions.calculate { [unowned self] (response, error) in
            if let _ = error {
                let ac = UIAlertController(title: "Error getting directions", message: "\(error?.localizedDescription ?? "Error")", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(ac, animated: true)
            } else {
                guard let reponse = response else {return}
                
                for route in reponse.routes {
                    self.mapView.addOverlay(route.polyline)
                    self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
                }
            }
        }
    }
    
    func createDirectionsRequest(from coordinate: CLLocationCoordinate2D) -> MKDirections.Request {
        let destinationCoordinate = getCentreLocation(for: mapView).coordinate
        let startingLocation = MKPlacemark(coordinate: coordinate)
        let destination = MKPlacemark(coordinate: destinationCoordinate)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: startingLocation)
        request.destination = MKMapItem(placemark: destination)
        request.transportType = .automobile
        request.requestsAlternateRoutes  = true
        
        return request
    }
    
    func resetMapView(withNew directions: MKDirections) {
        mapView.removeOverlays(mapView.overlays)
        directionsArray.append(directions)
        let _ = directionsArray.map { $0.cancel() }
        directionsArray.removeAll()
    }
}

extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthorisation()
    }
}

extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let centre = getCentreLocation(for: mapView)
        let geoCoder = CLGeocoder()
        
        guard let previousLocation = self.previouslocation else {return}
        guard centre.distance(from: previousLocation) > 50 else {return}
        self.previouslocation = centre
        
        geoCoder.cancelGeocode()
        
        geoCoder.reverseGeocodeLocation(centre) { [weak self] (placemarks, error) in
            guard let self = self else {return}
            
            if let _ = error {
                let ac = UIAlertController(title: "Error finding location", message: "\(error?.localizedDescription ?? "Error")", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(ac, animated: true)
                
                return
            }
            
            guard let placemark = placemarks?.first else {
                let ac = UIAlertController(title: "Error finding your pin", message: "\(error?.localizedDescription ?? "Error")", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(ac, animated: true)
                
                return
            }
            
            let streetNumber = placemark.subThoroughfare ?? ""
            let streetName = placemark.thoroughfare ?? ""
            
            DispatchQueue.main.async {
                self.addressLabel.text = "\(streetNumber) \(streetName)"
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay as! MKPolyline)
        renderer.strokeColor = .blue
        
        return renderer
    }
}
