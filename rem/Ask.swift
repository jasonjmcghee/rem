//
//  Ask.swift
//  rem
//
//  Created by Jason McGhee on 12/27/23.
//

import SwiftUI

struct AskView: View {
    var onAsk: (String) -> Void

    var body: some View {
        ZStack {
            // Using a thin material for the background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Components
            VStack {
                AskViewResults(onAsk: onAsk)
                    .padding(.top, 20)

                Spacer()
                // Future components will be added here
                Spacer()
            }
        }
    }
}

struct AskViewResults: View {
    @State var text: String = ""
    var onAsk: (String) -> Void
    var body: some View {
        VStack {
            AskBar(text: $text, onAsk: onAsk)
            
            ScrollView {
            }
        }
    }

}

struct AskBar: View {
    @Binding var text: String
    var onAsk: (String) -> Void
    @Namespace var nspace
    @FocusState var focused: Bool?

    var body: some View {
        HStack {
            TextField("Search", text: $text, prompt: Text("Search for something..."))
                .prefersDefaultFocus(in: nspace)
                .textFieldStyle(.plain)
                .focused($focused, equals: true)
                .font(.system(size: 20))
                .padding()
                .padding(.horizontal, 24)
                .background(.thickMaterial)
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .imageScale(.large)
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12)
                    }
                )
                .onSubmit {
                    onAsk(text)
                }
                .onAppear {
                    self.focused = true
                }
                .padding(.horizontal, 10)
        }
    }
}

#Preview {
    AskView(onAsk: { _ in })
}
