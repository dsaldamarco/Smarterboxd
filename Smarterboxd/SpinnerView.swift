import SwiftUI

// MARK: - VISTA HELPER: SPINNER
// (Questo è il nuovo anello di caricamento)

struct SpinnerView: View {
    // Stato per l'animazione di riempimento
    @State private var fill: CGFloat = 0.0
    // Stato per l'animazione di rotazione
    @State private var rotation = Angle(degrees: 0)

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                // 1. Cerchio di sfondo grigio
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                
                // 2. Cerchio blu che si riempie
                Circle()
                    .trim(from: 0, to: fill) // Animato da 0 a 1
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(Angle(degrees: -90)) // Fa partire l'animazione dall'alto
            }
            .rotationEffect(rotation) // Fa ruotare l'intero ZStack
            .frame(width: 60, height: 60)
            .onAppear {
                // Avvia l'animazione di riempimento (dura 1 sec)
                withAnimation(.linear(duration: 1.0)) {
                    fill = 1.0
                }
                
                // Avvia l'animazione di rotazione (continua)
                // per renderlo più dinamico
                withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                    rotation = Angle(degrees: 360)
                }
            }
            
            Text("Giro la ruota...")
                .font(.title2)
                .foregroundColor(.secondary)
                .transition(.opacity)
        }
        .transition(.opacity) // Transizione per l'intera vista
    }
}
