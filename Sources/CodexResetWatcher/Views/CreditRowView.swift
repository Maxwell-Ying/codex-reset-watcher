import SwiftUI

struct CreditRowView: View {
    let credit: ResetCredit

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: credit.isAvailable ? "checkmark.seal.fill" : "clock.badge.xmark")
                .font(.title3)
                .foregroundStyle(credit.isAvailable ? .green : .secondary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(credit.title ?? "Codex reset credit")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(credit.status.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(credit.isAvailable ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    GridRow {
                        Text("Granted")
                            .foregroundStyle(.secondary)
                        Text(DateFormatting.full(credit.grantedAt))
                    }
                    GridRow {
                        Text("Expires")
                            .foregroundStyle(.secondary)
                        Text(DateFormatting.full(credit.expiresAt))
                            .fontWeight(credit.isAvailable ? .semibold : .regular)
                    }
                    if credit.redeemedAt != nil {
                        GridRow {
                            Text("Redeemed")
                                .foregroundStyle(.secondary)
                            Text(DateFormatting.full(credit.redeemedAt))
                        }
                    }
                }
                .font(.callout)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary)
        }
    }
}
