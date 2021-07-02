/*
 ViewController.swift
 Live OCR Text Recognition

 Created by Minaam Ahmed Awan on 30/06/2021.

 Abstract:
 Main view controller: Handles Scan Button Input and Manages Saved Scans.
*/


import UIKit


class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    @IBAction func scanBtn(_ sender: UIBarButtonItem) {
        let documentCameraViewController = storyboard?.instantiateViewController(identifier: "secondVC") as! SecondViewController
        navigationController?.pushViewController(documentCameraViewController, animated: true)
    }
}
