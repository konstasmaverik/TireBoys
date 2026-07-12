import DriveStatsCore
import PhotosUI
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
    @State private var emoji: String
    /// Stable before save so a generated icon has somewhere to live.
    @State private var vehicleID: UUID
    @State private var generatedIcon: UIImage?
    @State private var sourcePhoto: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var paint = ""

    private static let paintNames = [
        "red", "orange", "yellow", "green", "blue", "purple",
        "pink", "black", "silver", "white", "brown",
    ]

    init(vehicle: Vehicle?, onSave: @escaping (Vehicle) -> Void) {
        self.vehicle = vehicle
        self.onSave = onSave
        _make = State(initialValue: vehicle?.make ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _year = State(initialValue: vehicle?.year ?? Calendar.current.component(.year, from: Date()))
        _emoji = State(initialValue: vehicle?.emoji ?? VehicleEmoji.suggestions[0])
        let id = vehicle?.id ?? UUID()
        _vehicleID = State(initialValue: id)
        _generatedIcon = State(initialValue: VehicleIconStore.load(for: id))
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(VehicleEmoji.suggestions, id: \.self) { suggestion in
                            Text(suggestion)
                                .font(.system(size: 30))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    suggestion == emoji ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .onTapGesture { emoji = suggestion }
                        }
                    }

                    HStack {
                        TextField("Or type any emoji", text: $emoji)
                            .onChange(of: emoji) { _, new in
                                // Keep exactly one character (an emoji counts as one).
                                if let last = new.last, new.count > 1 {
                                    emoji = String(last)
                                }
                            }
                        Text(emoji)
                            .font(.system(size: 36))
                    }
                }

                Section {
                    if let generatedIcon {
                        HStack {
                            Spacer()
                            Image(uiImage: generatedIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 72)
                            Spacer()
                        }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Make sticker from a photo", systemImage: "person.crop.square.badge.camera")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Or draw an AI cartoon — pick the paint color first")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Self.paintNames, id: \.self) { name in
                                    Text(name)
                                        .font(.callout)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            name == paint ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.quaternary),
                                            in: Capsule()
                                        )
                                        .onTapGesture { paint = name }
                                }
                            }
                        }
                    }
                    Button {
                        generateAICartoon()
                    } label: {
                        Label("Draw AI cartoon", systemImage: "dice")
                    }
                    .disabled(isGenerating || make.isEmpty || model.isEmpty)
                    if generatedIcon != nil {
                        Button("Remove icon", role: .destructive) {
                            VehicleIconStore.delete(for: vehicleID)
                            generatedIcon = nil
                        }
                    }
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generating…")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let generationError {
                        Text(generationError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Sticker icon")
                } footer: {
                    Text("Sticker: your car is cut out of the photo and cartoonified entirely on this phone — exact shape and color, nothing leaves the device. AI cartoon: a free service draws from the text description only; tap again for a different take.")
                }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task {
                        defer { photoItem = nil }
                        guard let data = try? await item.loadTransferable(type: Data.self),
                              let photo = UIImage(data: data)
                        else { return }
                        sourcePhoto = photo
                        if let detected = await VehicleIconGenerator.detectPaint(of: photo) {
                            paint = detected
                        }
                        generateSticker(from: photo)
                    }
                }
            }
            .navigationTitle(vehicle == nil ? "Add Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Don't strand an icon generated for a vehicle that
                        // was never saved.
                        if vehicle == nil {
                            VehicleIconStore.delete(for: vehicleID)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(vehicle == nil ? "Add" : "Save") {
                        var saved = vehicle ?? Vehicle(id: vehicleID, make: "", model: "", year: year)
                        saved.make = make.trimmingCharacters(in: .whitespaces)
                        saved.model = model.trimmingCharacters(in: .whitespaces)
                        saved.year = year
                        saved.emoji = emoji.isEmpty ? "🚗" : emoji
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func generateSticker(from photo: UIImage) {
        generationError = nil
        isGenerating = true
        Task {
            defer { isGenerating = false }
            do {
                let icon = try await VehicleIconGenerator.stickerIcon(from: photo)
                VehicleIconStore.save(icon, for: vehicleID)
                generatedIcon = icon
            } catch {
                generationError = error.localizedDescription
            }
        }
    }

    private func generateAICartoon() {
        generationError = nil
        isGenerating = true
        Task {
            defer { isGenerating = false }
            // Uses the form's current values so the prompt matches what the
            // user typed, even before saving.
            let described = Vehicle(
                id: vehicleID,
                make: make.trimmingCharacters(in: .whitespaces),
                model: model.trimmingCharacters(in: .whitespaces),
                year: year
            )
            do {
                let icon = try await VehicleIconGenerator.generateIcon(
                    for: described,
                    paint: paint.isEmpty ? "red" : paint
                )
                VehicleIconStore.save(icon, for: vehicleID)
                generatedIcon = icon
            } catch {
                generationError = error.localizedDescription
            }
        }
    }
}

#Preview {
    GarageView(garage: Garage())
}
