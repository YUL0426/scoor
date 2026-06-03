//
//  Location.swift
//  Scoor
//

import Foundation

struct Location: Codable, Identifiable, Hashable {
    let id: UUID
    let country: String
    let city: String
    let latitude: Double
    let longitude: Double

    init(
        id: UUID = UUID(),
        country: String,
        city: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.country = country
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
    }
}
