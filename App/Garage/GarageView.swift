import DriveStatsCore
import SwiftUI

struct GarageView: View {
    @Bindable var garage: Garage
    @State private var isAddingVehicle = false
    @State private var editingVehicle: Vehicle?

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
                            .contentShape(Rectangle())
                            .onTapGesture { editingVehicle = vehicle }
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
                VehicleEditorSheet(vehicle: nil) { garage.save($0) }
            }
            .sheet(item: $editingVehicle) { vehicle in
                VehicleEditorSheet(vehicle: vehicle) { garage.save($0) }
            }
        }
    }
}

private struct VehicleRow: View {
    let vehicle: Vehicle
    let isDefault: Bool
    let makeDefault: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VehicleIconView(vehicle: vehicle, size: 22)
                .frame(width: 44)
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

/// Add and edit share one sheet; editing preserves id and creation date so
/// drive tags stay attached.
private struct VehicleEditorSheet: View {
    let vehicle: Vehicle?
    let onSave: (Vehicle) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var make: String
    @State private var model: String
    @State private var year: Int
    @State private var bodyStyle: Vehicle.BodyStyle
    @State private var colorHex: String

    init(vehicle: Vehicle?, onSave: @escaping (Vehicle) -> Void) {
        self.vehicle = vehicle
        self.onSave = onSave
        _make = State(initialValue: vehicle?.make ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _year = State(initialValue: vehicle?.year ?? Calendar.current.component(.year, from: Date()))
        _bodyStyle = State(initialValue: vehicle?.bodyStyle ?? .sedan)
        _colorHex = State(initialValue: vehicle?.colorHex ?? VehiclePaint.palette[0])
    }

    private var canSave: Bool {
        !make.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
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

                Section("Icon") {
                    Picker("Body style", selection: $bodyStyle) {
                        ForEach(Vehicle.BodyStyle.allCases, id: \.self) { style in
                            Label(style.label, systemImage: style.symbolName).tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    HStack(spacing: 10) {
                        ForEach(VehiclePaint.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if hex == colorHex {
                                        Circle().strokeBorder(.primary, lineWidth: 2)
                                    } else {
                                        Circle().strokeBorder(.quaternary, lineWidth: 1)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }

                    HStack {
                        Spacer()
                        Image(systemName: bodyStyle.symbolName)
                            .font(.system(size: 44))
                            .foregroundStyle(Color(hex: colorHex))
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(vehicle == nil ? "Add Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(vehicle == nil ? "Add" : "Save") {
                        var saved = vehicle ?? Vehicle(make: "", model: "", year: year)
                        saved.make = make.trimmingCharacters(in: .whitespaces)
                        saved.model = model.trimmingCharacters(in: .whitespaces)
                        saved.year = year
                        saved.bodyStyle = bodyStyle
                        saved.colorHex = colorHex
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    GarageView(garage: Garage())
}
