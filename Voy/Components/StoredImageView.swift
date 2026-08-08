import SwiftUI
import UIKit

struct StoredImageView: View {
    let data: Data?
    var symbol = "photo"

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)

            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
}
