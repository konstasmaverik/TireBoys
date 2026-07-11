import DriveStatsCore
import SwiftUI

struct GarageView: View {
    @Bindable var garage: Garage
    @State private var isAddingVehicle = false

    var body: some View {
        NavigationStack {
            Group {
                if garage.vehicles.isEmpty {
                    ContentUnavailableView(
                        "No vehicles yet",
                        systemImage: "car.2",
                        description: Text(garage.loadError ?? "Add the car you drive so drives get tagged with it.")
                    )
                } else {
                    List {
                        ForEach(garage.vehicles) { vehicle in
                            VehicleRow(
                                vehicle: vehicle,
                                isDefault: vehicle.id == garage.defaultVehicleID,
                                makeDefault: { garage.defaultVehicleID = vehicle.id }
                            )
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                garage.delete(id: garage.vehicles[index].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Garage")
            .toolbar {
                Button {
                    isAddingVehicle = true
                } label: {
                    Label("Add Vehicle", systemImage: "plus")
                }
            }
            .sheet(isPresented: $isAddingVehicle) {
                AddVehicleSheet { make, model, year in
                    garage.add(make: make, model: model, year: year)
                }
            }
        }
    }
}

private struct VehicleRow: View {
    let vehicle: Vehicle
    let isDefault: Bool
    let makeDefault: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vehicle.make) \(vehicle.model)")
                    .font(.headline)
                Text(String(vehicle.year))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: makeDefault) {
                Image(systemName: isDefault ? "star.fill" : "star")
                    .foregroundStyle(isDefault ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDefault ? "Default vehicle" : "Make default")
        }
    }
}

private struct AddVehicleSheet: View {
    let onAdd: (String, String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var make = ""
    @State private var model = ""
    @State private var year = Calendar.current.component(.year, from: Date())

    private var canAdd: Bool {
        !make.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Make (e.g. Toyota)", text: $make)
                    .textInputAutocapitalization(.words)
                TextField("Model (e.g. Supra)", text: $model)
                    .textInputAutocapitalization(.words)
                Picker("Year", selection: $year) {
                    let currentYear = Calendar.current.component(.year, from: Date())
                    ForEach((1950...currentYear + 1).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(
                            make.trimmingCharacters(in: .whitespaces),
                            model.trimmingCharacters(in: .whitespaces),
                            year
                        )
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    GarageView(garage: Garage())
}
