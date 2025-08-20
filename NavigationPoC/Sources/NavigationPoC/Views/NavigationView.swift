import SwiftUI
import CoreMotion

struct NavigationView: View {
    let destination: Location
    
    @StateObject private var navigationService = NavigationService.shared
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showRating = false
    @State private var rating = 5
    @State private var feedback = ""
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.teal.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Destination info
                VStack(spacing: 10) {
                    Text("Navigating to")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text(destination.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding()
                
                // Arrow display
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 250, height: 250)
                    
                    // Direction arrow
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(Color(navigationService.getStatusColor()))
                        .rotationEffect(.degrees(navigationService.getArrowRotation()))
                        .scaleEffect(navigationService.getArrowScale())
                        .animation(.easeInOut(duration: 0.3), value: navigationService.arrowDirection)
                    
                    // Distance text
                    VStack {
                        Spacer()
                        Text(navigationService.distanceToDestination)
                            .font(.title)
                            .fontWeight(.semibold)
                            .padding(.top, 200)
                    }
                }
                
                // Status information
                VStack(spacing: 15) {
                    // Navigation status
                    Text(navigationService.navigationStatus)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Connection indicators
                    HStack(spacing: 20) {
                        // Anchors connected
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.blue)
                            Text("\(navigationService.niService.connectedAnchors.count) anchors")
                                .font(.caption)
                        }
                        
                        // Confidence level
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.green)
                            Text("\(Int(navigationService.niService.positionConfidence * 100))% confidence")
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Spacer()
                
                // Stop button
                Button(action: stopNavigation) {
                    Text("Stop Navigation")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startNavigation()
        }
        .onDisappear {
            navigationService.stopNavigation()
        }
        .alert("You have arrived!", isPresented: $navigationService.hasArrived) {
            Button("Rate Experience") {
                showRating = true
            }
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("You've reached \(destination.name)")
        }
        .sheet(isPresented: $showRating) {
            RatingView(rating: $rating, feedback: $feedback) {
                Task {
                    await supabaseService.saveNavigationRating(
                        destination: destination.name,
                        rating: rating,
                        feedback: feedback.isEmpty ? nil : feedback
                    )
                }
                dismiss()
            }
        }
    }
    
    private func startNavigation() {
        Task {
            await navigationService.startNavigation(to: destination)
        }
    }
    
    private func stopNavigation() {
        navigationService.stopNavigation()
        dismiss()
    }
}

struct RatingView: View {
    @Binding var rating: Int
    @Binding var feedback: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Rate Your Experience")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                // Star rating
                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                rating = star
                            }
                    }
                }
                
                // Feedback text
                VStack(alignment: .leading) {
                    Text("Additional Feedback (Optional)")
                        .font(.headline)
                    
                    TextEditor(text: $feedback)
                        .frame(height: 100)
                        .padding(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Submit button
                Button(action: {
                    onSubmit()
                    dismiss()
                }) {
                    Text("Submit")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}