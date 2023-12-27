//
//  Field.swift
//  rem
//
//  Created by Jason McGhee on 12/27/23.
//

import SwiftUI

struct Field: View {
    @State var text: String

    var body: some View {
        TextField(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/, text: $text)
    }
}

#Preview {
    Field(text: "")
}
